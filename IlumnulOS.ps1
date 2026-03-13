
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
        @{ Remote = "Modules/RemoveAI.psm1"; Local = "$InstallPath\Modules\RemoveAI.psm1" }
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

if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
    try { New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null } catch {}
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

function Get-WaveText {
    param(
        [Parameter(Mandatory)][string]$Text,
        [int]$Frame = 0,
        [double]$Speed = 0.35,
        [double]$Freq = 0.22,
        [int]$BaseR = 150, [int]$BaseG = 0, [int]$BaseB = 255,
        [int]$AmpR = -150, [int]$AmpG = 255, [int]$AmpB = 0
    )
    $esc = [char]27
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $phase = ($i * $Freq) + ($Frame * $Speed)
        $w = ([math]::Sin($phase) + 1.0) / 2.0
        $r = [int]([math]::Max(0, [math]::Min(255, $BaseR + ($AmpR * $w))))
        $g = [int]([math]::Max(0, [math]::Min(255, $BaseG + ($AmpG * $w))))
        $b = [int]([math]::Max(0, [math]::Min(255, $BaseB + ($AmpB * $w))))
        [void]$sb.Append("$esc[38;2;$r;$g;$b" + "m" + $Text[$i])
    }
    [void]$sb.Append("$esc[0m")
    return $sb.ToString()
}

$global:WaveFrame = 0

function Get-WaveLogText {
    param(
        [Parameter(Mandatory)][string]$Text,
        [ValidateSet("Default","Ok","Warn","Error","Skull")][string]$Theme = "Default",
        [int]$MaxPlainLen = 80
    )
    $supportsVT = $false
    try { $supportsVT = [bool]$Host.UI.SupportsVirtualTerminal } catch {}

    if ($Text.Length -gt $MaxPlainLen) {
        $Text = $Text.Substring(0, $MaxPlainLen)
    }

    if (-not $supportsVT) { return $Text }

    $global:WaveFrame = ($global:WaveFrame + 1) % 1000000

    switch ($Theme) {
        "Ok"    { return Get-WaveText -Text $Text -Frame $global:WaveFrame -BaseR 0   -BaseG 255 -BaseB 120 -AmpR 80  -AmpG -180 -AmpB 80 }
        "Warn"  { return Get-WaveText -Text $Text -Frame $global:WaveFrame -BaseR 255 -BaseG 170 -BaseB 0   -AmpR -80 -AmpG 80   -AmpB 160 }
        "Error" { return Get-WaveText -Text $Text -Frame $global:WaveFrame -BaseR 255 -BaseG 30  -BaseB 30  -AmpR 0   -AmpG 120  -AmpB 120 }
        "Skull" { return Get-WaveText -Text $Text -Frame $global:WaveFrame -BaseR 200 -BaseG 0   -BaseB 255 -AmpR -80 -AmpG 160  -AmpB -80 }
        default { return Get-WaveText -Text $Text -Frame $global:WaveFrame }
    }
}

function Get-TerminalMetrics {
    param(
        [int]$MinPanelWidth = 84,
        [int]$MaxPanelWidth = 120,
        [int]$Margin = 2
    )
    $w = $Host.UI.RawUI.WindowSize.Width
    $h = $Host.UI.RawUI.WindowSize.Height
    $bw = $Host.UI.RawUI.BufferSize.Width
    $bh = $Host.UI.RawUI.BufferSize.Height
    $panelWidth = [Math]::Min($MaxPanelWidth, [Math]::Max(40, $w - ($Margin * 2)))
    if ($panelWidth -lt $MinPanelWidth) { $panelWidth = [Math]::Max(40, $w - ($Margin * 2)) }
    $panelX = [Math]::Max(0, [Math]::Floor(($w - $panelWidth) / 2))
    return @{
        Width = $w
        Height = $h
        BufferWidth = $bw
        BufferHeight = $bh
        PanelWidth = $panelWidth
        PanelX = $panelX
        Margin = $Margin
    }
}

