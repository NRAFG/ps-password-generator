#Requires -Version 5.1
<#
.SYNOPSIS
    WPF GUI front-end for the PS-PasswordGenerator project.
.DESCRIPTION
    Loads profile rules from config\password-rules.json, dot-sources
    src\New-Password.ps1 and src\SecretStore.ps1, then presents a dark-themed
    WPF window for interactive password generation, clipboard management, and
    optional vault storage.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Assemblies
# ---------------------------------------------------------------------------
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ---------------------------------------------------------------------------
# Dot-source helpers
# ---------------------------------------------------------------------------
$srcRoot = Join-Path $PSScriptRoot '..\src'
. (Join-Path $srcRoot 'New-Password.ps1')
. (Join-Path $srcRoot 'SecretStore.ps1')

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------
$configPath = Join-Path $PSScriptRoot '..\config\password-rules.json'
$config     = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

# Build a merged rules hashtable for a given profile name ('' = defaults only)
function Get-MergedRules {
    param([string]$ProfileName)
    $rules = @{}
    foreach ($p in $config.defaults.PSObject.Properties) { $rules[$p.Name] = $p.Value }
    if ($ProfileName -ne '' -and $ProfileName -ne 'Default') {
        foreach ($p in $config.profiles.$ProfileName.PSObject.Properties) {
            $rules[$p.Name] = $p.Value
        }
    }
    return $rules
}

