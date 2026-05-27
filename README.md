# PS-PasswordGenerator

A PowerShell password generator driven by JSON configuration profiles, using cryptographic randomness and optional Microsoft SecretManagement vault integration.

## Features

- **JSON-driven rules** — define character sets, length ranges, and complexity requirements in `config\password-rules.json`
- **Named profiles** — switch between pre-defined profiles (e.g. `Default`, `Strong`, `PIN`) without changing code
- **Cryptographic randomness** — uses `System.Security.Cryptography.RandomNumberGenerator` (CSRNG), never `Get-Random`
- **Microsoft SecretManagement integration** — optionally save generated passwords directly to a registered vault
- **WPF GUI** — dark-themed interactive window with profile selector, length slider, character-class toggles, clipboard auto-clear, and vault save
- **Pester 5 test suite** — full unit and integration tests under `tests\`

## Prerequisites

- PowerShell 7 or later
- [Microsoft.PowerShell.SecretManagement](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.secretmanagement/) module

  ```powershell
  Install-Module -Name Microsoft.PowerShell.SecretManagement -Scope CurrentUser
  ```

- A registered SecretManagement vault (required only when using `-SaveToStore`)

## Installation

Clone the repository — no build step is required:

```powershell
git clone https://github.com/<your-org>/PS-PasswordGenerator.git
cd PS-PasswordGenerator
```

## Usage

### 1. Generate a password with defaults

```powershell
. .\src\New-Password.ps1
New-Password
```

### 2. Use the Strong profile

```powershell
New-Password -Profile Strong
```

### 3. Generate and save to a SecretManagement vault

```powershell
New-Password -Profile Strong -SaveToStore -SecretName 'MyAppPassword'
```

## Configuration

Password rules are defined in `config\password-rules.json`. The file contains a `Defaults` section (applied when no profile is specified) and a `Profiles` section with named overrides.

Each entry can specify:

| Key | Description |
|-----|-------------|
| `Length` | Fixed length, or use `MinLength` / `MaxLength` for a range |
| `IncludeUppercase` | Include A–Z characters |
| `IncludeLowercase` | Include a–z characters |
| `IncludeDigits` | Include 0–9 characters |
| `IncludeSymbols` | Include special/symbol characters |
| `ExcludeAmbiguous` | Exclude visually similar characters (e.g. `0`, `O`, `l`, `1`) |

Example snippet:

```json
{
  "Defaults": {
    "Length": 16,
    "IncludeUppercase": true,
    "IncludeLowercase": true,
    "IncludeDigits": true,
    "IncludeSymbols": false
  },
  "Profiles": {
    "Strong": {
      "Length": 24,
      "IncludeSymbols": true
    }
  }
}
```

## GUI

Launch the interactive WPF front-end (requires PowerShell 7+ and .NET WPF assemblies, included with Windows):

```powershell
pwsh -File .\gui\Start-PasswordGeneratorGUI.ps1
```

The GUI lets you pick a profile, adjust the length with a slider, toggle character classes, copy to clipboard (auto-clears after 30 seconds), and save directly to a SecretManagement vault — all without touching the command line.

## Running Tests

```powershell
Invoke-Pester .\tests\ -Output Detailed
```

## License

MIT
