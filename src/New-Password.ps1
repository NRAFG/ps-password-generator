function New-Password {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = (Join-Path $PSScriptRoot '..\config\password-rules.json'),
        [string]$Profile = '',
        [int]$Length = 0,
        [switch]$SaveToStore,
        [string]$SecretName = ''
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Password rules config not found at: $ConfigPath"
    }

    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

    $rules = @{}
    foreach ($prop in $config.defaults.PSObject.Properties) {
        $rules[$prop.Name] = $prop.Value
    }

    if ($Profile -ne '') {
        if (-not $config.profiles.PSObject.Properties[$Profile]) {
            throw "Unknown profile '$Profile'. Available profiles: $($config.profiles.PSObject.Properties.Name -join ', ')"
        }
        foreach ($prop in $config.profiles.$Profile.PSObject.Properties) {
            $rules[$prop.Name] = $prop.Value
        }
    }

    $resolvedLength = $rules['defaultLength']
    if ($Length -gt 0) {
        if ($Length -lt $rules['minLength'] -or $Length -gt $rules['maxLength']) {
            throw "Requested length $Length is outside allowed range [$($rules['minLength']), $($rules['maxLength'])]."
        }
        $resolvedLength = $Length
    } elseif ($resolvedLength -lt $rules['minLength']) {
        $resolvedLength = $rules['minLength']
    } elseif ($resolvedLength -gt $rules['maxLength']) {
        $resolvedLength = $rules['maxLength']
    }

    $upper   = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $lower   = 'abcdefghijklmnopqrstuvwxyz'
    $digits  = '0123456789'
    $special = $rules['specialChars']

    $excluded = [System.Collections.Generic.HashSet[char]]::new()
    if ($rules['excludeAmbiguous']) {
        foreach ($c in $rules['ambiguousChars'].ToCharArray()) { [void]$excluded.Add($c) }
    }
    if ($rules['excludeChars'] -ne '') {
        foreach ($c in $rules['excludeChars'].ToCharArray()) { [void]$excluded.Add($c) }
    }

    function Remove-ExcludedChars([string]$source) {
        -join ($source.ToCharArray() | Where-Object { -not $excluded.Contains($_) })
    }

    $poolUpper   = if ($rules['requireUppercase'])   { Remove-ExcludedChars $upper   } else { '' }
    $poolLower   = if ($rules['requireLowercase'])   { Remove-ExcludedChars $lower   } else { '' }
    $poolDigits  = if ($rules['requireDigits'])      { Remove-ExcludedChars $digits  } else { '' }
    $poolSpecial = if ($rules['requireSpecialChars']) { Remove-ExcludedChars $special } else { '' }

    $fullPool = $poolUpper + $poolLower + $poolDigits + $poolSpecial
    if ($fullPool.Length -eq 0) {
        throw 'Character pool is empty after applying exclusions. Loosen excludeAmbiguous or excludeChars.'
    }

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    function Get-RandomIndex([int]$maxExclusive) {
        $bytes = [byte[]]::new(4)
        $rng.GetBytes($bytes)
        $raw = [System.BitConverter]::ToUInt32($bytes, 0)
        # Rejection sampling to eliminate modulo bias
        $limit = [uint32]([uint32]::MaxValue - ([uint32]::MaxValue % [uint32]$maxExclusive))
        while ($raw -ge $limit) {
            $rng.GetBytes($bytes)
            $raw = [System.BitConverter]::ToUInt32($bytes, 0)
        }
        return [int]($raw % [uint32]$maxExclusive)
    }

    function Get-RandomChar([string]$pool) {
        return $pool[(Get-RandomIndex $pool.Length)]
    }

    $chars = [System.Collections.Generic.List[char]]::new()

    $minU = [int]$rules['minUppercase']
    $minL = [int]$rules['minLowercase']
    $minD = [int]$rules['minDigits']
    $minS = [int]$rules['minSpecialChars']

    if ($minU -gt 0 -and $poolUpper.Length -eq 0) {
        throw "minUppercase=$minU but no uppercase characters remain after exclusions."
    }
    if ($minL -gt 0 -and $poolLower.Length -eq 0) {
        throw "minLowercase=$minL but no lowercase characters remain after exclusions."
    }
    if ($minD -gt 0 -and $poolDigits.Length -eq 0) {
        throw "minDigits=$minD but no digit characters remain after exclusions."
    }
    if ($minS -gt 0 -and $poolSpecial.Length -eq 0) {
        throw "minSpecialChars=$minS but no special characters remain after exclusions."
    }

    for ($i = 0; $i -lt $minU; $i++) { $chars.Add((Get-RandomChar $poolUpper)) }
    for ($i = 0; $i -lt $minL; $i++) { $chars.Add((Get-RandomChar $poolLower)) }
    for ($i = 0; $i -lt $minD; $i++) { $chars.Add((Get-RandomChar $poolDigits)) }
    for ($i = 0; $i -lt $minS; $i++) { $chars.Add((Get-RandomChar $poolSpecial)) }

    $remaining = $resolvedLength - $chars.Count
    if ($remaining -lt 0) {
        throw "Minimum character class requirements ($($chars.Count) chars) exceed requested length $resolvedLength."
    }
    for ($i = 0; $i -lt $remaining; $i++) {
        $chars.Add((Get-RandomChar $fullPool))
    }

    # Fisher-Yates shuffle using CSRNG
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $j = Get-RandomIndex ($i + 1)
        $tmp = $chars[$i]
        $chars[$i] = $chars[$j]
        $chars[$j] = $tmp
    }

    $rng.Dispose()

    $password = -join $chars

    if ($SaveToStore) {
        $storeScript = Join-Path $PSScriptRoot 'SecretStore.ps1'
        . $storeScript
        Save-PasswordToStore -SecretName $SecretName -PlainTextPassword $password
    }

    return $password
}