# ---------------------------------------------------------------------------
# XAML
# ---------------------------------------------------------------------------
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="PS-PasswordGenerator"
    Width="480" Height="560"
    ResizeMode="NoResize"
    WindowStartupLocation="CenterScreen"
    Background="#1E1E1E"
    Foreground="#D4D4D4"
    FontFamily="Segoe UI"
    FontSize="13">

    <Window.Resources>

        <!-- Base colours as named brushes -->
        <SolidColorBrush x:Key="BgWindow"   Color="#1E1E1E"/>
        <SolidColorBrush x:Key="BgPanel"    Color="#252526"/>
        <SolidColorBrush x:Key="BgControl"  Color="#3C3C3C"/>
        <SolidColorBrush x:Key="FgText"     Color="#D4D4D4"/>
        <SolidColorBrush x:Key="Accent"     Color="#0078D4"/>
        <SolidColorBrush x:Key="AccentHov"  Color="#1A86D8"/>
        <SolidColorBrush x:Key="ErrRed"     Color="#F44747"/>
        <SolidColorBrush x:Key="OkGreen"    Color="#4EC9B0"/>
        <SolidColorBrush x:Key="Border"     Color="#3F3F46"/>

        <!-- Label style -->
        <Style TargetType="Label">
            <Setter Property="Foreground"  Value="#D4D4D4"/>
            <Setter Property="FontFamily"  Value="Segoe UI"/>
            <Setter Property="FontSize"    Value="13"/>
            <Setter Property="Padding"     Value="0,2,0,2"/>
        </Style>

        <!-- TextBox style -->
        <Style TargetType="TextBox">
            <Setter Property="Background"         Value="#3C3C3C"/>
            <Setter Property="Foreground"         Value="#D4D4D4"/>
            <Setter Property="BorderBrush"        Value="#3F3F46"/>
            <Setter Property="BorderThickness"    Value="1"/>
            <Setter Property="Padding"            Value="4,3"/>
            <Setter Property="FontFamily"         Value="Segoe UI"/>
            <Setter Property="FontSize"           Value="13"/>
            <Setter Property="CaretBrush"         Value="#D4D4D4"/>
            <Setter Property="SelectionBrush"     Value="#0078D4"/>
        </Style>

        <!-- PasswordBox style -->
        <Style TargetType="PasswordBox">
            <Setter Property="Background"         Value="#3C3C3C"/>
            <Setter Property="Foreground"         Value="#D4D4D4"/>
            <Setter Property="BorderBrush"        Value="#3F3F46"/>
            <Setter Property="BorderThickness"    Value="1"/>
            <Setter Property="Padding"            Value="4,3"/>
            <Setter Property="FontFamily"         Value="Segoe UI"/>
            <Setter Property="FontSize"           Value="13"/>
            <Setter Property="CaretBrush"         Value="#D4D4D4"/>
            <Setter Property="SelectionBrush"     Value="#0078D4"/>
        </Style>

        <!-- ComboBox style -->
        <Style TargetType="ComboBox">
            <Setter Property="Background"         Value="#3C3C3C"/>
            <Setter Property="Foreground"         Value="#D4D4D4"/>
            <Setter Property="BorderBrush"        Value="#3F3F46"/>
            <Setter Property="BorderThickness"    Value="1"/>
            <Setter Property="Padding"            Value="4,3"/>
            <Setter Property="FontFamily"         Value="Segoe UI"/>
            <Setter Property="FontSize"           Value="13"/>
        </Style>

        <!-- Slider style -->
        <Style TargetType="Slider">
            <Setter Property="Foreground" Value="#0078D4"/>
        </Style>

        <!-- CheckBox style -->
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#D4D4D4"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="FontSize"   Value="13"/>
            <Setter Property="Margin"     Value="0,3,12,3"/>
        </Style>

        <!-- Accent Button style -->
        <Style x:Key="AccentButton" TargetType="Button">
            <Setter Property="Background"      Value="#0078D4"/>
            <Setter Property="Foreground"      Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding"         Value="14,5"/>
            <Setter Property="FontFamily"      Value="Segoe UI"/>
            <Setter Property="FontSize"        Value="13"/>
            <Setter Property="Cursor"          Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}"
                                CornerRadius="3" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#1A86D8"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#005A9E"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Bd" Property="Background" Value="#555555"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Secondary Button style -->
        <Style x:Key="SecButton" TargetType="Button">
            <Setter Property="Background"      Value="#3C3C3C"/>
            <Setter Property="Foreground"      Value="#D4D4D4"/>
            <Setter Property="BorderBrush"     Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"         Value="10,5"/>
            <Setter Property="FontFamily"      Value="Segoe UI"/>
            <Setter Property="FontSize"        Value="13"/>
            <Setter Property="Cursor"          Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="3" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#4A4A4A"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#2A2A2A"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ToggleButton style (Show/Hide) -->
        <Style x:Key="ToggleBtn" TargetType="ToggleButton">
            <Setter Property="Background"      Value="#3C3C3C"/>
            <Setter Property="Foreground"      Value="#D4D4D4"/>
            <Setter Property="BorderBrush"     Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"         Value="8,4"/>
            <Setter Property="FontFamily"      Value="Segoe UI"/>
            <Setter Property="FontSize"        Value="12"/>
            <Setter Property="Cursor"          Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToggleButton">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="3" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#0078D4"/>
                                <Setter TargetName="Bd" Property="BorderBrush" Value="#0078D4"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#4A4A4A"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

    </Window.Resources>

    <DockPanel LastChildFill="True">

        <!-- Status bar at the bottom -->
        <Border DockPanel.Dock="Bottom"
                Background="#252526"
                BorderBrush="#3F3F46"
                BorderThickness="0,1,0,0"
                Padding="10,5">
            <TextBlock x:Name="StatusBar"
                       Foreground="#D4D4D4"
                       FontFamily="Segoe UI"
                       FontSize="12"
                       Text="Ready."
                       TextTrimming="CharacterEllipsis"/>
        </Border>

        <!-- Main scroll area -->
        <ScrollViewer VerticalScrollBarVisibility="Auto"
                      Background="#1E1E1E">
            <StackPanel Margin="18,14,18,14" >

                <!-- ── Profile ─────────────────────────────────────────── -->
                <Border Background="#252526" BorderBrush="#3F3F46"
                        BorderThickness="1" CornerRadius="4"
                        Padding="14,10" Margin="0,0,0,10">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Label Grid.Column="0" Content="Profile" VerticalAlignment="Center"
                               Width="100"/>
                        <ComboBox x:Name="ProfileCombo" Grid.Column="1"
                                  VerticalAlignment="Center"/>
                    </Grid>
                </Border>

                <!-- ── Length ──────────────────────────────────────────── -->
                <Border Background="#252526" BorderBrush="#3F3F46"
                        BorderThickness="1" CornerRadius="4"
                        Padding="14,10" Margin="0,0,0,10">
                    <StackPanel>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="60"/>
                            </Grid.ColumnDefinitions>
                            <Label Grid.Column="0" Content="Length" VerticalAlignment="Center"
                                   Width="100"/>
                            <Slider x:Name="LengthSlider" Grid.Column="1"
                                    Minimum="4" Maximum="128" Value="20"
                                    TickFrequency="1" IsSnapToTickEnabled="True"
                                    VerticalAlignment="Center" Margin="0,0,8,0"/>
                            <TextBox x:Name="LengthBox" Grid.Column="2"
                                     Text="20" TextAlignment="Center"
                                     VerticalAlignment="Center"/>
                        </Grid>
                        <TextBlock x:Name="LengthRangeLabel"
                                   Foreground="#888888" FontSize="11"
                                   Margin="100,2,0,0" Text="Range: 8 – 128"/>
                    </StackPanel>
                </Border>

                <!-- ── Character classes ───────────────────────────────── -->
                <Border Background="#252526" BorderBrush="#3F3F46"
                        BorderThickness="1" CornerRadius="4"
                        Padding="14,10" Margin="0,0,0,10">
                    <StackPanel>
                        <Label Content="Character Classes" Margin="0,0,0,4"/>
                        <WrapPanel Margin="0,2,0,0">
                            <CheckBox x:Name="ChkUpper"   Content="Uppercase (A-Z)"  IsChecked="True"/>
                            <CheckBox x:Name="ChkLower"   Content="Lowercase (a-z)"  IsChecked="True"/>
                            <CheckBox x:Name="ChkDigits"  Content="Digits (0-9)"     IsChecked="True"/>
                            <CheckBox x:Name="ChkSpecial" Content="Special (!@#…)"   IsChecked="True"/>
                        </WrapPanel>
                    </StackPanel>
                </Border>

                <!-- ── Generate ────────────────────────────────────────── -->
                <Button x:Name="GenerateBtn"
                        Content="Generate Password"
                        Style="{StaticResource AccentButton}"
                        Height="34" Margin="0,0,0,10"/>

                <!-- ── Output ──────────────────────────────────────────── -->
                <Border Background="#252526" BorderBrush="#3F3F46"
                        BorderThickness="1" CornerRadius="4"
                        Padding="14,10" Margin="0,0,0,10">
                    <StackPanel>
                        <Label Content="Generated Password" Margin="0,0,0,4"/>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <!-- Plain-text view (visible when Show is on) -->
                            <TextBox x:Name="PasswordPlain"
                                     Grid.Column="0"
                                     IsReadOnly="True"
                                     FontFamily="Consolas"
                                     FontSize="14"
                                     Visibility="Collapsed"
                                     Margin="0,0,6,0"/>

                            <!-- Masked view (default) -->
                            <PasswordBox x:Name="PasswordMasked"
                                         Grid.Column="0"
                                         IsEnabled="False"
                                         FontFamily="Consolas"
                                         FontSize="14"
                                         Margin="0,0,6,0"/>

                            <ToggleButton x:Name="ShowHideBtn"
                                          Grid.Column="1"
                                          Style="{StaticResource ToggleBtn}"
                                          Content="Show"
                                          Width="52"
                                          VerticalAlignment="Center"/>
                        </Grid>

                        <!-- Copy row -->
                        <Grid Margin="0,8,0,0">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Button x:Name="CopyBtn"
                                    Grid.Column="0"
                                    Content="Copy to Clipboard"
                                    Style="{StaticResource SecButton}"/>
                            <TextBlock x:Name="ClipCountdown"
                                       Grid.Column="1"
                                       Foreground="#888888"
                                       FontSize="12"
                                       VerticalAlignment="Center"
                                       Margin="10,0,0,0"
                                       Text=""/>
                        </Grid>
                    </StackPanel>
                </Border>

                <!-- ── Save to vault ───────────────────────────────────── -->
                <Border Background="#252526" BorderBrush="#3F3F46"
                        BorderThickness="1" CornerRadius="4"
                        Padding="14,10" Margin="0,0,0,6">
                    <StackPanel>
                        <CheckBox x:Name="SaveVaultChk" Content="Save to vault"
                                  Margin="0,0,0,0"/>

                        <StackPanel x:Name="VaultPanel" Visibility="Collapsed"
                                    Margin="0,8,0,0">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBox x:Name="SecretNameBox"
                                         Grid.Column="0"
                                         Margin="0,0,6,0"
                                         ToolTip="Secret name in the vault"/>
                                <Button x:Name="SaveVaultBtn"
                                        Grid.Column="1"
                                        Content="Save"
                                        Style="{StaticResource AccentButton}"/>
                            </Grid>
                            <TextBlock x:Name="VaultFeedback"
                                       Margin="0,6,0,0"
                                       FontSize="12"
                                       Text=""/>
                        </StackPanel>
                    </StackPanel>
                </Border>

            </StackPanel>
        </ScrollViewer>
    </DockPanel>