function Write-At {
    param(
        [int]$X,
        [int]$Y,
        [string]$Text,
        [switch]$NoNewline
    )
    try {
        $buf = $Host.UI.RawUI.BufferSize
        $x2 = [Math]::Max(0, [Math]::Min($buf.Width - 1, $X))
        $y2 = [Math]::Max(0, [Math]::Min($buf.Height - 1, $Y))
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates($x2, $y2)
        if ($NoNewline) { Write-Host $Text -NoNewline } else { Write-Host $Text }
    } catch {
        return
    }
}

function Clear-Region {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )
    try {
        $buf = $Host.UI.RawUI.BufferSize
        if ($Y -ge $buf.Height) { return }
        $x2 = [Math]::Max(0, $X)
        $w2 = [Math]::Max(0, [Math]::Min($Width, $buf.Width - $x2))
        $maxH = [Math]::Max(0, [Math]::Min($Height, $buf.Height - $Y))
        $blank = " " * $w2
        for ($i = 0; $i -lt $maxH; $i++) {
            Write-At -X $x2 -Y ($Y + $i) -Text $blank -NoNewline
        }
    } catch {}
}

function Draw-Box {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [string]$Title = ""
    )
    try {
        $buf = $Host.UI.RawUI.BufferSize
        if ($Y -ge $buf.Height - 1 -or $X -ge $buf.Width - 1) { return }
        $Width = [Math]::Min($Width, $buf.Width - $X)
        $Height = [Math]::Min($Height, $buf.Height - $Y)
        if ($Width -lt 4 -or $Height -lt 3) { return }
    } catch {
        if ($Width -lt 4 -or $Height -lt 3) { return }
    }
    $tl = [char]0x2554
    $tr = [char]0x2557
    $bl = [char]0x255A
    $br = [char]0x255D
    $h = [char]0x2550
    $v = [char]0x2551
    $top = "$tl" + (([string]$h) * ($Width - 2)) + "$tr"
    if ($Title) {
        $t = " $Title "
        if ($t.Length -lt ($Width - 2)) {
            $start = [Math]::Max(1, [Math]::Floor((($Width - 2) - $t.Length) / 2) + 1)
            $top = $top.Substring(0, $start) + $t + $top.Substring($start + $t.Length)
        }
    }
    $mid = "$v" + (" " * ($Width - 2)) + "$v"
    $bot = "$bl" + (([string]$h) * ($Width - 2)) + "$br"
    Write-At -X $X -Y $Y -Text $top -NoNewline
    for ($i = 1; $i -lt ($Height - 1); $i++) {
        Write-At -X $X -Y ($Y + $i) -Text $mid -NoNewline
    }
    Write-At -X $X -Y ($Y + $Height - 1) -Text $bot -NoNewline
}

function Render-RunHeader {
    param(
        [int]$Frames = 0
    )
    Clear-Host
    $esc = [char]27
    $reset = "$esc[0m"
    $gray = "$esc[90m"
    $lines = @(
        'IIII  lll   u   u  m   m  n   n  u   u  lll    OOO   SSS ',
        ' II   ll    u   u  mm mm  nn  n  u   u  ll    O   O S    ',
        ' II   ll    u   u  m m m  n n n  u   u  ll    O   O  SSS ',
        ' II   ll    u   u  m   m  n  nn  u   u  ll    O   O    S ',
        'IIII llll    uuu   m   m  n   n   uuu  llll    OOO  SSS  '
    )
    $subtitle = "Windows 11 Ultimate Optimization Tool"
    $m = Get-TerminalMetrics
    $w = [int]$m.Width
    $maxLineLen = ($lines | Measure-Object -Property Length -Maximum).Maximum
    $padTitle = [Math]::Max(0, [Math]::Floor(($w - $maxLineLen) / 2))
    for ($i = 0; $i -lt $lines.Count; $i++) {
        Write-At -X $padTitle -Y $i -Text (Get-GradientText $lines[$i] 120 0 255 0 255 255) -NoNewline
    }
    $padSubtitle = [Math]::Max(0, [Math]::Floor(($w - $subtitle.Length) / 2))
    Write-At -X $padSubtitle -Y ($lines.Count) -Text (Get-GradientText $subtitle 0 255 255 255 255 255) -NoNewline
    $border = ([string][char]0x2500) * [Math]::Min(70, [Math]::Max(30, $w - 10))
    $padBorder = [Math]::Max(0, [Math]::Floor(($w - $border.Length) / 2))
    Write-At -X $padBorder -Y ($lines.Count + 1) -Text ($gray + $border + $reset) -NoNewline
    $global:HeaderBottomY = $lines.Count + 1
}

