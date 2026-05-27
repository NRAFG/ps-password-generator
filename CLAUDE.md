# PS-PasswordGenerator — Claude Code Context

## Project Overview

PS-PasswordGenerator is a PowerShell password generator that reads complexity rules from a JSON configuration file and optionally persists generated passwords to a Microsoft SecretManagement vault. There is no compiled output; all code is plain PowerShell scripts.

## Directory Map

```
PS-PasswordGenerator\
  src\
    New-Password.ps1     # Main public function — entry point for all generation logic
    SecretStore.ps1      # Wrapper around Microsoft.PowerShell.SecretManagement cmdlets
  config\
    password-rules.json  # Defaults and named profiles (length, character sets, etc.)
  gui\
    Start-PasswordGeneratorGUI.ps1  # WPF dark-theme GUI front-end
  tests\
    *.Tests.ps1          # Pester 5 test files
```

## Key Conventions

- **Test framework**: Pester 5 only. Do not use Pester 4 syntax (`Should Be`, `Mock` without `-CommandName`, etc.).
- **Randomness**: Always use `[System.Security.Cryptography.RandomNumberGenerator]` (CSRNG). Never use `Get-Random` — it is not cryptographically secure.
- **Secret handling**: Plain-text passwords must not persist beyond the function boundary. The password string may be returned to the caller or handed directly to `Set-Secret`; it must not be written to disk, logged, or stored in a variable that outlives the call stack.
- **Error handling**: Use `$PSCmdlet.ThrowTerminatingError()` for fatal conditions rather than `throw` or `Write-Error` with `-ErrorAction Stop`.
- **Profiles**: Profile merging logic should apply `Defaults` first, then overlay the named profile. Missing keys in a profile inherit from `Defaults`.

## Running Tests

```powershell
Invoke-Pester .\tests\ -Output Detailed
```

To run a single test file:

```powershell
Invoke-Pester .\tests\New-Password.Tests.ps1 -Output Detailed
```

## Dependencies

- **Microsoft.PowerShell.SecretManagement** must be installed before dot-sourcing `src\SecretStore.ps1` or using `-SaveToStore`.

  ```powershell
  Install-Module -Name Microsoft.PowerShell.SecretManagement -Scope CurrentUser
  ```

- No specific vault is assumed. Tests that exercise vault integration should mock `Set-Secret` and `Get-Secret` rather than requiring a real vault at test time.
- No NuGet packages, no `#Requires` on third-party modules beyond SecretManagement — keep the dependency surface minimal.