</Window>
"@

# ---------------------------------------------------------------------------
# Load window
# ---------------------------------------------------------------------------
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# ---------------------------------------------------------------------------
# Grab controls
# ---------------------------------------------------------------------------
$ProfileCombo    = $window.FindName('ProfileCombo')
$LengthSlider    = $window.FindName('LengthSlider')
$LengthBox       = $window.FindName('LengthBox')
$LengthRangeLabel= $window.FindName('LengthRangeLabel')
$ChkUpper        = $window.FindName('ChkUpper')
$ChkLower        = $window.FindName('ChkLower')
$ChkDigits       = $window.FindName('ChkDigits')
$ChkSpecial      = $window.FindName('ChkSpecial')
$GenerateBtn     = $window.FindName('GenerateBtn')
$PasswordPlain   = $window.FindName('PasswordPlain')
$PasswordMasked  = $window.FindName('PasswordMasked')
$ShowHideBtn     = $window.FindName('ShowHideBtn')
$CopyBtn         = $window.FindName('CopyBtn')
$ClipCountdown   = $window.FindName('ClipCountdown')
$SaveVaultChk    = $window.FindName('SaveVaultChk')
$VaultPanel      = $window.FindName('VaultPanel')
$SecretNameBox   = $window.FindName('SecretNameBox')
$SaveVaultBtn    = $window.FindName('SaveVaultBtn')
$VaultFeedback   = $window.FindName('VaultFeedback')
$StatusBar       = $window.FindName('StatusBar')

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
$script:CurrentPassword = ''
$script:ClipTimer       = $null
$script:ClipSecondsLeft = 0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Set-Status {
    param([string]$Message, [string]$Color = '#D4D4D4')
    $StatusBar.Text       = $Message
    $StatusBar.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
}