function Show-HeaderWave {
    param(
        [int]$Frames = 40,
        [int]$DelayMs = 18,
        [bool]$clear = $true
    )
    if ($clear) { Clear-Host }
    $lines = @(
        'IIII  lll   u   u  m   m  n   n  u   u  lll    OOO   SSS ',
        ' II   ll    u   u  mm mm  nn  n  u   u  ll    O   O S    ',
        ' II   ll    u   u  m m m  n n n  u   u  ll    O   O  SSS ',
        ' II   ll    u   u  m   m  n  nn  u   u  ll    O   O    S ',
        'IIII llll    uuu   m   m  n   n   uuu  llll    OOO  SSS  '
    )
    $subtitle = "Windows 11 Ultimate Optimization Tool"
    $start = New-Object System.Management.Automation.Host.Coordinates(0, 0)
    $width = $Host.UI.RawUI.WindowSize.Width
    $maxLineLen = ($lines | Measure-Object -Property Length -Maximum).Maximum
    $padTitle = [Math]::Max(0, [Math]::Floor(($width - $maxLineLen) / 2))
    $padSubtitle = [Math]::Max(0, [Math]::Floor(($width - $subtitle.Length) / 2))
    for ($f = 0; $f -lt $Frames; $f++) {
        $Host.UI.RawUI.CursorPosition = $start
        foreach ($line in $lines) {
            Write-Host (" " * $padTitle) -NoNewline
            Write-Host (Get-WaveText -Text $line -Frame $f -Speed 0.22 -Freq 0.12 -BaseR 120 -BaseG 0 -BaseB 255 -AmpR -60 -AmpG 255 -AmpB 0)
        }
        Write-Host (" " * $padSubtitle) -NoNewline
        Write-Host (Get-GradientText $subtitle 0 255 255 255 255 255)
        Start-Sleep -Milliseconds $DelayMs
    }
    $hw = if ($global:cachedHwInfo) { $global:cachedHwInfo } else { Get-HardwareInfo }
    $esc = [char]27
    $reset = "$esc[0m"
    $gray = "$esc[90m"
    $boxTop = ([string][char]0x2554) + ([string][char]0x2550 * 52) + ([string][char]0x2557)
    $boxBot = ([string][char]0x255A) + ([string][char]0x2550 * 52) + ([string][char]0x255D)
    $padBox = [Math]::Max(0, [Math]::Floor(($width - $boxTop.Length) / 2))
    $indent = " " * $padBox
    Write-Host ""
    Write-Host "$indent$gray$boxTop$reset"
    Write-HwLine "CPU" $hw.CPU $indent
    Write-HwLine "GPU" $hw.GPU $indent
    Write-HwLine "RAM" $hw.RAM $indent
    Write-Host "$indent$gray$boxBot$reset"
    $borderLine = ([string][char]0x2500) * 54
    Write-Host (" " * [Math]::Max(0, [Math]::Floor(($width - $borderLine.Length) / 2)) + $borderLine) -ForegroundColor Gray
    $global:HeaderBottomY = $Host.UI.RawUI.CursorPosition.Y
}

