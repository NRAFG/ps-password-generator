#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

Describe 'New-Password' {

    BeforeAll {
        . (Join-Path $PSScriptRoot '..\src\New-Password.ps1')

        # Resolve the real config file and create a temp copy for tests
        $script:RealConfig   = Join-Path $PSScriptRoot '..\config\password-rules.json'
        $script:TempConfig   = Join-Path $TestDrive 'password-rules.json'
        Copy-Item -Path $script:RealConfig -Destination $script:TempConfig
    }

    AfterAll {
        # TestDrive is cleaned up automatically by Pester, but remove explicitly
        # in case this suite is run outside of the standard Pester test drive.
        if (Test-Path $script:TempConfig) {
            Remove-Item -Path $script:TempConfig -Force -ErrorAction SilentlyContinue
        }
    }

    # ------------------------------------------------------------------
    # Default length
    # ------------------------------------------------------------------
    Context 'Default length behaviour' {

        It 'Returns a string of the expected default length (20) when no -Length is given' {
            $password = New-Password -ConfigPath $script:TempConfig
            $password              | Should -BeOfType [string]
            $password.Length       | Should -Be 20
        }

        It 'Returns a string of a custom length when -Length is specified' {
            $password = New-Password -Length 35 -ConfigPath $script:TempConfig
            $password              | Should -BeOfType [string]
            $password.Length       | Should -Be 35
        }
    }

    # ------------------------------------------------------------------
    # Length boundary enforcement
    # ------------------------------------------------------------------
    Context 'Length boundary enforcement' {

        It 'Throws a descriptive error when -Length is below minLength (8)' {
            { New-Password -Length 4 -ConfigPath $script:TempConfig } |
                Should -Throw -ExceptionType ([System.ArgumentException]) -Because 'length is below the configured minLength of 8'
        }

        It 'Throws a descriptive error when -Length is above maxLength (128)' {
            { New-Password -Length 200 -ConfigPath $script:TempConfig } |
                Should -Throw -ExceptionType ([System.ArgumentException]) -Because 'length exceeds the configured maxLength of 128'
        }

        It 'Does not throw when -Length equals minLength (8)' {
            { New-Password -Length 8 -ConfigPath $script:TempConfig } | Should -Not -Throw
        }

        It 'Does not throw when -Length equals maxLength (128)' {
            { New-Password -Length 128 -ConfigPath $script:TempConfig } | Should -Not -Throw
        }
    }

    # ------------------------------------------------------------------
    # Character-class requirements with default rules
    # ------------------------------------------------------------------
    Context 'Character class requirements (default rules)' {

        BeforeAll {
            $script:DefaultPassword = New-Password -ConfigPath $script:TempConfig
        }

        It 'Contains at least 1 uppercase letter' {
            ($script:DefaultPassword -cmatch '[A-Z]') | Should -Be $true
        }

        It 'Contains at least 1 lowercase letter' {
            ($script:DefaultPassword -cmatch '[a-z]') | Should -Be $true
        }

        It 'Contains at least 1 digit' {
            ($script:DefaultPassword -match '\d') | Should -Be $true
        }

        It 'Contains at least 1 special character' {
            # specialChars from config: !@#$%^&*()-_=+[]{}|;:,.<>?
            ($script:DefaultPassword -match '[!@#$%\^&*()\-_=+\[\]{}|;:,.<>?]') |
                Should -Be $true
        }
    }

    # ------------------------------------------------------------------
    # Profile: Strong
    # ------------------------------------------------------------------
    Context 'Profile: Strong' {

        BeforeAll {
            $script:StrongPassword = New-Password -Profile Strong -ConfigPath $script:TempConfig
        }

        It 'Produces a password of the Strong profile default length (32)' {
            $script:StrongPassword.Length | Should -Be 32
        }

        It 'Contains at least 3 uppercase letters' {
            $upper = ($script:StrongPassword.ToCharArray() | Where-Object { $_ -cmatch '[A-Z]' }).Count
            $upper | Should -BeGreaterOrEqual 3
        }

        It 'Contains at least 3 lowercase letters' {
            $lower = ($script:StrongPassword.ToCharArray() | Where-Object { $_ -cmatch '[a-z]' }).Count
            $lower | Should -BeGreaterOrEqual 3
        }

        It 'Contains at least 3 digits' {
            $digits = ($script:StrongPassword.ToCharArray() | Where-Object { $_ -match '\d' }).Count
            $digits | Should -BeGreaterOrEqual 3
        }

        It 'Contains at least 3 special characters' {
            $specials = ($script:StrongPassword.ToCharArray() |
                Where-Object { $_ -match '[!@#$%\^&*()\-_=+\[\]{}|;:,.<>?]' }).Count
            $specials | Should -BeGreaterOrEqual 3
        }
    }

    # ------------------------------------------------------------------
    # Profile: PIN
    # ------------------------------------------------------------------
    Context 'Profile: PIN' {

        BeforeAll {
            $script:PinPassword = New-Password -Profile PIN -ConfigPath $script:TempConfig
        }

        It 'Produces a password of the PIN profile default length (6)' {
            $script:PinPassword.Length | Should -Be 6
        }

        It 'Contains only digits' {
            ($script:PinPassword -match '^\d+$') | Should -Be $true
        }

        It 'Contains no uppercase letters' {
            ($script:PinPassword -cmatch '[A-Z]') | Should -Be $false
        }

        It 'Contains no lowercase letters' {
            ($script:PinPassword -cmatch '[a-z]') | Should -Be $false
        }

        It 'Contains no special characters' {
            ($script:PinPassword -match '[!@#$%\^&*()\-_=+\[\]{}|;:,.<>?]') | Should -Be $false
        }
    }

    # ------------------------------------------------------------------
    # Error handling
    # ------------------------------------------------------------------
    Context 'Error handling' {

        It 'Throws a descriptive error when the JSON config file path does not exist' {
            $missingPath = Join-Path $TestDrive 'does-not-exist.json'
            { New-Password -ConfigPath $missingPath } |
                Should -Throw -Because 'config file is missing'
        }

        It 'Throws when an unknown profile name is given' {
            { New-Password -Profile 'NonExistentProfile' -ConfigPath $script:TempConfig } |
                Should -Throw -Because 'the profile does not exist in the config'
        }
    }

    # ------------------------------------------------------------------
    # Uniqueness
    # ------------------------------------------------------------------
    Context 'Randomness / uniqueness' {

        It 'Generates 20 successive passwords that are all distinct' {
            $passwords = 1..20 | ForEach-Object {
                New-Password -ConfigPath $script:TempConfig
            }
            $uniqueCount = ($passwords | Sort-Object -Unique).Count
            $uniqueCount | Should -Be 20
        }
    }
}