function Set-VaultFeedback {
    param([string]$Message, [string]$Color = '#D4D4D4')
    $VaultFeedback.Text       = $Message
    $VaultFeedback.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
}

function Stop-ClipTimer {
    if ($null -ne $script:ClipTimer) {
        $script:ClipTimer.Stop()
        $script:ClipTimer = $null
    }
    $ClipCountdown.Text = ''
}

function Apply-ProfileToUI {
    param([string]$ProfileName)

    $rules = Get-MergedRules -ProfileName $ProfileName

    $min = [int]$rules['minLength']
    $max = [int]$rules['maxLength']
    $def = [int]$rules['defaultLength']

    # Clamp default to range
    if ($def -lt $min) { $def = $min }
    if ($def -gt $max) { $def = $max }

    $LengthSlider.Minimum = $min
    $LengthSlider.Maximum = $max
    # Clamp current value
    $cur = [int]$LengthSlider.Value
    if ($cur -lt $min) { $cur = $min }
    if ($cur -gt $max) { $cur = $max }
    $LengthSlider.Value = $cur
    # Set to profile default on first load / explicit profile change
    $LengthSlider.Value = $def
    $LengthBox.Text     = "$def"
    $LengthRangeLabel.Text = "Range: $min - $max"

    $ChkUpper.IsChecked   = [bool]$rules['requireUppercase']
    $ChkLower.IsChecked   = [bool]$rules['requireLowercase']
    $ChkDigits.IsChecked  = [bool]$rules['requireDigits']
    $ChkSpecial.IsChecked = [bool]$rules['requireSpecialChars']
}

