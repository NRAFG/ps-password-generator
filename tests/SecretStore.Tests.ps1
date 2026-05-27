#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

Describe 'SecretStore' {

    BeforeAll {
        . (Join-Path $PSScriptRoot '..\src\SecretStore.ps1')
    }

    # ------------------------------------------------------------------
    # Helper: build a SecureString from a plain-text string
    # ------------------------------------------------------------------
    BeforeAll {
        function script:New-TestSecureString {
            param([string]$Plain)
            ConvertTo-SecureString -String $Plain -AsPlainText -Force
        }
    }

    # ==================================================================
    # Save-PasswordToStore
    # ==================================================================
    Describe 'Save-PasswordToStore' {

        Context 'When Microsoft.PowerShell.SecretManagement is available' {

            BeforeAll {
                # Simulate the module being present
                Mock Get-Module { return [PSCustomObject]@{ Name = 'Microsoft.PowerShell.SecretManagement' } } `
                    -ParameterFilter { $ListAvailable -and $Name -eq 'Microsoft.PowerShell.SecretManagement' }

                # Capture calls to Set-Secret
                Mock Set-Secret { }
            }

            It 'Calls Set-Secret with the correct secret name' {
                Save-PasswordToStore -SecretName 'MyApp/DbPassword' -PlainTextPassword 'S3cur3P@ss!'

                Should -Invoke Set-Secret -Times 1 -Exactly -ParameterFilter {
                    $Name -eq 'MyApp/DbPassword'
                }
            }

            It 'Calls Set-Secret with a SecureString value (not plain text)' {
                Save-PasswordToStore -SecretName 'MyApp/ApiKey' -PlainTextPassword 'T0pSecr3t!'

                Should -Invoke Set-Secret -Times 1 -Exactly -ParameterFilter {
                    $Secret -is [System.Security.SecureString]
                }
            }

            It 'Passes the correct plain-text value encoded as a SecureString' {
                $capturedSecret = $null
                Mock Set-Secret { $capturedSecret = $Secret } -Verifiable

                Save-PasswordToStore -SecretName 'CheckValue' -PlainTextPassword 'VerifyMe99!'

                # Decode and verify
                $bstr  = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($capturedSecret)
                $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

                $plain | Should -Be 'VerifyMe99!'
            }
        }

        Context 'When Microsoft.PowerShell.SecretManagement is NOT available' {

            BeforeAll {
                # Simulate the module being absent
                Mock Get-Module { return $null } `
                    -ParameterFilter { $ListAvailable -and $Name -eq 'Microsoft.PowerShell.SecretManagement' }

                Mock Set-Secret { }
            }

            It 'Throws a helpful error message' {
                { Save-PasswordToStore -SecretName 'AnyName' -PlainTextPassword 'AnyPass1!' } |
                    Should -Throw -Because 'module is not installed'
            }

            It 'Does not call Set-Secret when the module is missing' {
                try {
                    Save-PasswordToStore -SecretName 'AnyName' -PlainTextPassword 'AnyPass1!'
                }
                catch { }

                Should -Invoke Set-Secret -Times 0
            }
        }
    }

    # ==================================================================
    # Get-PasswordFromStore
    # ==================================================================
    Describe 'Get-PasswordFromStore' {

        Context 'When Microsoft.PowerShell.SecretManagement is available' {

            BeforeAll {
                $script:FakePlain  = 'R3tr!eved#Passw0rd'
                $script:FakeSecure = script:New-TestSecureString $script:FakePlain

                Mock Get-Module { return [PSCustomObject]@{ Name = 'Microsoft.PowerShell.SecretManagement' } } `
                    -ParameterFilter { $ListAvailable -and $Name -eq 'Microsoft.PowerShell.SecretManagement' }

                Mock Get-Secret { return $script:FakeSecure } `
                    -ParameterFilter { $Name -eq 'StoredSecret' }
            }

            It 'Returns a SecureString by default (no -AsPlainText)' {
                $result = Get-PasswordFromStore -SecretName 'StoredSecret'

                $result | Should -BeOfType [System.Security.SecureString]
            }

            It 'The returned SecureString encodes the correct value' {
                $result = Get-PasswordFromStore -SecretName 'StoredSecret'

                $bstr  = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($result)
                $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

                $plain | Should -Be $script:FakePlain
            }

            It 'Returns a plain string when -AsPlainText is passed' {
                $result = Get-PasswordFromStore -SecretName 'StoredSecret' -AsPlainText

                $result | Should -BeOfType [string]
                $result | Should -Be $script:FakePlain
            }

            It 'Calls Get-Secret with the correct secret name' {
                Get-PasswordFromStore -SecretName 'StoredSecret' | Out-Null

                Should -Invoke Get-Secret -Times 1 -Exactly -ParameterFilter {
                    $Name -eq 'StoredSecret'
                }
            }
        }

        Context 'When Microsoft.PowerShell.SecretManagement is NOT available' {

            BeforeAll {
                Mock Get-Module { return $null } `
                    -ParameterFilter { $ListAvailable -and $Name -eq 'Microsoft.PowerShell.SecretManagement' }

                Mock Get-Secret { }
            }

            It 'Throws a helpful error message' {
                { Get-PasswordFromStore -SecretName 'AnyName' } |
                    Should -Throw -Because 'module is not installed'
            }

            It 'Does not call Get-Secret when the module is missing' {
                try {
                    Get-PasswordFromStore -SecretName 'AnyName'
                }
                catch { }

                Should -Invoke Get-Secret -Times 0
            }
        }
    }
}
