#Requires -Version 7.0
<#
.SYNOPSIS
    Installs all prerequisites for PS-PasswordGenerator and verifies the setup.
.DESCRIPTION
    Installs Microsoft.PowerShell.SecretManagement and Microsoft.PowerShell.SecretStore,
    registers a default vault named 'MyVault', and runs a quick smoke test.
.PARAMETER VaultName
    Name to register for the SecretStore vault. Defaults to 'MyVault'.
.PARAMETER Scope
    Module installation scope: CurrentUser (default) or AllUsers (requires elevation).
.PARAMETER SkipTests
    Skip the Pester smoke test at the end.
.EXAMPLE
    .\Setup-Environment.ps1
.EXAMPLE
    .\Setup-Environment.ps1 -VaultName 'PasswordGenVault' -Scope AllUsers
#>
[CmdletBinding()]
param(
    [string]$VaultName = 'MyVault',
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',
    [switch]$SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Step   { param([string]$Msg) Write-Host "  --> $Msg" -ForegroundColor Cyan }
function Write-Ok     { param([string]$Msg) Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Warn   { param([string]$Msg) Write-Host "  [!!] $Msg" -ForegroundColor Yellow }
function Write-Header { param([string]$Msg) Write-Host "`n=== $Msg ===" -ForegroundColor White }

function Install-IfMissing {
    param(
        [string]$ModuleName,
        [string]$InstallScope
    )

    $installed = Get-Module -ListAvailable -Name $ModuleName |
                 Sort-Object Version -Descending |
                 Select-Object -First 1

    if ($installed) {
        Write-Ok "$ModuleName $($installed.Version) already installed — skipping."
        return
    }

    Write-Step "Installing $ModuleName (scope: $InstallScope)..."
    Install-Module -Name $ModuleName -Scope $InstallScope -Force -AllowClobber -Repository PSGallery
    Write-Ok "$ModuleName installed."
}

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "PS-PasswordGenerator — Environment Setup" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor White

# ---------------------------------------------------------------------------
# Step 1 — PowerShellGet / PSGallery
# ---------------------------------------------------------------------------
Write-Header "Step 1: PSGallery"

$gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
if (-not $gallery) {
    Write-Step "Registering PSGallery..."
    Register-PSRepository -Default -InstallationPolicy Trusted
    Write-Ok "PSGallery registered."
}
elseif ($gallery.InstallationPolicy -ne 'Trusted') {
    Write-Step "Trusting PSGallery..."
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Write-Ok "PSGallery trusted."
}
else {
    Write-Ok "PSGallery already trusted."
}

# ---------------------------------------------------------------------------
# Step 2 — Install modules
# ---------------------------------------------------------------------------
Write-Header "Step 2: Install modules"

Install-IfMissing -ModuleName 'Microsoft.PowerShell.SecretManagement' -InstallScope $Scope
Install-IfMissing -ModuleName 'Microsoft.PowerShell.SecretStore'       -InstallScope $Scope

# ---------------------------------------------------------------------------
# Step 3 — Register vault
# ---------------------------------------------------------------------------
Write-Header "Step 3: Register vault '$VaultName'"

$existing = Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Ok "Vault '$VaultName' already registered."
    if (-not $existing.IsDefault) {
        Write-Step "Setting '$VaultName' as the default vault..."
        Set-SecretVaultDefault -Name $VaultName
        Write-Ok "Default vault updated."
    }
}
else {
    Write-Step "Registering vault '$VaultName' using Microsoft.PowerShell.SecretStore..."
    Register-SecretVault -Name $VaultName -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
    Write-Ok "Vault '$VaultName' registered and set as default."
}

# ---------------------------------------------------------------------------
# Step 4 — Smoke test: generate a password
# ---------------------------------------------------------------------------
Write-Header "Step 4: Smoke test"

Write-Step "Dot-sourcing src\New-Password.ps1..."
. (Join-Path $PSScriptRoot 'src\New-Password.ps1')

Write-Step "Generating a Strong-profile password..."
try {
    $testPwd = New-Password -Profile Strong -ConfigPath (Join-Path $PSScriptRoot 'config\password-rules.json')
    Write-Ok "Password generated successfully ($($testPwd.Length) characters)."
}
catch {
    Write-Host "  [FAIL] Password generation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Step 5 — Pester tests (optional)
# ---------------------------------------------------------------------------
if (-not $SkipTests) {
    Write-Header "Step 5: Pester tests"

    $pester = Get-Module -ListAvailable -Name Pester |
              Sort-Object Version -Descending |
              Select-Object -First 1

    if (-not $pester -or $pester.Version -lt [version]'5.0') {
        Write-Step "Installing Pester 5..."
        Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -Scope $Scope
        Write-Ok "Pester 5 installed."
    }
    else {
        Write-Ok "Pester $($pester.Version) already installed."
    }

    Write-Step "Running test suite..."
    $result = Invoke-Pester -Path (Join-Path $PSScriptRoot 'tests') -Output Detailed -PassThru
    if ($result.FailedCount -gt 0) {
        Write-Warn "$($result.FailedCount) test(s) failed. Review output above."
    }
    else {
        Write-Ok "All $($result.PassedCount) tests passed."
    }
}
else {
    Write-Warn "Step 5: Pester tests skipped (-SkipTests)."
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
Write-Host ""
Write-Host "  Launch the GUI :" -ForegroundColor White
Write-Host "    pwsh -File .\gui\Start-PasswordGeneratorGUI.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "  CLI usage       :" -ForegroundColor White
Write-Host "    . .\src\New-Password.ps1" -ForegroundColor Gray
Write-Host "    New-Password -Profile Strong" -ForegroundColor Gray
Write-Host "    New-Password -Profile Strong -SaveToStore -SecretName 'MyAppPassword'" -ForegroundColor Gray
Write-Host ""