# Build args hashtable from current UI state for New-Password
function Get-PasswordArgs {
    $profileName = $ProfileCombo.SelectedItem
    $length      = [int]$LengthSlider.Value

    # We always pass explicit character-class overrides by building a temporary
    # in-memory config path isn't practical, so we rely on New-Password using
    # the profile as a base and pass Length; for character class overrides we
    # manipulate what the function sees via a wrapped call with an ad-hoc
    # config written to a temp file.
    #
    # Strategy: build a merged rules object from UI state, write to a temp
    # JSON, then call New-Password pointing at that temp file (no profile).

    $rules = Get-MergedRules -ProfileName $profileName

    # Override character classes with UI checkboxes
    $rules['requireUppercase']   = [bool]$ChkUpper.IsChecked
    $rules['requireLowercase']   = [bool]$ChkLower.IsChecked
    $rules['requireDigits']      = [bool]$ChkDigits.IsChecked
    $rules['requireSpecialChars']= [bool]$ChkSpecial.IsChecked

    # Ensure minimums are zero for disabled classes
    if (-not $rules['requireUppercase'])    { $rules['minUppercase']   = 0 }
    if (-not $rules['requireLowercase'])    { $rules['minLowercase']   = 0 }
    if (-not $rules['requireDigits'])       { $rules['minDigits']      = 0 }
    if (-not $rules['requireSpecialChars']) { $rules['minSpecialChars']= 0 }

    # Set length
    $rules['defaultLength'] = $length
    $rules['minLength']     = [int]$LengthSlider.Minimum
    $rules['maxLength']     = [int]$LengthSlider.Maximum

    # Write temp config
    $tempConfig = @{ defaults = $rules; profiles = @{} }
    $tempJson   = $tempConfig | ConvertTo-Json -Depth 5
    $tempFile   = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tempFile, $tempJson, [System.Text.Encoding]::UTF8)

    return $tempFile
}

# ---------------------------------------------------------------------------
# Populate profile ComboBox
# ---------------------------------------------------------------------------
$profiles = @('Default') + @($config.profiles.PSObject.Properties.Name)
foreach ($p in $profiles) { [void]$ProfileCombo.Items.Add($p) }
$ProfileCombo.SelectedIndex = 0
Apply-ProfileToUI -ProfileName 'Default'

# ---------------------------------------------------------------------------
# Event: profile selection changed
# ---------------------------------------------------------------------------
$ProfileCombo.Add_SelectionChanged({
    $selected = $ProfileCombo.SelectedItem
    Apply-ProfileToUI -ProfileName $selected
    Set-Status "Profile '$selected' loaded."
})

# ---------------------------------------------------------------------------
# Event: slider changed -> sync TextBox
# ---------------------------------------------------------------------------
$LengthSlider.Add_ValueChanged({
    $v = [int]$LengthSlider.Value
    if ($LengthBox.Text -ne "$v") { $LengthBox.Text = "$v" }
})

# ---------------------------------------------------------------------------
# Event: TextBox changed -> sync slider (validate input)
# ---------------------------------------------------------------------------
$LengthBox.Add_TextChanged({
    $raw = $LengthBox.Text
    $n   = 0
    if ([int]::TryParse($raw, [ref]$n)) {
        $min = [int]$LengthSlider.Minimum
        $max = [int]$LengthSlider.Maximum
        if ($n -ge $min -and $n -le $max) {
            if ([int]$LengthSlider.Value -ne $n) { $LengthSlider.Value = $n }
        }
    }
})

# ---------------------------------------------------------------------------
# Event: Show/Hide toggle
# ---------------------------------------------------------------------------
$ShowHideBtn.Add_Checked({
    $PasswordPlain.Visibility   = [System.Windows.Visibility]::Visible
    $PasswordMasked.Visibility  = [System.Windows.Visibility]::Collapsed
    $ShowHideBtn.Content        = 'Hide'
})