function Write-Spinner {
    param([string]$Message)
    $frames = @("|","/","-","\\")
    $esc = [char]27
    $cyan = "$esc[36m"
    $reset = "$esc[0m"
    for ($i = 0; $i -lt 10; $i++) {
        Write-Host "`r$cyan$($frames[$i % $frames.Count])$reset $Message" -NoNewline
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
    param($Label, $Value, [string]$Indent = "  ")
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
    
    Write-Host "$Indent$gray$boxMid$reset" -NoNewline
    Write-Host (" " * $l) -NoNewline
    Write-Host "$cyan$Label :$reset $Value" -NoNewline
    Write-Host (" " * $r) -NoNewline
    Write-Host "$gray$boxMid$reset"
}

function Render-HeaderStatic {
    param(
        [bool]$Clear = $true,
        [bool]$UseCachedHw = $true
    )
    if ($Clear) { Clear-Host }
    $esc = [char]27
    $reset = "$esc[0m"
    $gray = "$esc[90m"
    $lines = @(
        'IIII  lll   u   u  m   m  n   n  u   u  lll    OOO   SSS ',
        ' II   ll    u   u  mm mm  nn  n  u   u  ll    O   O S    ',
        ' II   ll    u   u  m m m  n n n  u   u  ll    O   O  SSS ',
        ' II   ll    u   u  m   m  n  nn  u   u  ll    O   O    S ',
        'IIII llll    uuu   m   m  n   n   uuu  llll    OOO  SSS  '
    )
    $subtitle = "Windows 11 Ultimate Optimization Tool"
    $w = $Host.UI.RawUI.WindowSize.Width

    foreach ($line in $lines) {
        $pad = [Math]::Max(0, [Math]::Floor(($w - $line.Length) / 2))
        Write-Host (" " * $pad) -NoNewline
        Write-Host (Get-GradientText $line 120 0 255 0 255 255)
    }

    $pad2 = [Math]::Max(0, [Math]::Floor(($w - $subtitle.Length) / 2))
    Write-Host (" " * $pad2) -NoNewline
    Write-Host (Get-GradientText $subtitle 0 255 255 255 255 255)

    $hw = if ($UseCachedHw -and $global:cachedHwInfo) { $global:cachedHwInfo } else { Get-HardwareInfo }
    $boxTop = ([string][char]0x2554) + ([string][char]0x2550 * 52) + ([string][char]0x2557)
    $boxBot = ([string][char]0x255A) + ([string][char]0x2550 * 52) + ([string][char]0x255D)
    $padBox = [Math]::Max(0, [Math]::Floor(($w - $boxTop.Length) / 2))
    $indent = " " * $padBox

    Write-Host ""
    Write-Host "$indent$gray$boxTop$reset"
    Write-HwLine "CPU" $hw.CPU $indent
    Write-HwLine "GPU" $hw.GPU $indent
    Write-HwLine "RAM" $hw.RAM $indent
    Write-Host "$indent$gray$boxBot$reset"

    $borderLine = ([string][char]0x2500) * 54
    $padBorder = [Math]::Max(0, [Math]::Floor(($w - $borderLine.Length) / 2))
    Write-Host (" " * $padBorder + $borderLine) -ForegroundColor Gray
    $global:HeaderBottomY = $Host.UI.RawUI.CursorPosition.Y
}

function Show-Header {
    Render-HeaderStatic -Clear $true -UseCachedHw $false
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

Show-HeaderWave
Write-Typewriter " [SYSTEM] Initializing IlumnulOS Ultimate v2.0..." -Delay 15 -Color Cyan
Write-Typewriter " [SYSTEM] Loading modules and verifying environment..." -Delay 10 -Color Gray
Start-Sleep -Seconds 1

$global:cachedHwInfo = Get-HardwareInfo

function Show-Header-Optimized {
    param([bool]$clear = $true)
    Render-HeaderStatic -Clear $clear -UseCachedHw $true
}

while ($true) {
    $esc = [char]27
    $bold = "$esc[1m"
    $cyan = "$esc[36m"
    $green = "$esc[32m"
    $gray = "$esc[90m"
    $reset = "$esc[0m"
    $menuOptions = @("Start Optimization (Full Suite)", "Exit")
    
    $selectedIndex = 0
    $inMenu = $true
    
    Show-HeaderWave -clear $true
    
    while ($inMenu) {
        $menuTopY = if ($global:HeaderBottomY) { [int]$global:HeaderBottomY + 2 } else { 15 }
        $m = Get-TerminalMetrics
        $menuMax = ($menuOptions | Measure-Object -Property Length -Maximum).Maximum
        $panelW = [int][Math]::Max(46, [Math]::Min(72, ($menuMax + 12)))
        $panelX = [int][Math]::Max(0, [Math]::Floor(($m.Width - $panelW) / 2))
        $boxH = $menuOptions.Count + 3
        Clear-Region -X 0 -Y $menuTopY -Width $m.Width -Height ($boxH + 2)
        Draw-Box -X $panelX -Y $menuTopY -Width $panelW -Height $boxH -Title "MENU"

        $innerW = $panelW - 4
        $optY = $menuTopY + 1
        for ($i = 0; $i -lt $menuOptions.Count; $i++) {
            $lineX = $panelX + 2
            Write-At -X $lineX -Y ($optY + $i) -Text (" " * $innerW) -NoNewline

            if ($i -eq $selectedIndex) {
                $txt = "> " + $menuOptions[$i]
                $pad = [Math]::Max(0, [Math]::Floor(($innerW - $txt.Length) / 2))
                Write-At -X ($lineX + $pad) -Y ($optY + $i) -Text ("$bold$cyan$txt$reset") -NoNewline
            } else {
                $txt = "  " + $menuOptions[$i]
                $pad = [Math]::Max(0, [Math]::Floor(($innerW - $txt.Length) / 2))
                Write-At -X ($lineX + $pad) -Y ($optY + $i) -Text ($gray + $txt + $reset) -NoNewline
            }
        }

        $hint = "Use Up/Down arrows to navigate, Enter to select."
        $hintPad = [Math]::Max(0, [Math]::Floor(($m.Width - $hint.Length) / 2))
        Write-At -X $hintPad -Y ($menuTopY + $boxH) -Text ($gray + $hint + $reset) -NoNewline

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

        Render-RunHeader
        $cyan = "$esc[36m"
        $m = Get-TerminalMetrics -MaxPanelWidth 120
        $panelX = [int]$m.PanelX
        $panelW = [int]$m.PanelWidth

        $statusY = if ($global:HeaderBottomY) { [int]$global:HeaderBottomY + 1 } else { 10 }
        $statusH = 5
        $logY = $statusY + $statusH + 1
        $available = [Math]::Max(0, $m.BufferHeight - ($logY + 3))
        $logH = [Math]::Max(8, [Math]::Min(16, $available))

        Draw-Box -X $panelX -Y $statusY -Width $panelW -Height $statusH -Title "STATUS"
        Draw-Box -X $panelX -Y $logY -Width $panelW -Height $logH -Title "LOG"

        $innerX = $panelX + 2
        $innerW = $panelW - 4

        $global:StatusLineY = $statusY + 2
        $global:StatusDetailY = $statusY + 3
        Write-At -X $innerX -Y $global:StatusLineY -Text (" " * $innerW) -NoNewline
        Write-At -X $innerX -Y $global:StatusDetailY -Text (" " * $innerW) -NoNewline
        Write-At -X $innerX -Y $global:StatusLineY -Text ("$green[RUN]$reset Starting system-wide optimization...") -NoNewline
        Write-At -X $innerX -Y $global:StatusDetailY -Text ("$gray Step:$reset Initializing") -NoNewline

        $global:LogX = $innerX
        $global:LogInnerW = $innerW
        $global:LogAreaTop = $logY + 2
        $global:LogAreaBottom = $logY + $logH - 2
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
            $cyan = "$esc[36m"
            $gray = "$esc[90m"
            
            $cleanMsg = $msg -replace '\x1b\[[0-9;]*m', '' # Strip ANSI codes
            $logEntry = "[$timestamp] $cleanMsg"
            Add-Content -Path $logFilePath -Value $logEntry -ErrorAction SilentlyContinue
            $logHeight = [Math]::Max(1, ($global:LogAreaBottom - $global:LogAreaTop + 1))
            $maxW = [int]$global:LogInnerW

            function FitPlain([string]$s, [int]$w) {
                if ($w -le 0) { return "" }
                if ($null -eq $s) { return "" }
                if ($s.Length -le $w) { return $s }
                return $s.Substring(0, $w)
            }

    $iconOk = "$([char]0x2714)"      # Checkmark
    $iconFail = "$([char]0x2718)"    # X
    $iconWarn = "$([char]0x26A0)"    # Warning Triangle
    $iconSkull = "$([char]0x2620)"   # Skull
    
    if ($cleanMsg -match '^(?:Step:\s*)?\[(\d+)/(\d+)\]\s*(.*)$') {
        $idx = $matches[1]
        $tot = $matches[2]
        $desc = $matches[3]

        Write-At -X $global:LogX -Y $global:StatusDetailY -Text (" " * $global:LogInnerW) -NoNewline
        $statusPlain = FitPlain ("Step: [$idx/$tot] $desc") $maxW
        Write-At -X $global:LogX -Y $global:StatusDetailY -Text ($gray + $statusPlain + $reset) -NoNewline
    }

    if ($msg -match 'Error' -or $msg -match 'FAILED') {
        $prefixPlain = "[$timestamp] | $iconFail "
        $prefix = "[$timestamp] $bold$([char]0x2503)$reset $iconFail "
        $maxMsg = [Math]::Max(0, $maxW - $prefixPlain.Length)
        $msgPlain = FitPlain $cleanMsg $maxMsg
        $wave = Get-WaveLogText -Text $msgPlain -Theme "Error" -MaxPlainLen $maxMsg
        $formattedMsg = $prefix + $wave + $reset
    } elseif ($msg -match 'Success' -or $msg -match 'OK' -or $msg -match 'Finished' -or $msg -match 'completed successfully') {
        $prefixPlain = "[$timestamp] | $iconOk "
        $prefix = "[$timestamp] $bold$([char]0x2503)$reset $iconOk "
        $maxMsg = [Math]::Max(0, $maxW - $prefixPlain.Length)
        $msgPlain = FitPlain $cleanMsg $maxMsg
        $wave = Get-WaveLogText -Text $msgPlain -Theme "Ok" -MaxPlainLen $maxMsg
        $formattedMsg = $prefix + $wave + $reset
    } elseif ($msg -match 'Warning' -or $msg -match 'skipped') {
        $prefixPlain = "[$timestamp] | $iconWarn "
        $prefix = "[$timestamp] $bold$([char]0x2503)$reset $iconWarn "
        $maxMsg = [Math]::Max(0, $maxW - $prefixPlain.Length)
        $msgPlain = FitPlain $cleanMsg $maxMsg
        $wave = Get-WaveLogText -Text $msgPlain -Theme "Warn" -MaxPlainLen $maxMsg
        $formattedMsg = $prefix + $wave + $reset
    } elseif ($msg -match 'Removing' -or $msg -match 'Disabling' -or $msg -match 'Purging') {
        $prefixPlain = "[$timestamp] | $iconSkull "
        $prefix = "[$timestamp] $bold$([char]0x2503)$reset $iconSkull "
        $maxMsg = [Math]::Max(0, $maxW - $prefixPlain.Length)
        $msgPlain = FitPlain $cleanMsg $maxMsg
        $wave = Get-WaveLogText -Text $msgPlain -Theme "Skull" -MaxPlainLen $maxMsg
        $formattedMsg = $prefix + $wave + $reset
    } elseif ($msg -match '^\[\d/\d\]') {
            $plain = FitPlain $cleanMsg $maxW
            $wave = Get-WaveLogText -Text $plain -Theme "Default" -MaxPlainLen $maxW
            $formattedMsg = "$bold$wave$reset"
    } else {
        $prefixPlain = "[$timestamp] | "
        $prefix = "[$timestamp] $bold$([char]0x2503)$reset "
        $maxMsg = [Math]::Max(0, $maxW - $prefixPlain.Length)
        $msgPlain = FitPlain $cleanMsg $maxMsg
        $wave = Get-WaveLogText -Text $msgPlain -Theme "Default" -MaxPlainLen $maxMsg
        $formattedMsg = $prefix + $wave + $reset
    }

            $global:LogHistory.Add($formattedMsg)
            
            $displayLines = $global:LogHistory
            if ($global:LogHistory.Count -gt $logHeight) {
                $startIndex = $global:LogHistory.Count - $logHeight
                $displayLines = $global:LogHistory.GetRange($startIndex, $logHeight)
            }
            
            $currentY = $global:LogAreaTop
            foreach ($line in $displayLines) {
                
                Write-At -X $global:LogX -Y $currentY -Text (" " * $global:LogInnerW) -NoNewline
                Write-At -X $global:LogX -Y $currentY -Text $line -NoNewline
                
                $currentY++
            }
            
            Write-At -X 0 -Y ($global:LogAreaBottom + 1) -Text "" -NoNewline
        }
        
        Start-Sleep -Milliseconds 200
        $prevEAP = $ErrorActionPreference
        $prevWP = $WarningPreference
        $ErrorActionPreference = "SilentlyContinue"
        $WarningPreference = "SilentlyContinue"
        $cliLogger.Invoke("[1/6] System Performance Optimization")
        
        $cliLogger.Invoke("Analyzing System Configuration...")
        try { Invoke-SystemOptimization -Logger $cliLogger 2>$null } catch {}
        
        $cliLogger.Invoke("Applying Group Policy Tweaks...")
        try { Invoke-GroupPolicyTweaks -Logger $cliLogger 2>$null } catch {}
        
        $cliLogger.Invoke("Applying Modern Cursor Scheme...")
        try { Invoke-ModernCursor -Logger $cliLogger 2>$null } catch {}
        
        $cliLogger.Invoke("[2/6] Gaming and Latency Optimization")
        $cliLogger.Invoke("Applying Gaming Tweaks...")
        try { Invoke-GamingOptimization -Logger $cliLogger -Options @{ GameMode = $true } 2>$null } catch {}
        
        $cliLogger.Invoke("[3/6] NVIDIA Profile Inspector Tweak")
        $cliLogger.Invoke("Checking GPU Settings...")
        try { Invoke-NvidiaProfile -Logger $cliLogger 2>$null } catch {}
        
        $cliLogger.Invoke("[4/6] Privacy and Debloat")
        $cliLogger.Invoke("Removing Bloatware...")
        try { Remove-Bloatware -Logger $cliLogger 2>$null } catch {}
        
        $cliLogger.Invoke("[5/6] AI and Copilot Removal")
        $cliLogger.Invoke("Purging AI Components...")
        try { Remove-WindowsAI -Logger $cliLogger 2>$null } catch {}
        
        $cliLogger.Invoke("[6/6] Finalizing and Cleanup")
        $cliLogger.Invoke("Running Ultimate Cleanup...")
        ipconfig /flushdns 2>$null | Out-Null
        $cliLogger.Invoke("DNS Cache Flushed.")
        
        try { Invoke-UltimateCleanup -Logger $cliLogger 2>$null } catch {}
        
        $cliLogger.Invoke("Restarting Explorer to apply changes...")
        Stop-Process -Name Explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $m2 = Get-TerminalMetrics -MaxPanelWidth 96
        $repW = [int][Math]::Min($m2.PanelWidth, 96)
        $repX = [int]$m2.PanelX
        $repH = 7
        $repY = [int]([Math]::Min(($global:LogAreaBottom + 2), ($m2.BufferHeight - $repH)))
        Draw-Box -X $repX -Y $repY -Width $repW -Height $repH -Title "REPORT"
        $ix = $repX + 2
        $iw = $repW - 4
        $lines = @(
            "$green Optimization Completed$reset",
            "$cyan Status:$reset Completed Successfully",
            "$cyan Performance:$reset Maximized (Ultimate Mode)",
            "$cyan Privacy:$reset Enhanced",
            "$cyan Telemetry:$reset Purged"
        )
        for ($i = 0; $i -lt $lines.Count; $i++) {
            Write-At -X $ix -Y ($repY + 1 + $i) -Text (" " * $iw) -NoNewline
            $plain = ($lines[$i] -replace '\x1b\[[0-9;]*m', '')
            $pad = [Math]::Max(0, [Math]::Floor(($iw - $plain.Length) / 2))
            Write-At -X ($ix + $pad) -Y ($repY + 1 + $i) -Text $lines[$i] -NoNewline
        }
        
        $cliLogger.Invoke("Success: Optimization Suite Finished!")
        $cliLogger.Invoke("Log file saved to Desktop: IlumnulOS_Log.txt")
        $ErrorActionPreference = $prevEAP
        $WarningPreference = $prevWP
        Write-Host "`n  Press any key to return to menu..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } else {
        Write-Typewriter " [SYSTEM] Exiting... Stay optimized!" -Delay 20 -Color Cyan
        break
    }
}
