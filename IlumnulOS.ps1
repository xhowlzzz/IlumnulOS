# IlumnulOS CLI - Optimized by Assistant
# Windows 11 Optimization & Debloating Tool - CLI Edition

# Load required assemblies
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue
    Add-Type -AssemblyName WindowsBase -ErrorAction SilentlyContinue
} catch {}

# Initialize Paths
$ScriptPath = $PSScriptRoot
if (-not $ScriptPath) {
    if ($MyInvocation.MyCommand.Path) {
        $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $ScriptPath = Get-Location
    }
}
# Normalize path
if ($ScriptPath) { $ScriptPath = $ScriptPath.TrimEnd('\') }

# Bootstrapper: Check if modules exist, if not download them (simplified)
if (-not (Test-Path "$ScriptPath\Modules\RemoveAI.psm1")) {
    Write-Host "Remote Execution or Missing Modules Detected. Initializing Bootstrapper..." -ForegroundColor Cyan
    
    $InstallPath = "$env:USERPROFILE\Documents\IlumnulOS_CLI"
    $RepoUrl = "https://raw.githubusercontent.com/xhowlzzz/IlumnulOS/main"
    
    if (Test-Path $InstallPath) {
        Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    New-Item -ItemType Directory -Path "$InstallPath\Modules" -Force | Out-Null
    
    function Download-File {
        param($RemotePath, $LocalPath)
        $headers = @{ "User-Agent" = "PowerShell" }
        $BaseUrl = "https://raw.githubusercontent.com/xhowlzzz/IlumnulOS/main"
        try {
            Invoke-WebRequest -Uri "$BaseUrl/$RemotePath" -OutFile $LocalPath -Headers $headers -ErrorAction Stop
            Write-Host " [OK] Downloaded $RemotePath" -ForegroundColor Green
            return $true
        } catch {
            Write-Host " [FAILED] Could not download $RemotePath" -ForegroundColor Red
            return $false
        }
    }

    $requiredFiles = @(
        @{ Remote = "Modules/Debloat.psm1"; Local = "$InstallPath\Modules\Debloat.psm1" },
        @{ Remote = "Modules/Gaming.psm1"; Local = "$InstallPath\Modules\Gaming.psm1" },
        @{ Remote = "Modules/Optimize.psm1"; Local = "$InstallPath\Modules\Optimize.psm1" },
        @{ Remote = "Modules/RemoveAI.psm1"; Local = "$InstallPath\Modules\RemoveAI.psm1" }
    )

    $hasFailure = $false
    foreach ($file in $requiredFiles) {
        if (-not (Download-File $file.Remote $file.Local)) { $hasFailure = $true }
    }
    if ($hasFailure) {
        Read-Host "CRITICAL: Some files failed to download. Press Enter to exit..."
        return
    }
    $ScriptPath = $InstallPath
}

# Import Modules
Write-Host "Importing modules..." -ForegroundColor Cyan
if (Test-Path "$ScriptPath\Modules\Debloat.psm1") { Import-Module "$ScriptPath\Modules\Debloat.psm1" -Force }
if (Test-Path "$ScriptPath\Modules\Optimize.psm1") { Import-Module "$ScriptPath\Modules\Optimize.psm1" -Force }
if (Test-Path "$ScriptPath\Modules\Gaming.psm1") { Import-Module "$ScriptPath\Modules\Gaming.psm1" -Force }
if (Test-Path "$ScriptPath\Modules\RemoveAI.psm1") { Import-Module "$ScriptPath\Modules\RemoveAI.psm1" -Force }

# Audio Helper (MCI API for maximum reliability)
$mciSource = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class AudioPlayer {
    [DllImport("winmm.dll")]
    private static extern long mciSendString(string command, StringBuilder returnValue, int returnLength, IntPtr winHandle);

    public static void Play(string fileName) {
        mciSendString("close myDevice", null, 0, IntPtr.Zero);
        mciSendString("open \"" + fileName + "\" type mpegvideo alias myDevice", null, 0, IntPtr.Zero);
        mciSendString("setaudio myDevice volume to 100", null, 0, IntPtr.Zero); // 100 out of 1000 is 10%
        mciSendString("play myDevice repeat", null, 0, IntPtr.Zero);
    }

    public static void Stop() {
        mciSendString("stop myDevice", null, 0, IntPtr.Zero);
        mciSendString("close myDevice", null, 0, IntPtr.Zero);
    }
}
"@
try {
    Add-Type -TypeDefinition $mciSource -ErrorAction SilentlyContinue
} catch {}

function Start-Music {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        $absPath = (Get-Item $FilePath).FullName
        [AudioPlayer]::Play($absPath)
    }
}

function Stop-Music {
    [AudioPlayer]::Stop()
}

# CLI Color & UI Helpers
function Get-GradientText {
    param([string]$Text, [int]$R1, [int]$G1, [int]$B1, [int]$R2, [int]$G2, [int]$B2)
    $len = $Text.Length
    if ($len -le 1) { return $Text }
    $result = ""
    for ($i = 0; $i -lt $len; $i++) {
        $r = [int]($R1 + ($R2 - $R1) * ($i / ($len - 1)))
        $g = [int]($G1 + ($G2 - $G1) * ($i / ($len - 1)))
        $b = [int]($B1 + ($B2 - $B1) * ($i / ($len - 1)))
        $result += "$([char]27)[38;2;$r;$g;${b}m$($Text[$i])"
    }
    return "$result$([char]27)[0m"
}

function Write-Spinner {
    param([string]$Message)
    $frames = @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏")
    $esc = [char]27
    $cyan = "$esc[36m"
    $reset = "$esc[0m"
    for ($i = 0; $i -lt 10; $i++) {
        Write-Host "`r$cyan$($frames[$i % 10])$reset $Message" -NoNewline
        Start-Sleep -Milliseconds 50
    }
    Write-Host "`r   $Message" -NoNewline # Clean up
}

function Get-HardwareInfo {
    try {
        $cpu = (Get-CimInstance Win32_Processor).Name.Trim()
        $gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name.Trim()
        $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)
        return @{ CPU = $cpu; GPU = $gpu; RAM = "$ram GB" }
    } catch {
        return @{ CPU = "Unknown"; GPU = "Unknown"; RAM = "Unknown" }
    }
}

function Write-Typewriter {
    param([string]$Text, [int]$Delay = 10, [string]$Color = "White")
    $chars = $Text.ToCharArray()
    foreach ($c in $chars) {
        Write-Host $c -NoNewline -ForegroundColor $Color
        Start-Sleep -Milliseconds $Delay
    }
    Write-Host ""
}

# CLI Logger Helper (Updated with Icons)
$cliLogger = [Action[string]] { 
    param($msg) 
    $timestamp = Get-Date -Format "HH:mm:ss"
    $esc = [char]27
    $bold = "$esc[1m"
    $reset = "$esc[0m"
    
    # Status Icons
    $iconOk = "$([char]0x2714)"      # Checkmark
    $iconFail = "$([char]0x2718)"    # X
    $iconWarn = "$([char]0x26A0)"    # Warning Triangle
    $iconSkull = "$([char]0x2620)"   # Skull
    
    if ($msg -match 'Error' -or $msg -match 'FAILED') {
        Write-Host "[$timestamp] $bold$([char]0x2503)$reset " -NoNewline -ForegroundColor Gray; Write-Host "$iconFail $msg" -ForegroundColor Red
    } elseif ($msg -match 'Success' -or $msg -match 'OK' -or $msg -match 'Finished' -or $msg -match 'completed successfully') {
        Write-Host "[$timestamp] $bold$([char]0x2503)$reset " -NoNewline -ForegroundColor Gray; Write-Host "$iconOk $msg" -ForegroundColor Green
    } elseif ($msg -match 'Warning' -or $msg -match 'skipped') {
        Write-Host "[$timestamp] $bold$([char]0x2503)$reset " -NoNewline -ForegroundColor Gray; Write-Host "$iconWarn $msg" -ForegroundColor Yellow
    } elseif ($msg -match 'Removing' -or $msg -match 'Disabling' -or $msg -match 'Purging') {
        Write-Host "[$timestamp] $bold$([char]0x2503)$reset " -NoNewline -ForegroundColor Gray; Write-Host "$iconSkull $msg" -ForegroundColor Magenta
    } elseif ($msg -match '^\[\d/\d\]') {
        # Section Headers
        $headerText = " $msg "
        $borderLine = ([string][char]0x2550) * ($headerText.Length)
        Write-Host ""
        Write-Host ("$bold$([char]0x2554)$borderLine$([char]0x2557)") -ForegroundColor Cyan
        Write-Host ("$([char]0x2551)$headerText$([char]0x2551)") -ForegroundColor Cyan
        Write-Host ("$([char]0x255A)$borderLine$([char]0x255D)$reset") -ForegroundColor Cyan
    } else {
        Write-Host "[$timestamp] $bold$([char]0x2503)$reset " -NoNewline -ForegroundColor Gray; Write-Host "$msg" -ForegroundColor White
    }
}

function Write-ProgressBar {
    param([int]$Current, [int]$Total, [string]$Status = "")
    $width = 40
    $percent = [int]($Current / $Total * 100)
    $filled = [int]($Current / $Total * $width)
    $empty = $width - $filled
    
    # Dynamic Color based on percent
    $color = "Red"
    if ($percent -ge 50) { $color = "Yellow" }
    if ($percent -ge 90) { $color = "Green" }
    
    $bar = ([string][char]0x2588 * $filled) + ([string][char]0x2591 * $empty)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "`r[$timestamp] [$bar] $percent% $Status" -NoNewline -ForegroundColor $color
    if ($Current -eq $Total) { Write-Host "" }
}

function Write-HwLine {
    param($Label, $Value)
    $Width = 52
    $esc = [char]27
    $gray = "$esc[90m"
    $cyan = "$esc[36m"
    $reset = "$esc[0m"
    $boxMid = "$([char]0x2551)"
    
    $fullText = "$Label : $Value"
    if ($fullText.Length -gt $Width) { 
        # Truncate value if too long
        $maxValLen = $Width - $Label.Length - 3
        if ($maxValLen -gt 0) {
            $Value = $Value.Substring(0, $maxValLen)
            $fullText = "$Label : $Value"
        }
    }
    
    $pad = $Width - $fullText.Length
    if ($pad -lt 0) { $pad = 0 }
    $l = [math]::Floor($pad / 2)
    $r = $pad - $l
    
    Write-Host "  $gray$boxMid$reset" -NoNewline
    Write-Host (" " * $l) -NoNewline
    Write-Host "$cyan$Label :$reset $Value" -NoNewline
    Write-Host (" " * $r) -NoNewline
    Write-Host "$gray$boxMid$reset"
}

function Show-Header {
    Clear-Host
    $esc = [char]27
    $bold = "$esc[1m"
    $reset = "$esc[0m"

    # Gradient ASCII Art
    $lines = @(
        "    __  __                          __ ____  _____",
        "   / / / /_  ______ ___  ____  __  __/ / __ \/ ___/",
        "  / / / / / / / __ `__ \/ __ \/ / / / / / / /\__ \ ",
        " / /_/ / /_/ / / / / / / / / / /_/ / / /_/ /___/ / ",
        " \____/\__,_/_/ /_/ /_/_/ /_/\__,_/_/\____//____/  "
    )
    foreach ($line in $lines) {
        Write-Host (Get-GradientText $line 150 0 255 0 255 255)
    }
    
    $subtitle = "          Windows 11 Ultimate Optimization Tool"
    Write-Host (Get-GradientText $subtitle 0 255 255 255 255 255)
    
    # Hardware Info Box
    $hw = Get-HardwareInfo
    $esc = [char]27
    $cyan = "$esc[36m"
    $gray = "$esc[90m"
    $reset = "$esc[0m"
    $boxTop = ([string][char]0x2554) + ([string][char]0x2550 * 52) + ([string][char]0x2557)
    $boxMid = ([string][char]0x2551)
    $boxBot = ([string][char]0x255A) + ([string][char]0x2550 * 52) + ([string][char]0x255D)

    Write-Host ""
    Write-Host "  $gray$boxTop$reset"
    Write-HwLine "CPU" $hw.CPU
    Write-HwLine "GPU" $hw.GPU
    Write-HwLine "RAM" $hw.RAM
    Write-Host "  $gray$boxBot$reset"
    
    $borderLine = ([string][char]0x2500) * 54
    Write-Host "  $borderLine" -ForegroundColor Gray
}

function Get-MenuSelection {
    param([string[]]$Options)
    $selectedIndex = 0
    $esc = [char]27
    $bold = "$esc[1m"
    $cyan = "$esc[36m"
    $reset = "$esc[0m"

    while ($true) {
        Show-Header
        Write-Host ""
        for ($i = 0; $i -lt $Options.Count; $i++) {
            if ($i -eq $selectedIndex) {
                Write-Host "    $bold$cyan > $($Options[$i])$reset" -ForegroundColor Cyan
            } else {
                Write-Host "      $($Options[$i])" -ForegroundColor Gray
            }
        }
        Write-Host ""
        $borderLine = ([string][char]0x2500) * 54
        Write-Host "  $borderLine" -ForegroundColor Gray
        Write-Host "  Use Up/Down arrows to navigate, Enter to select." -ForegroundColor DarkGray

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($key.VirtualKeyCode -eq 38) { # Up
            $selectedIndex = if ($selectedIndex -eq 0) { $Options.Count - 1 } else { $selectedIndex - 1 }
        } elseif ($key.VirtualKeyCode -eq 40) { # Down
            $selectedIndex = if ($selectedIndex -eq $Options.Count - 1) { 0 } else { $selectedIndex + 1 }
        } elseif ($key.VirtualKeyCode -eq 13) { # Enter
            return $selectedIndex
        }
    }
}

# Main Entry Point
$global:MusicEnabled = $true
Show-Header
Write-Typewriter " [SYSTEM] Initializing IlumnulOS Ultimate v2.0..." -Delay 15 -Color Cyan
Write-Typewriter " [SYSTEM] Loading modules and verifying environment..." -Delay 10 -Color Gray
Start-Sleep -Seconds 1

# Main Loop - Pre-calculate Hardware Info ONCE
$global:cachedHwInfo = Get-HardwareInfo

# Optimized Show-Header using Cached Info
function Show-Header-Optimized {
    param([bool]$clear = $true)
    if ($clear) { Clear-Host }
    $esc = [char]27
    $bold = "$esc[1m"
    $reset = "$esc[0m"

    # Gradient ASCII Art
    $lines = @(
        "    __  __                          __ ____  _____",
        "   / / / /_  ______ ___  ____  __  __/ / __ \/ ___/",
        "  / / / / / / / __ `__ \/ __ \/ / / / / / / /\__ \ ",
        " / /_/ / /_/ / / / / / / / / / /_/ / / /_/ /___/ / ",
        " \____/\__,_/_/ /_/ /_/_/ /_/\__,_/_/\____//____/  "
    )
    foreach ($line in $lines) {
        Write-Host (Get-GradientText $line 150 0 255 0 255 255)
    }
    
    $subtitle = "          Windows 11 Ultimate Optimization Tool"
    Write-Host (Get-GradientText $subtitle 0 255 255 255 255 255)
    
    # Use Cached Hardware Info
    $hw = $global:cachedHwInfo
    $cyan = "$esc[36m"
    $gray = "$esc[90m"
    $boxTop = ([string][char]0x2554) + ([string][char]0x2550 * 52) + ([string][char]0x2557)
    $boxMid = ([string][char]0x2551)
    $boxBot = ([string][char]0x255A) + ([string][char]0x2550 * 52) + ([string][char]0x255D)

    Write-Host ""
    Write-Host "  $gray$boxTop$reset"
    Write-HwLine "CPU" $hw.CPU
    Write-HwLine "GPU" $hw.GPU
    Write-HwLine "RAM" $hw.RAM
    Write-Host "  $gray$boxBot$reset"
    
    $borderLine = ([string][char]0x2500) * 54
    Write-Host "  $borderLine" -ForegroundColor Gray
}

# Main Loop
while ($true) {
    $esc = [char]27
    $green = "$esc[32m"
    $gray = "$esc[90m"
    $reset = "$esc[0m"
    
    $musicToggle = if ($global:MusicEnabled) { "$green$([string][char]0x25CF)$([string][char]0x2500)$([string][char]0x2500)$([string][char]0x2500)$gray$([string][char]0x25CB)$reset ON " } else { "$gray$([string][char]0x25CB)$([string][char]0x2500)$([string][char]0x2500)$([string][char]0x2500)$reset$([string][char]0x25CF) OFF" }
    
    $menuOptions = @("Start Optimization (Full Suite)", "Music: [$musicToggle]", "Exit")
    
    # Inline Menu Logic for Maximum Speed
    $selectedIndex = 0
    $inMenu = $true
    
    # Draw initial header
    Show-Header-Optimized -clear $true
    
    while ($inMenu) {
        # Only redraw menu part by moving cursor
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, 15) # Adjust based on header height
        
        Write-Host ""
        $cyan = "$esc[36m"
        $bold = "$esc[1m"
        
        for ($i = 0; $i -lt $menuOptions.Count; $i++) {
            # Clear line first
            Write-Host (" " * 80) -NoNewline 
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, $Host.UI.RawUI.CursorPosition.Y)
            
            if ($i -eq $selectedIndex) {
                Write-Host "    $bold$cyan > $($menuOptions[$i])$reset" -ForegroundColor Cyan
            } else {
                Write-Host "      $($menuOptions[$i])" -ForegroundColor Gray
            }
        }
        Write-Host ""
        $borderLine = ([string][char]0x2500) * 54
        Write-Host "  $borderLine" -ForegroundColor Gray
        Write-Host "  Use Up/Down arrows to navigate, Enter to select." -ForegroundColor DarkGray

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($key.VirtualKeyCode -eq 38) { # Up
            $selectedIndex = if ($selectedIndex -eq 0) { $menuOptions.Count - 1 } else { $selectedIndex - 1 }
        } elseif ($key.VirtualKeyCode -eq 40) { # Down
            $selectedIndex = if ($selectedIndex -eq $menuOptions.Count - 1) { 0 } else { $selectedIndex + 1 }
        } elseif ($key.VirtualKeyCode -eq 13) { # Enter
            $choiceIndex = $selectedIndex
            $inMenu = $false
        }
    }

    if ($choiceIndex -eq 0) {
        $esc = [char]27
        $bold = "$esc[1m"
        $reset = "$esc[0m"

        Clear-Host
        Show-Header
        
        if ($global:MusicEnabled) {
            $musicPath = "$ScriptPath\Modules\IlumnulOS.mp3"
            if (Test-Path $musicPath) {
                Start-Music -FilePath $musicPath
                $cliLogger.Invoke("Playing background music: IlumnulOS.mp3")
            }
        }
        
        Write-Typewriter " [OPTIMIZE] Starting system-wide optimization..." -Delay 20 -Color Green
        Start-Sleep -Seconds 1
        
        # Draw the Log Box (Fixed Terminal Window)
        Write-Host ""
        $boxTop = ([string][char]0x2554) + ([string][char]0x2550 * 100) + ([string][char]0x2557)
        $boxMid = ([string][char]0x2551)
        $boxBot = ([string][char]0x255A) + ([string][char]0x2550 * 100) + ([string][char]0x255D)
        
        Write-Host "  $gray$boxTop$reset"
        # We need to reserve space for the log lines. Let's say 10 lines of logs.
        $logHeight = 10
        $logStartY = $Host.UI.RawUI.CursorPosition.Y
        
        for ($i = 0; $i -lt $logHeight; $i++) {
            Write-Host "  $gray$boxMid$reset                                                                                                    $gray$boxMid$reset"
        }
        Write-Host "  $gray$boxBot$reset"
        
        # Store the Y coordinates for the log area
        $global:LogAreaTop = $logStartY
        $global:LogAreaBottom = $logStartY + $logHeight
        $global:LogCurrentLine = 0
        $global:LogHistory = New-Object System.Collections.Generic.List[string]

        # Override the logger to print INSIDE the box
        $cliLogger = [Action[string]] { 
            param($msg) 
            $timestamp = Get-Date -Format "HH:mm:ss"
            $esc = [char]27
            $bold = "$esc[1m"
            $reset = "$esc[0m"
            
            # Status Icons
    $iconOk = "$([char]0x2714)"      # Checkmark
    $iconFail = "$([char]0x2718)"    # X
    $iconWarn = "$([char]0x26A0)"    # Warning Triangle
    $iconSkull = "$([char]0x2620)"   # Skull
    
    # Progress Bar logic (embedded in log)
    # Format: [||||||||||  ] 80%
    if ($msg -match '^\[P(\d+)\] (.*)') {
        $pct = [int]$matches[1]
        $txt = $matches[2]
        $barLen = 20
        $filledLen = [int]($barLen * $pct / 100)
        $bar = ("$([char]0x2588)" * $filledLen) + ("$([char]0x2591)" * ($barLen - $filledLen))
        $formattedMsg = "[$timestamp] $bold$([char]0x2503)$reset [$bar] $pct% $txt"
    } elseif ($msg -match 'Error' -or $msg -match 'FAILED') {
        $formattedMsg = "[$timestamp] $bold$([char]0x2503)$reset $iconFail $msg"
    } elseif ($msg -match 'Success' -or $msg -match 'OK' -or $msg -match 'Finished' -or $msg -match 'completed successfully') {
        $formattedMsg = "[$timestamp] $bold$([char]0x2503)$reset $iconOk $msg"
    } elseif ($msg -match 'Warning' -or $msg -match 'skipped') {
        $formattedMsg = "[$timestamp] $bold$([char]0x2503)$reset $iconWarn $msg"
    } elseif ($msg -match 'Removing' -or $msg -match 'Disabling' -or $msg -match 'Purging') {
        $formattedMsg = "[$timestamp] $bold$([char]0x2503)$reset $iconSkull $msg"
    } elseif ($msg -match '^\[\d/\d\]') {
            $formattedMsg = "$bold$([char]0x2550)$([char]0x2550) $msg $([char]0x2550)$([char]0x2550)$reset"
    } else {
        $formattedMsg = "[$timestamp] $bold$([char]0x2503)$reset $msg"
    }

            # Add to history
            $global:LogHistory.Add($formattedMsg)
            
            # Logic to scroll: If history > height, we take the last N items
            $displayLines = $global:LogHistory
            if ($global:LogHistory.Count -gt $logHeight) {
                $startIndex = $global:LogHistory.Count - $logHeight
                $displayLines = $global:LogHistory.GetRange($startIndex, $logHeight)
            }
            
            # Redraw the log area
            $currentY = $global:LogAreaTop
            foreach ($line in $displayLines) {
                # Clear the inner part of the line (70 chars wide approx, excluding borders)
                # Border is at X=2 (start) and X=73 (end) approx. 
                # Actually X=2 is the start of the string printed "  ║". So the text starts at X=4.
                # Box width is 70 chars of content.
                
                # We need to strip ANSI codes for length calculation to pad correctly, but that's complex in PS.
                # Simplification: Overwrite with spaces then print.
                
                # Move to text start position
                $coord = New-Object System.Management.Automation.Host.Coordinates 4, $currentY
                $Host.UI.RawUI.CursorPosition = $coord
                Write-Host (" " * 98) -NoNewline # Clear content
                
                $Host.UI.RawUI.CursorPosition = $coord
                
                # Truncate if too long to fit in box
                if ($line.Length -gt 98) { $line = $line.Substring(0, 98) }
                Write-Host $line -NoNewline
                
                $currentY++
            }
            
            # Reset cursor to below the box to avoid messing up other output if any
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0, ($global:LogAreaBottom + 1)
        }
        
        # 1. System Optimization
        # Force a small delay to let UI stabilize
        Start-Sleep -Milliseconds 200
        $cliLogger.Invoke("[1/6] System Performance Optimization")
        
        # NOTE: Write-Spinner is removed because it writes outside the box and messes up cursor position.
        # Replacing with log messages.
        $cliLogger.Invoke("Analyzing System Configuration...")
        Invoke-SystemOptimization -Logger $cliLogger
        
        # 2. Gaming Optimization
        $cliLogger.Invoke("[2/6] Gaming and Latency Optimization")
        $cliLogger.Invoke("Applying Gaming Tweaks...")
        Invoke-GamingOptimization -Logger $cliLogger -Options @{ GameMode = $true }
        
        # 3. NVIDIA Profile Tweak
        $cliLogger.Invoke("[3/6] NVIDIA Profile Inspector Tweak")
        $cliLogger.Invoke("Checking GPU Settings...")
        Invoke-NvidiaProfile -Logger $cliLogger
        
        # 4. Privacy and Debloat
        $cliLogger.Invoke("[4/6] Privacy and Debloat")
        $cliLogger.Invoke("Removing Bloatware...")
        Remove-Bloatware -Logger $cliLogger
        
        # 5. AI Removal
        $cliLogger.Invoke("[5/6] AI and Copilot Removal")
        $cliLogger.Invoke("Purging AI Components...")
        Remove-WindowsAI -Logger $cliLogger
        
        # 6. Final Cleanup
        $cliLogger.Invoke("[6/6] Finalizing and Cleanup")
        $cliLogger.Invoke("Cleaning Disk...")
        ipconfig /flushdns | Out-Null
        $cliLogger.Invoke("DNS Cache Flushed.")
        
        $cliLogger.Invoke("Cleaning temporary files...")
        $tempPaths = @("$env:TEMP\*", "$env:SystemRoot\Temp\*")
        foreach ($path in $tempPaths) {
            try { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
        }
        
        $cliLogger.Invoke("Restarting Explorer to apply changes...")
        Stop-Process -Name Explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        
        if ($global:MusicEnabled) { Stop-Music }
        
        # Final Scorecard
        Write-Host ""
        $boxTop = ([string][char]0x2554) + ([string][char]0x2550 * 52) + ([string][char]0x2557)
        $boxMid = ([string][char]0x2551)
        $boxBot = ([string][char]0x255A) + ([string][char]0x2550 * 52) + ([string][char]0x255D)
        
        Write-Host "  $gray$boxTop$reset"
        Write-Host "  $gray$boxMid$reset $green OPTIMIZATION REPORT:$reset                              $gray$boxMid$reset"
        Write-Host "  $gray$boxMid$reset $cyan Status     :$reset Completed Successfully               $gray$boxMid$reset"
        Write-Host "  $gray$boxMid$reset $cyan Performance:$reset Maximized (Ultimate Mode)            $gray$boxMid$reset"
        Write-Host "  $gray$boxMid$reset $cyan Privacy    :$reset Enhanced                             $gray$boxMid$reset"
        Write-Host "  $gray$boxMid$reset $cyan Telemetry  :$reset Purged                               $gray$boxMid$reset"
        Write-Host "  $gray$boxBot$reset"
        Write-Host ""
        
        $cliLogger.Invoke("Success: Optimization Suite Finished!")
        Write-Host "`n  Press any key to return to menu..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } elseif ($choiceIndex -eq 1) {
        $global:MusicEnabled = -not $global:MusicEnabled
    } else {
        Write-Typewriter " [SYSTEM] Exiting... Stay optimized!" -Delay 20 -Color Cyan
        break
    }
}