$ShowHideBtn.Add_Unchecked({
    $PasswordPlain.Visibility   = [System.Windows.Visibility]::Collapsed
    $PasswordMasked.Visibility  = [System.Windows.Visibility]::Visible
    $ShowHideBtn.Content        = 'Show'
})

# ---------------------------------------------------------------------------
# Event: Generate button
# ---------------------------------------------------------------------------
$GenerateBtn.Add_Click({
    $tempFile = $null
    try {
        $tempFile = Get-PasswordArgs
        $pwd      = New-Password -ConfigPath $tempFile -Length ([int]$LengthSlider.Value)

        $script:CurrentPassword = $pwd
        $PasswordPlain.Text     = $pwd
        $PasswordMasked.Password= $pwd

        Set-Status "Password generated  ($($pwd.Length) characters)."
        Set-VaultFeedback ''
    }
    catch {
        Set-Status "Error: $($_.Exception.Message)" '#F44747'
    }
    finally {
        if ($null -ne $tempFile -and (Test-Path $tempFile)) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
})

# ---------------------------------------------------------------------------
# Event: Copy button + clipboard countdown timer
# ---------------------------------------------------------------------------
$CopyBtn.Add_Click({
    if ($script:CurrentPassword -eq '') {
        Set-Status 'Nothing to copy — generate a password first.' '#F44747'
        return
    }

    # Stop any running timer first
    Stop-ClipTimer

    [System.Windows.Clipboard]::SetText($script:CurrentPassword)
    Set-Status 'Password copied to clipboard.'

    $script:ClipSecondsLeft = 30
    $ClipCountdown.Text     = "Clipboard clears in 30s"

    $script:ClipTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $script:ClipTimer.Interval = [TimeSpan]::FromSeconds(1)

    $script:ClipTimer.Add_Tick({
        $script:ClipSecondsLeft--
        if ($script:ClipSecondsLeft -le 0) {
            [System.Windows.Clipboard]::Clear()
            Stop-ClipTimer
            Set-Status 'Clipboard cleared.'
        }
        else {
            $ClipCountdown.Text = "Clipboard clears in $($script:ClipSecondsLeft)s"
        }
    })

    $script:ClipTimer.Start()
})

# ---------------------------------------------------------------------------
# Event: Save to vault checkbox
# ---------------------------------------------------------------------------
$SaveVaultChk.Add_Checked({
    $VaultPanel.Visibility = [System.Windows.Visibility]::Visible
})

$SaveVaultChk.Add_Unchecked({
    $VaultPanel.Visibility = [System.Windows.Visibility]::Collapsed
    Set-VaultFeedback ''
})

# ---------------------------------------------------------------------------
# Event: Save button
# ---------------------------------------------------------------------------
$SaveVaultBtn.Add_Click({
    $secretName = $SecretNameBox.Text.Trim()
    if ($secretName -eq '') {
        Set-VaultFeedback 'Please enter a secret name.' '#F44747'
        return
    }
    if ($script:CurrentPassword -eq '') {
        Set-VaultFeedback 'Generate a password first.' '#F44747'
        return
    }

    try {
        Save-PasswordToStore -SecretName $secretName -PlainTextPassword $script:CurrentPassword
        Set-VaultFeedback "Saved as '$secretName'." '#4EC9B0'
        Set-Status "Password saved to vault as '$secretName'."
    }
    catch {
        $msg = $_.Exception.Message
        Set-VaultFeedback "Save failed: $msg" '#F44747'
        Set-Status "Vault error: $msg" '#F44747'
    }
})

# ---------------------------------------------------------------------------
# Clean up clipboard timer when window closes
# ---------------------------------------------------------------------------
$window.Add_Closed({
    Stop-ClipTimer
    [System.Windows.Clipboard]::Clear()
})

# ---------------------------------------------------------------------------
# Show
# ---------------------------------------------------------------------------
$window.ShowDialog() | Out-Null
