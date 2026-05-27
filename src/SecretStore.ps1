function Save-PasswordToStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SecretName,
        [Parameter(Mandatory)][string]$PlainTextPassword
    )

    if (-not (Get-Module -ListAvailable Microsoft.PowerShell.SecretManagement)) {
        throw "Microsoft.PowerShell.SecretManagement is not installed. Run: Install-Module Microsoft.PowerShell.SecretManagement"
    }

    $secure = ConvertTo-SecureString -String $PlainTextPassword -AsPlainText -Force
    Set-Secret -Name $SecretName -Secret $secure
}

function Get-PasswordFromStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SecretName,
        [switch]$AsPlainText
    )

    if (-not (Get-Module -ListAvailable Microsoft.PowerShell.SecretManagement)) {
        throw "Microsoft.PowerShell.SecretManagement is not installed. Run: Install-Module Microsoft.PowerShell.SecretManagement"
    }

    $secure = Get-Secret -Name $SecretName -AsSecureString

    if (-not $AsPlainText) {
        return $secure
    }

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}
