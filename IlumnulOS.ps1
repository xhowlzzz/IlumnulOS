
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    $argList = "-File `"$($MyInvocation.MyCommand.Path)`""
    Start-Process powershell -Verb RunAs -ArgumentList $argList
    Exit
}

try {
    Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue
    Add-Type -AssemblyName WindowsBase -ErrorAction SilentlyContinue
} catch {}

$ScriptPath = $PSScriptRoot
if (-not $ScriptPath) {
    if ($MyInvocation.MyCommand.Path) {
        $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $ScriptPath = Get-Location
    }
}
if ($ScriptPath) { $ScriptPath = $ScriptPath.TrimEnd('\') }

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
        @{ Remote = "Modules/RemoveAI.psm1"; Local = "$InstallPath\Modules\RemoveAI.psm1" },
        @{ Remote = "Modules/IlumnulOS.mp3"; Local = "$InstallPath\Modules\IlumnulOS.mp3" }
    )

    # Modern Cursor Files
    $cursorFiles = @(
        "ModernCursorScheme.reg", "alternate.cur", "beam.cur", "busy.ani", "dgn1.cur", "dgn2.cur",
        "handwriting.cur", "help.cur", "horz.cur", "link.cur", "move.cur", "person.cur",
        "pin.cur", "pointer.cur", "precision.cur", "unavailable.cur", "vert.cur", "working.ani"
    )
    
    $cursorPath = "$InstallPath\Modules\ModernCursors"
    New-Item -ItemType Directory -Path $cursorPath -Force | Out-Null
    
    foreach ($file in $cursorFiles) {
        $requiredFiles += @{ Remote = "Modules/ModernCursors/$file"; Local = "$cursorPath\$file" }
    }

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

Write-Host "Importing modules..." -ForegroundColor Cyan
if (Test-Path "$ScriptPath\Modules\Debloat.psm1") { Import-Module "$ScriptPath\Modules\Debloat.psm1" -Force }
if (Test-Path "$ScriptPath\Modules\Optimize.psm1") { Import-Module "$ScriptPath\Modules\Optimize.psm1" -Force }
if (Test-Path "$ScriptPath\Modules\Gaming.psm1") { Import-Module "$ScriptPath\Modules\Gaming.psm1" -Force }
if (Test-Path "$ScriptPath\Modules\RemoveAI.psm1") { Import-Module "$ScriptPath\Modules\RemoveAI.psm1" -Force }

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
    $frames = @("â ‹","â ™","â ¹","â ¸","â ¼","â ´","â ¦","â §","â ‡","â ")
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

$cliLogger = [Action[string]] { 
    param($msg) 
    $timestamp = Get-Date -Format "HH:mm:ss"
    $esc = [char]27
    $bold = "$esc[1m"
    $reset = "$esc[0m"
    
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

$global:MusicEnabled = $true
Show-Header
Write-Typewriter " [SYSTEM] Initializing IlumnulOS Ultimate v2.0..." -Delay 15 -Color Cyan
Write-Typewriter " [SYSTEM] Loading modules and verifying environment..." -Delay 10 -Color Gray
Start-Sleep -Seconds 1

$global:cachedHwInfo = Get-HardwareInfo

function Show-Header-Optimized {
    param([bool]$clear = $true)
    if ($clear) { Clear-Host }
    $esc = [char]27
    $bold = "$esc[1m"
    $reset = "$esc[0m"

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

while ($true) {
    $esc = [char]27
    $green = "$esc[32m"
    $gray = "$esc[90m"
    $reset = "$esc[0m"
    
    $musicToggle = if ($global:MusicEnabled) { "$green$([string][char]0x25CF)$([string][char]0x2500)$([string][char]0x2500)$([string][char]0x2500)$gray$([string][char]0x25CB)$reset ON " } else { "$gray$([string][char]0x25CB)$([string][char]0x2500)$([string][char]0x2500)$([string][char]0x2500)$reset$([string][char]0x25CF) OFF" }
    
    $menuOptions = @("Start Optimization (Full Suite)", "Music: [$musicToggle]", "Exit")
    
    $selectedIndex = 0
    $inMenu = $true
    
    Show-Header-Optimized -clear $true
    
    while ($inMenu) {
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, 15) # Adjust based on header height
        
        Write-Host ""
        $cyan = "$esc[36m"
        $bold = "$esc[1m"
        
        for ($i = 0; $i -lt $menuOptions.Count; $i++) {
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
        
        Write-Host ""
        $boxTop = ([string][char]0x2554) + ([string][char]0x2550 * 100) + ([string][char]0x2557)
        $boxMid = ([string][char]0x2551)
        $boxBot = ([string][char]0x255A) + ([string][char]0x2550 * 100) + ([string][char]0x255D)
        
        Write-Host "  $gray$boxTop$reset"
        $logHeight = 10
        $logStartY = $Host.UI.RawUI.CursorPosition.Y
        
        for ($i = 0; $i -lt $logHeight; $i++) {
            Write-Host "  $gray$boxMid$reset                                                                                                    $gray$boxMid$reset"
        }
        Write-Host "  $gray$boxBot$reset"
        
        $global:LogAreaTop = $logStartY
        $global:LogAreaBottom = $logStartY + $logHeight
        $global:LogCurrentLine = 0
        $global:LogHistory = New-Object System.Collections.Generic.List[string]

        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $logFilePath = "$desktopPath\IlumnulOS_Log.txt"
        $logHeader = @"
================================================================================
   IlumnulOS Optimization Log - $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
   System: $((Get-CimInstance Win32_ComputerSystem).Name) | User: $env:USERNAME
   OS: $((Get-CimInstance Win32_OperatingSystem).Caption) ($((Get-CimInstance Win32_OperatingSystem).Version))
================================================================================
"@
        Set-Content -Path $logFilePath -Value $logHeader -Force

        $cliLogger = [Action[string]] { 
            param($msg) 
            $timestamp = Get-Date -Format "HH:mm:ss"
            $esc = [char]27
            $bold = "$esc[1m"
            $reset = "$esc[0m"
            
            $cleanMsg = $msg -replace '\x1b\[[0-9;]*m', '' # Strip ANSI codes
            $logEntry = "[$timestamp] $cleanMsg"
            Add-Content -Path $logFilePath -Value $logEntry -ErrorAction SilentlyContinue

    $iconOk = "$([char]0x2714)"      # Checkmark
    $iconFail = "$([char]0x2718)"    # X
    $iconWarn = "$([char]0x26A0)"    # Warning Triangle
    $iconSkull = "$([char]0x2620)"   # Skull
    
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

            $global:LogHistory.Add($formattedMsg)
            
            $displayLines = $global:LogHistory
            if ($global:LogHistory.Count -gt $logHeight) {
                $startIndex = $global:LogHistory.Count - $logHeight
                $displayLines = $global:LogHistory.GetRange($startIndex, $logHeight)
            }
            
            $currentY = $global:LogAreaTop
            foreach ($line in $displayLines) {
                
                $coord = New-Object System.Management.Automation.Host.Coordinates 4, $currentY
                $Host.UI.RawUI.CursorPosition = $coord
                Write-Host (" " * 98) -NoNewline # Clear content
                
                $Host.UI.RawUI.CursorPosition = $coord
                
                if ($line.Length -gt 98) { $line = $line.Substring(0, 98) }
                Write-Host $line -NoNewline
                
                $currentY++
            }
            
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0, ($global:LogAreaBottom + 1)
        }
        
        Start-Sleep -Milliseconds 200
        $cliLogger.Invoke("[1/6] System Performance Optimization")
        
        $cliLogger.Invoke("Analyzing System Configuration...")
        Invoke-SystemOptimization -Logger $cliLogger
        
        $cliLogger.Invoke("Applying Group Policy Tweaks...")
        Invoke-GroupPolicyTweaks -Logger $cliLogger
        
        $cliLogger.Invoke("Applying Modern Cursor Scheme...")
        Invoke-ModernCursor -Logger $cliLogger
        
        $cliLogger.Invoke("[2/6] Gaming and Latency Optimization")
        $cliLogger.Invoke("Applying Gaming Tweaks...")
        Invoke-GamingOptimization -Logger $cliLogger -Options @{ GameMode = $true }
        
        $cliLogger.Invoke("[3/6] NVIDIA Profile Inspector Tweak")
        $cliLogger.Invoke("Checking GPU Settings...")
        Invoke-NvidiaProfile -Logger $cliLogger
        
        $cliLogger.Invoke("[4/6] Privacy and Debloat")
        $cliLogger.Invoke("Removing Bloatware...")
        Remove-Bloatware -Logger $cliLogger
        
        $cliLogger.Invoke("[5/6] AI and Copilot Removal")
        $cliLogger.Invoke("Purging AI Components...")
        Remove-WindowsAI -Logger $cliLogger
        
        $cliLogger.Invoke("[6/6] Finalizing and Cleanup")
        $cliLogger.Invoke("Running Ultimate Cleanup...")
        ipconfig /flushdns | Out-Null
        $cliLogger.Invoke("DNS Cache Flushed.")
        
        Invoke-UltimateCleanup -Logger $cliLogger
        
        $cliLogger.Invoke("Restarting Explorer to apply changes...")
        Stop-Process -Name Explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        
        if ($global:MusicEnabled) { Stop-Music }
        
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
        $cliLogger.Invoke("Log file saved to Desktop: IlumnulOS_Log.txt")
        Write-Host "`n  Press any key to return to menu..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } elseif ($choiceIndex -eq 1) {
        $global:MusicEnabled = -not $global:MusicEnabled
    } else {
        Write-Typewriter " [SYSTEM] Exiting... Stay optimized!" -Delay 20 -Color Cyan
        break
    }
}
