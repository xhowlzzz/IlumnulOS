# IlumnulOS - Created by Howl
# Windows 11 Optimization & Debloating Tool - Ultimate Edition
# Features: Glass/iOS-like UI, Animations, Modern Design, Loading Screen, Custom Terminal (#517755)

# Load required assemblies
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Import Modules
$ScriptPath = $PSScriptRoot

# Remote Execution / Missing Path Logic
if (-not $ScriptPath) {
    if ($MyInvocation.MyCommand.Path) {
        $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $ScriptPath = Get-Location
    }
}

# Bootstrapper: Check if running remotely (missing local modules) and download them
    if (-not (Test-Path "$ScriptPath\Modules\RemoveAI.psm1")) {
        Write-Host "Remote Execution Detected. Initializing IlumnulOS Bootstrapper..." -ForegroundColor Cyan
        
        $InstallPath = "$env:USERPROFILE\Documents\IlumnulOS_v2"
        $RepoUrl = "https://raw.githubusercontent.com/xhowlzzz/IlumnulOS/main"
        
        # Clean cleanup to ensure fresh files
        if (Test-Path $InstallPath) {
            Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Create Directories
        New-Item -ItemType Directory -Path "$InstallPath\Modules" -Force | Out-Null
        New-Item -ItemType Directory -Path "$InstallPath\Assets" -Force | Out-Null
        New-Item -ItemType Directory -Path "$InstallPath\Config" -Force | Out-Null
        
        # Helper to download with retry logic and robust error handling
        function Download-File {
            param($RemotePath, $LocalPath)
            $MaxRetries = 3
            $RetryDelaySeconds = 2
            $BaseUrl = "https://raw.githubusercontent.com/xhowlzzz/IlumnulOS/main"
            $ApiBaseUrl = "https://api.github.com/repos/xhowlzzz/IlumnulOS/contents"
            $headers = @{ "User-Agent" = "PowerShell" }

            $parentDir = Split-Path -Parent $LocalPath
            if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }

            $attempt = 0
            $downloaded = $false
            $lastError = ""

            while (-not $downloaded -and $attempt -lt $MaxRetries) {
                $attempt++
                $timestamp = Get-Date -Format "HH:mm:ss"
                Write-Host "[$timestamp] Downloading $RemotePath (Attempt $attempt/$MaxRetries)..." -NoNewline

                $cb = Get-Random
                $candidates = @(
                    "$BaseUrl/$RemotePath?v=$cb",
                    "$BaseUrl/$RemotePath",
                    "$ApiBaseUrl/$RemotePath?ref=main"
                )

                foreach ($candidate in $candidates) {
                    try {
                        if ($candidate -like "https://api.github.com/*") {
                            $json = Invoke-RestMethod -Uri $candidate -Headers $headers -ErrorAction Stop
                            if (-not $json.content) { throw "GitHub API response has no content field." }
                            $bytes = [Convert]::FromBase64String(($json.content -replace "`n",""))
                            [System.IO.File]::WriteAllBytes($LocalPath, $bytes)
                        } else {
                            Invoke-WebRequest -Uri $candidate -OutFile $LocalPath -Headers $headers -ErrorAction Stop
                        }

                        if (Test-Path $LocalPath) {
                            $size = (Get-Item $LocalPath).Length
                            if ($size -gt 0) {
                                Write-Host " [OK] ($size bytes)" -ForegroundColor Green
                                $downloaded = $true
                                break
                            }
                        }
                        throw "Downloaded file is missing or empty."
                    } catch {
                        $lastError = "URL: $candidate | Error: $($_.Exception.Message)"
                    }
                }

                if (-not $downloaded) {
                    Write-Host " [FAILED]" -ForegroundColor Red
                    Write-Host "    $lastError" -ForegroundColor DarkGray
                    if ($attempt -lt $MaxRetries) {
                        $sleep = $RetryDelaySeconds * [math]::Pow(2, $attempt - 1)
                        Write-Host "    Retrying in $sleep seconds..." -ForegroundColor Yellow
                        Start-Sleep -Seconds $sleep
                    }
                }
            }

            if (-not $downloaded) {
                Write-Error "CRITICAL: Failed to download $RemotePath after $MaxRetries attempts."
                return $false
            }
            return $true
        }
    
    # Download Core Files
    $requiredFiles = @(
        @{ Remote = "Assets/MainWindow.xaml"; Local = "$InstallPath\Assets\MainWindow.xaml" },
        @{ Remote = "Config/settings.json"; Local = "$InstallPath\Config\settings.json" },
        @{ Remote = "Modules/Debloat.psm1"; Local = "$InstallPath\Modules\Debloat.psm1" },
        @{ Remote = "Modules/Gaming.psm1"; Local = "$InstallPath\Modules\Gaming.psm1" },
        @{ Remote = "Modules/Optimize.psm1"; Local = "$InstallPath\Modules\Optimize.psm1" },
        @{ Remote = "Modules/RemoveAI.psm1"; Local = "$InstallPath\Modules\RemoveAI.psm1" }
    )

    $hasFailure = $false
    foreach ($file in $requiredFiles) {
        $ok = Download-File $file.Remote $file.Local
        if (-not $ok) { $hasFailure = $true }
    }
    if ($hasFailure) {
        Read-Host "Press Enter to exit..."
        return
    }
    
    $ScriptPath = $InstallPath
    Write-Host "Bootstrapping Complete. Launching..." -ForegroundColor Green
}

# Ensure modules exist before importing to avoid errors if run independently
if (Test-Path "$ScriptPath\Modules\Debloat.psm1") { Import-Module "$ScriptPath\Modules\Debloat.psm1" -Force }
if (Test-Path "$ScriptPath\Modules\Optimize.psm1") { Import-Module "$ScriptPath\Modules\Optimize.psm1" -Force }
if (Test-Path "$ScriptPath\Modules\Gaming.psm1") { Import-Module "$ScriptPath\Modules\Gaming.psm1" -Force }
if (Test-Path "$ScriptPath\Modules\RemoveAI.psm1") { Import-Module "$ScriptPath\Modules\RemoveAI.psm1" -Force }

# -----------------------------------------------------------------------------
# Initialize UI Elements & Events
# -----------------------------------------------------------------------------

# Load XAML from file
$XamlPath = Join-Path -Path $ScriptPath -ChildPath "Assets\MainWindow.xaml"
if (!(Test-Path $XamlPath)) {
    Write-Error "CRITICAL ERROR: MainWindow.xaml not found at $XamlPath"
    Read-Host "Press Enter to exit..."
    return
}

try {
    $xamlContent = Get-Content -Path $XamlPath -Raw
    # Update dynamic content (username) before parsing
    $xamlContent = $xamlContent.Replace("Welcome back, User", "Welcome back, $env:USERNAME")
    
    $sr = New-Object System.IO.StringReader($xamlContent)
    $reader = [System.Xml.XmlReader]::Create($sr)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $sr.Close()
} catch {
    Write-Error "CRITICAL ERROR: Failed to load XAML. $_"
    Read-Host "Press Enter to exit..."
    return
}

# -----------------------------------------------------------------------------
# Async Execution Helper
# -----------------------------------------------------------------------------
function Start-AsyncOperation {
    param(
        [ScriptBlock]$ScriptBlock,
        [string]$SuccessMessage = "Operation Completed.",
        [switch]$ShowTerminal = $true,
        [hashtable]$OperationOptions = @{}
    )

    if ($ShowTerminal) {
        Switch-View "Terminal"
        $window.FindName("navTerminal").IsChecked = $true
    }

    if ($script:OperationInProgress) {
        if (Get-Command Log-Message -ErrorAction SilentlyContinue) {
            Log-Message "Another operation is already running."
        }
        return
    }

    # Create a synchronized hashtable for thread-safe logging
    $syncHash = [Hashtable]::Synchronized(@{})
    $syncHash.Window = $window
    $syncHash.OutputBox = $window.FindName("txtTerminalOutput")
    $syncHash.StatusBox = $window.FindName("txtStatus")

    # Define the logger scriptblock (Not used in async, but defined for reference or fallback)
    $loggerBlock = {
        param($msg)
        # Empty placeholder as we use internal log function in runspace
    }

    # Create the runspace
    # In 'irm | iex' scenarios, default session states are often broken.
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $iss.LanguageMode = [System.Management.Automation.PSLanguageMode]::FullLanguage
    
    # Pre-load critical system modules into the InitialSessionState
    # This is more reliable than Import-Module inside the scriptblock for restricted contexts
    $sysModPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules"
    $criticalModules = @("Appx", "ScheduledTasks", "Dism", "Storage", "NetAdapter", "DnsClient", "Defender", "NetSecurity", "MMAgent", "Microsoft.PowerShell.Archive")
    
    foreach ($mod in $criticalModules) {
        try {
            # Try to find the module manifest directly
            $manifestPath = Join-Path $sysModPath "$mod\$mod.psd1"
            if (Test-Path $manifestPath) {
                $iss.ImportPSModule($manifestPath)
            } else {
                # Fallback to name import if path is different
                $iss.ImportPSModule($mod)
            }
        } catch {
            # Log error but continue - missing one module shouldn't break everything
            Write-Host "Warning: Failed to pre-load module $mod - $_" -ForegroundColor Yellow
        }
    }

    $rs = [PowerShell]::Create($iss)
    
    # Capture host environment variables that might be missing in the runspace
    $hostModulePath = $env:PSModulePath
    
    # Add necessary modules and functions to the runspace
    $modulePath = $ScriptPath # Pass the script path (Local Scope first)
    if (-not $modulePath) { $modulePath = $global:ScriptPath } # Try Global Scope
    if (-not $modulePath) { $modulePath = $PWD.Path } # Fallback to PWD
    
    $rs.AddScript({
        param($Path, $SyncHash, $Task, $SuccessMsg, $HostModulePath, $TaskOptions)

        function Log($msg) {
            try {
                if ($SyncHash.Window -and -not $SyncHash.Window.Dispatcher.HasShutdownStarted) {
                    $timestamp = Get-Date -Format "HH:mm:ss"
                    $null = $SyncHash.Window.Dispatcher.BeginInvoke([Action]{
                        try {
                            if ($SyncHash.OutputBox) {
                                $line = "[$timestamp] $msg`n"
                                if ($SyncHash.OutputBox.Dispatcher.CheckAccess()) {
                                    $SyncHash.OutputBox.Text += $line
                                    if ($SyncHash.OutputBox.Parent -is [System.Windows.Controls.ScrollViewer]) {
                                        $SyncHash.OutputBox.Parent.ScrollToBottom()
                                    }
                                } else {
                                    $ob = $SyncHash.OutputBox
                                    $null = $ob.Dispatcher.BeginInvoke([Action]{
                                        $ob.Text += $line
                                        if ($ob.Parent -is [System.Windows.Controls.ScrollViewer]) {
                                            $ob.Parent.ScrollToBottom()
                                        }
                                    })
                                }
                            }
                            if ($SyncHash.StatusBox) {
                                if ($SyncHash.StatusBox.Dispatcher.CheckAccess()) {
                                    $SyncHash.StatusBox.Text = $msg
                                } else {
                                    $sb = $SyncHash.StatusBox
                                    $smsg = $msg
                                    $null = $sb.Dispatcher.BeginInvoke([Action]{ $sb.Text = $smsg })
                                }
                            }
                        } catch {}
                    })
                }
            } catch {
                Write-Host $msg
            }
        }

        # Set Global Root for modules to use
        $global:IlumnulRoot = $Path
        
        # Debug Log for Troubleshooting Path Issues
        $timestamp = Get-Date -Format "HH:mm:ss"
        Log "Runspace Initialized. Root Path: '$Path'"

        # FIX: Restore PSModulePath and ensure System32 modules are visible
        if ($HostModulePath) {
            $env:PSModulePath = $HostModulePath
        }
        
        # Explicitly add System32 PowerShell modules path if missing
        $sysModPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules"
        $sysNativeModPath = "$env:SystemRoot\SysNative\WindowsPowerShell\v1.0\Modules"
        
        # Detect if we need to force SysNative import (32-bit process on 64-bit OS)
        if (Test-Path $sysNativeModPath) {
             # We are in 32-bit mode, but need 64-bit modules for Appx
             Log "32-bit Process Detected. Attempting to load 64-bit modules from SysNative..."
             
             if ($env:PSModulePath -notlike "*$sysNativeModPath*") {
                $env:PSModulePath = "$sysNativeModPath;$env:PSModulePath"
             }
             
             # Force import Appx from SysNative with verbose logging on failure
             $modulesToLoad = @("Appx", "Dism", "ScheduledTasks", "Microsoft.PowerShell.Archive")
             foreach ($mod in $modulesToLoad) {
                try {
                    Import-Module "$sysNativeModPath\$mod\$mod.psd1" -ErrorAction Stop
                    Log "Loaded $mod from SysNative."
                } catch {
                    Log "Failed to load $mod from SysNative: $_"
                    # Last ditch attempt: name only
                    try { Import-Module $mod -ErrorAction SilentlyContinue } catch {}
                }
             }
        } else {
             if ($env:PSModulePath -notlike "*$sysModPath*") {
                $env:PSModulePath = "$sysModPath;$env:PSModulePath"
             }
             # Force import Appx from System32
             Import-Module "Appx" -ErrorAction SilentlyContinue
             Import-Module "Dism" -ErrorAction SilentlyContinue
             Import-Module "ScheduledTasks" -ErrorAction SilentlyContinue
             Import-Module "Microsoft.PowerShell.Archive" -ErrorAction SilentlyContinue
        }

        # FINAL CHECK: If modules are still missing, try one more time blindly
        if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
            Log "WARNING: Get-AppxPackage missing. Attempting blind import..."
            Import-Module Appx -ErrorAction SilentlyContinue
        }
        if (-not (Get-Command Get-AppxProvisionedPackage -ErrorAction SilentlyContinue)) {
            Log "WARNING: Get-AppxProvisionedPackage missing. Attempting blind import..."
            Import-Module Dism -ErrorAction SilentlyContinue
        }
        if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) {
            Log "WARNING: Get-ScheduledTask missing. Attempting blind import..."
            Import-Module ScheduledTasks -ErrorAction SilentlyContinue
        }

        # Create a proxy scriptblock for the module functions to use
        $LoggerProxy = { param($m) Log $m }
        
        try {
            if (-not $Path) {
                throw "Module path is null. Cannot import modules."
            }

            # Import Modules
            $modules = @("Debloat.psm1", "Gaming.psm1", "Optimize.psm1", "RemoveAI.psm1")
            foreach ($m in $modules) {
                $p = Join-Path $Path "Modules\$m"
                if (Test-Path $p) { Import-Module $p -Force }
            }
            
            # Execute the task
            Log "Starting Operation..."
            & $Task -Logger $LoggerProxy -Options $TaskOptions
            Log $SuccessMsg
            
        } catch {
            Log "ERROR: $_"
        }
    }).AddArgument($modulePath).AddArgument($syncHash).AddArgument($ScriptBlock).AddArgument($SuccessMessage).AddArgument($hostModulePath).AddArgument($OperationOptions)

    try {
        $asyncHandle = $rs.BeginInvoke()
    } catch {
        if (Get-Command Log-Message -ErrorAction SilentlyContinue) {
            Log-Message "Failed to start operation: $_"
        }
        try { $rs.Dispose() } catch {}
        return
    }

    if (-not $script:ActiveOperations) {
        $script:ActiveOperations = [System.Collections.ArrayList]::new()
    }

    $script:OperationInProgress = $true
    if (Get-Command Set-ActionButtonsState -ErrorAction SilentlyContinue) {
        Set-ActionButtonsState -Enabled $false
    }

    $opTimer = New-Object System.Windows.Threading.DispatcherTimer
    $opTimer.Interval = [TimeSpan]::FromMilliseconds(300)
    $opRef = @{ Runspace = $rs; Handle = $asyncHandle; Timer = $opTimer }
    [void]$script:ActiveOperations.Add($opRef)

    $opTimer.Add_Tick({
        $state = $rs.InvocationStateInfo.State
        if ($state -in @('Completed','Failed','Stopped')) {
            $opTimer.Stop()
            try { $rs.EndInvoke($asyncHandle) | Out-Null } catch {}
            try { $rs.Dispose() } catch {}
            if ($script:ActiveOperations) {
                for ($i = $script:ActiveOperations.Count - 1; $i -ge 0; $i--) {
                    if ($script:ActiveOperations[$i].Runspace -eq $rs) {
                        $script:ActiveOperations.RemoveAt($i)
                    }
                }
            }
            $script:OperationInProgress = $false
            if (Get-Command Set-ActionButtonsState -ErrorAction SilentlyContinue) {
                Set-ActionButtonsState -Enabled $true
            }
        }
    })
    $opTimer.Start()
}

try {
    $window.FindName("TopBar").Add_MouseLeftButtonDown({ $window.DragMove() })

    
    $btnMinimize = $window.FindName("btnMinimize")
    if ($btnMinimize) { $btnMinimize.Add_Click({ $window.WindowState = "Minimized" }) }
    
    $btnClose = $window.FindName("btnClose")
    if ($btnClose) { $btnClose.Add_Click({ $window.Close() }) }

    # Hardware Info Initialization
    $txtCpuName   = $window.FindName("txtCpuName")
    $txtGpuName   = $window.FindName("txtGpuName")
    $txtGpuDetail = $window.FindName("txtGpuDetail")
    $txtGpuDriver = $window.FindName("txtGpuDriver")
    $txtRamDetail = $window.FindName("txtRamDetail")
    $txtDiskDetail = $window.FindName("txtDiskDetail")
    $txtOsVersion = $window.FindName("txtOsVersion")

    # Gather Hardware Info
    $hwInfo = @{}
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $hwInfo.CPU = $cpu.Name
        
        $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
        $hwInfo.GPU = $gpu.Name
        
        $os = Get-CimInstance Win32_OperatingSystem
        $totalRamGB = [math]::Round($os.TotalVisibleMemorySize / 1MB / 1024, 0)
        $hwInfo.RAM = "$totalRamGB GB"
    } catch {
        $hwInfo.CPU = "Unknown CPU"
        $hwInfo.GPU = "Unknown GPU"
        $hwInfo.RAM = "Unknown RAM"
    }

    # Set Static Data (Names & OS)
    if ($txtCpuName) { $txtCpuName.Text = $hwInfo.CPU }
    if ($txtGpuName) { $txtGpuName.Text = $hwInfo.GPU }
    
    # Get Static Hardware Details
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        if ($txtOsVersion) { $txtOsVersion.Text = "$($osInfo.Caption) - Build $($osInfo.BuildNumber)" }
        
        $gpuInfo = Get-CimInstance Win32_VideoController | Select-Object -First 1
        if ($txtGpuDetail) { $txtGpuDetail.Text = "$($gpuInfo.CurrentHorizontalResolution) x $($gpuInfo.CurrentVerticalResolution) @ $($gpuInfo.CurrentRefreshRate)Hz" }
        if ($txtGpuDriver) { $txtGpuDriver.Text = "Driver: $($gpuInfo.DriverVersion)" }

        # RAM Total
        if ($txtRamDetail) { $txtRamDetail.Text = "$($hwInfo.RAM) Total" }

        # Disk C: Total Size
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        if ($disk -and $txtDiskDetail) {
             $totalDisk = [math]::Round($disk.Size / 1GB, 0)
             $txtDiskDetail.Text = "Drive C: $totalDisk GB Total"
        }
    } catch {}

    # -----------------------------------------------------------------------------
    # Real-Time Stats (Background Threading to prevent UI Lag)
    # -----------------------------------------------------------------------------
    
    # Synchronized Hashtable for thread-safe data exchange
    $syncHash = [Hashtable]::Synchronized(@{})
    $syncHash.CpuLoad = "0"
    $syncHash.CpuDetail = "Detecting..."
    $syncHash.RamDetail = "Detecting..."
    $syncHash.RamLoad = "0"
    $syncHash.RamPercent = 0
    $syncHash.DiskDetail = "Detecting..."
    $syncHash.DiskLoad = "0"
    $syncHash.DiskPercent = 0
    $syncHash.Uptime = "00:00:00"
    $syncHash.Run = $true

    # Create Runspace for background worker
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $runspace = [PowerShell]::Create($iss).AddScript({
        param($sync)
        
        # Import modules for hardware monitoring
        Import-Module CimCmdlets -ErrorAction SilentlyContinue
        Import-Module Storage -ErrorAction SilentlyContinue

        while ($sync.Run) {
            try {
                # CPU Stats (Fastest way using CIM)
                $cpu = Get-CimInstance Win32_Processor
                $load = $cpu.LoadPercentage
                $sync.CpuLoad = "$load%"
                $sync.CpuRaw = $load
                $sync.CpuDetail = "$($cpu.NumberOfCores) Cores / $($cpu.NumberOfLogicalProcessors) Threads @ $([math]::Round($cpu.MaxClockSpeed/1000, 2)) GHz"

                # RAM Stats
                $os = Get-CimInstance Win32_OperatingSystem
                $totalRam = $os.TotalVisibleMemorySize / 1MB
                $freeRam = $os.FreePhysicalMemory / 1MB
                $usedRam = $totalRam - $freeRam
                $ramPercent = [math]::Round(($usedRam / $totalRam) * 100, 0)
                
                $sync.RamDetail = "$([math]::Round($usedRam, 1)) GB / $([math]::Round($totalRam, 1)) GB"
                $sync.RamLoad = "$ramPercent%"
                $sync.RamPercent = $ramPercent

                # Disk Stats (C:)
                $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
                if ($disk) {
                    $totalDisk = $disk.Size / 1GB
                    $freeDisk = $disk.FreeSpace / 1GB
                    $usedDisk = $totalDisk - $freeDisk
                    $diskPercent = [math]::Round(($usedDisk / $totalDisk) * 100, 0)
                    
                    $sync.DiskDetail = "$([math]::Round($freeDisk, 1)) GB Free / $([math]::Round($totalDisk, 0)) GB"
                    $sync.DiskLoad = "$diskPercent%"
                    $sync.DiskPercent = $diskPercent
                }

                # Uptime
                $uptime = (Get-Date) - $os.LastBootUpTime
                $sync.Uptime = "{0:dd}d {0:hh}h {0:mm}m" -f $uptime
                
            } catch {
                # Log error or ignore
            }
            
            # Sleep to prevent high CPU usage from the monitoring thread itself
            Start-Sleep -Seconds 2
        }
    }).AddArgument($syncHash)
    
    # Start the background thread
    $asyncResult = $runspace.BeginInvoke()

    # UI Timer - ONLY updates UI from the synchronized hashtable (Lightweight)
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({
        try {
            Set-ControlTextSafe -Control $txtCpuLoad -Value $syncHash.CpuLoad
            if ($pbCpu) { $pbCpu.Value = $syncHash.CpuRaw }
            Set-ControlTextSafe -Control $txtCpuDetail -Value $syncHash.CpuDetail

            Set-ControlTextSafe -Control $txtRamDetail -Value $syncHash.RamDetail
            Set-ControlTextSafe -Control $txtRamLoad -Value $syncHash.RamLoad
            if ($pbRam) { $pbRam.Value = $syncHash.RamPercent }

            Set-ControlTextSafe -Control $txtDiskDetail -Value $syncHash.DiskDetail
            Set-ControlTextSafe -Control $txtDiskLoad -Value $syncHash.DiskLoad
            if ($pbDisk) { $pbDisk.Value = $syncHash.DiskPercent }

            Set-ControlTextSafe -Control $txtUptime -Value $syncHash.Uptime
        } catch { }
    })
    $timer.Start()

    # Cleanup on Close
    $window.Add_Closed({
        $syncHash.Run = $false
        if ($timer) { $timer.Stop() }
    })

    # Navigation
    $views = @{
        "Dashboard" = $window.FindName("viewDashboard")
        "Debloat"   = $window.FindName("viewDebloat")
        "Gaming"    = $window.FindName("viewGaming")
        "Privacy"   = $window.FindName("viewPrivacy")
        "AI"        = $window.FindName("viewAI")
        "Settings"  = $window.FindName("viewSettings")
        "Terminal"  = $window.FindName("viewTerminal")
    }

    $sbSlideIn = $window.Resources["SlideInRight"]

    function Switch-View {
        param($Name)
        foreach ($key in $views.Keys) {
            if ($views[$key]) { 
                $views[$key].Visibility = "Collapsed" 
            }
        }
        if ($views[$Name]) { 
            $views[$Name].Visibility = "Visible"
            if ($sbSlideIn) {
                $sbSlideIn.Begin($views[$Name])
            }
        }
    }

    $window.FindName("navDashboard").Add_Click({ Switch-View "Dashboard" })
    $window.FindName("navDebloat").Add_Click({ Switch-View "Debloat" })
    $window.FindName("navGaming").Add_Click({ Switch-View "Gaming" })
    $window.FindName("navPrivacy").Add_Click({ Switch-View "Privacy" })
    $window.FindName("navAI").Add_Click({ Switch-View "AI" })
    $window.FindName("navSettings").Add_Click({ Switch-View "Settings" })
    $window.FindName("navTerminal").Add_Click({ Switch-View "Terminal" })

    function Set-ControlTextSafe {
        param($Control, [string]$Value)
        if (-not $Control) { return }
        try {
            if ($Control.Dispatcher.CheckAccess()) {
                $Control.Text = $Value
            } else {
                $target = $Control
                $textValue = $Value
                $null = $target.Dispatcher.BeginInvoke([Action]{ $target.Text = $textValue })
            }
        } catch {}
    }

    # Logging System
    $txtTerminalOutput = $window.FindName("txtTerminalOutput")
    $txtStatus = $window.FindName("txtStatus")
    
    function Log-Message {
        param([string]$Message)
        $appendUi = {
            $timestamp = Get-Date -Format "HH:mm:ss"
            if ($txtTerminalOutput) {
                $txtTerminalOutput.Text += "[$timestamp] $Message`n"
                if ($txtTerminalOutput.Parent -is [System.Windows.Controls.ScrollViewer]) {
                    $txtTerminalOutput.Parent.ScrollToBottom()
                }
            }
            Set-ControlTextSafe -Control $txtStatus -Value $Message
        }
        try {
            if ($window -and $window.Dispatcher.CheckAccess()) {
                & $appendUi
            } else {
                $null = $window.Dispatcher.BeginInvoke([Action]$appendUi)
            }
        } catch {
            Write-Host $Message
        }
    }

    $window.Dispatcher.add_UnhandledException({
        param($sender, $e)
        try {
            Log-Message "UI Exception: $($e.Exception.Message)"
            $e.Handled = $true
        } catch {}
    })
    
    $window.FindName("btnClearTerminal").Add_Click({ Set-ControlTextSafe -Control $txtTerminalOutput -Value "" })

    # Actions
    $btnOneClick = $window.FindName("btnOneClick")
    $btnRunDebloat = $window.FindName("btnRunDebloat")
    $btnRunGaming = $window.FindName("btnRunGaming")
    $btnNvidiaProfile = $window.FindName("btnNvidiaProfile")
    $btnRunPrivacy = $window.FindName("btnRunPrivacy")
    $btnRunAI = $window.FindName("btnRunAI")
    $btnRunOptimize = $window.FindName("btnRunOptimize")
    $chkRemoveAppx = $window.FindName("chkRemoveAppx")
    $chkRemoveOneDrive = $window.FindName("chkRemoveOneDrive")
    $chkRemoveCortana = $window.FindName("chkRemoveCortana")
    $chkDisableServices = $window.FindName("chkDisableServices")
    $chkGameMode = $window.FindName("chkGameMode")
    $chkGPUPriority = $window.FindName("chkGPUPriority")
    $chkDisableGameBar = $window.FindName("chkDisableGameBar")
    $chkHAGS = $window.FindName("chkHAGS")
    $chkNetworkTweaks = $window.FindName("chkNetworkTweaks")
    $chkDisableTelemetry = $window.FindName("chkDisableTelemetry")
    $chkDisableAdvertising = $window.FindName("chkDisableAdvertising")
    $chkDisableLocation = $window.FindName("chkDisableLocation")
    $chkDisableCopilot = $window.FindName("chkDisableCopilot")
    $chkDisableRecall = $window.FindName("chkDisableRecall")
    $chkDisableOfficeAI = $window.FindName("chkDisableOfficeAI")
    $chkPowerPlan = $window.FindName("chkPowerPlan")
    $chkDisableHibernation = $window.FindName("chkDisableHibernation")
    $chkDisableSearchIndexing = $window.FindName("chkDisableSearchIndexing")
    $chkVisualEffects = $window.FindName("chkVisualEffects")
    $btnCleanTemp = $window.FindName("btnCleanTemp")
    $btnRestartExplorer = $window.FindName("btnRestartExplorer")
    $btnFlushDNS = $window.FindName("btnFlushDNS")

    $script:OperationInProgress = $false
    $script:TweakButtons = @($btnOneClick, $btnRunDebloat, $btnRunGaming, $btnNvidiaProfile, $btnRunPrivacy, $btnRunAI, $btnRunOptimize, $btnCleanTemp, $btnRestartExplorer, $btnFlushDNS)

    function Set-ActionButtonsState {
        param([bool]$Enabled)
        foreach ($btn in $script:TweakButtons) {
            if ($btn) {
                $btn.IsEnabled = $Enabled
            }
        }
    }

    $logAction = [Action[string]] { param($msg) Log-Message $msg }

    if ($btnRunDebloat) {
        $btnRunDebloat.Add_Click({
            if ([System.Windows.MessageBox]::Show("This will remove pre-installed apps and disable services. Continue?", "Confirm Debloat", "YesNo", "Warning") -eq "Yes") {
                $opts = @{
                    RemoveAppx = [bool]$chkRemoveAppx.IsChecked
                    RemoveOneDrive = [bool]$chkRemoveOneDrive.IsChecked
                    RemoveCortana = [bool]$chkRemoveCortana.IsChecked
                    DisableServices = [bool]$chkDisableServices.IsChecked
                    DisableTelemetry = $true
                    DisableAdvertising = $true
                    DisableLocation = $true
                }
                Start-AsyncOperation -ScriptBlock { param($Logger, $Options) Remove-Bloatware -Logger $Logger -Options $Options } -OperationOptions $opts -SuccessMessage "Debloat Finished."
            }
        })
    }
    
    if ($btnRunGaming) {
        $btnRunGaming.Add_Click({
            if ([System.Windows.MessageBox]::Show("This will apply gaming optimizations and power plans. Continue?", "Confirm Gaming Boost", "YesNo", "Information") -eq "Yes") {
                $opts = @{
                    GameMode = [bool]$chkGameMode.IsChecked
                    GPUPriority = [bool]$chkGPUPriority.IsChecked
                    DisableGameBar = [bool]$chkDisableGameBar.IsChecked
                    HAGS = [bool]$chkHAGS.IsChecked
                    NetworkTweaks = [bool]$chkNetworkTweaks.IsChecked
                }
                Start-AsyncOperation -ScriptBlock { param($Logger, $Options) Invoke-GamingOptimization -Logger $Logger -Options $Options } -OperationOptions $opts -SuccessMessage "Gaming Boost Finished."
            }
        })
    }

    if ($btnNvidiaProfile) {
        $btnNvidiaProfile.Add_Click({
            if ([System.Windows.MessageBox]::Show("This will download and apply a custom NVIDIA Profile. Continue?", "Confirm NVIDIA Profile", "YesNo", "Information") -eq "Yes") {
                Start-AsyncOperation -ScriptBlock { param($Logger, $Options) Invoke-NvidiaProfile -Logger $Logger } -SuccessMessage "NVIDIA Profile Process Finished."
            }
        })
    }

    if ($btnRunPrivacy) {
        $btnRunPrivacy.Add_Click({
            if ([System.Windows.MessageBox]::Show("This will disable telemetry and tracking features. Continue?", "Confirm Privacy", "YesNo", "Information") -eq "Yes") {
                $opts = @{
                    RemoveAppx = $false
                    RemoveOneDrive = $false
                    RemoveCortana = $false
                    DisableServices = $false
                    DisableTelemetry = [bool]$chkDisableTelemetry.IsChecked
                    DisableAdvertising = [bool]$chkDisableAdvertising.IsChecked
                    DisableLocation = [bool]$chkDisableLocation.IsChecked
                }
                Start-AsyncOperation -ScriptBlock { param($Logger, $Options) Remove-Bloatware -Logger $Logger -Options $Options } -OperationOptions $opts -SuccessMessage "Privacy Tweaks Applied."
            }
        })
    }

    if ($btnRunAI) {
        $btnRunAI.Add_Click({
            if ([System.Windows.MessageBox]::Show("WARNING: This will permanently remove Copilot, Recall, and AI components. This action is aggressive. Continue?", "Confirm AI Removal", "YesNo", "Warning") -eq "Yes") {
                $opts = @{
                    DisableCopilot = [bool]$chkDisableCopilot.IsChecked
                    DisableRecall = [bool]$chkDisableRecall.IsChecked
                    DisableOfficeAI = [bool]$chkDisableOfficeAI.IsChecked
                }
                Start-AsyncOperation -ScriptBlock { param($Logger, $Options) Remove-WindowsAI -Logger $Logger -Options $Options } -OperationOptions $opts -SuccessMessage "AI Removal Complete."
            }
        })
    }

    if ($btnRunOptimize) {
        $btnRunOptimize.Add_Click({
            if ([System.Windows.MessageBox]::Show("This will apply general system performance tweaks. Continue?", "Confirm Optimization", "YesNo", "Information") -eq "Yes") {
                $opts = @{
                    PowerPlan = [bool]$chkPowerPlan.IsChecked
                    DisableHibernation = [bool]$chkDisableHibernation.IsChecked
                    DisableSearchIndexing = [bool]$chkDisableSearchIndexing.IsChecked
                    VisualEffects = [bool]$chkVisualEffects.IsChecked
                }
                Start-AsyncOperation -ScriptBlock { param($Logger, $Options) Invoke-SystemOptimization -Logger $Logger -Options $Options } -OperationOptions $opts -SuccessMessage "System Optimization Finished."
            }
        })
    }

    if ($btnOneClick) {
        $btnOneClick.Add_Click({
            if ([System.Windows.MessageBox]::Show("ONE-CLICK MODE: This will run ALL optimizations (Debloat, Gaming, AI Removal, System). This may take a while. Are you sure?", "Confirm One-Click", "YesNo", "Warning") -eq "Yes") {
                Start-AsyncOperation -ScriptBlock { 
                    param($Logger, $Options)
                    Invoke-SystemOptimization -Logger $Logger
                    Invoke-GamingOptimization -Logger $Logger
                    Remove-Bloatware -Logger $Logger
                    Remove-WindowsAI -Logger $Logger
                } -SuccessMessage "One-Click Optimization Complete."
            }
        })
    }

    # Quick Actions
    $btnCleanTemp.Add_Click({
        Start-AsyncOperation -ScriptBlock {
            param($Logger, $Options)
            if ($Logger) { $Logger.Invoke("Cleaning Temp Files...") }
            Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
            if ($Logger) { $Logger.Invoke("Temp Files Cleaned.") }
        } -SuccessMessage "Temp cleanup finished."
    })
    
    $btnRestartExplorer.Add_Click({
        Start-AsyncOperation -ScriptBlock {
            param($Logger, $Options)
            if ($Logger) { $Logger.Invoke("Restarting Explorer...") }
            Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
            if ($Logger) { $Logger.Invoke("Explorer Restarted.") }
        } -SuccessMessage "Explorer restart finished."
    })

    $btnFlushDNS.Add_Click({
        Start-AsyncOperation -ScriptBlock {
            param($Logger, $Options)
            if ($Logger) { $Logger.Invoke("Flushing DNS...") }
            ipconfig /flushdns | Out-Null
            if ($Logger) { $Logger.Invoke("DNS Flushed.") }
        } -SuccessMessage "DNS flush finished."
    })

} catch {
    Write-Host "UI Initialization Error: $_"
}

if ($window) {
    try {
        $window.ShowDialog() | Out-Null
    } catch {
        Write-Error "CRITICAL ERROR: Failed to show window dialog. $_"
    } finally {
        # Cleanup background resources after window closes to prevent UI freeze
        if ($syncHash) { $syncHash.Run = $false }

        if ($script:ActiveOperations) {
            foreach ($op in @($script:ActiveOperations)) {
                try { if ($op.Timer) { $op.Timer.Stop() } } catch {}
                try {
                    if ($op.Runspace -and $op.Runspace.InvocationStateInfo.State -eq 'Running') {
                        $op.Runspace.Stop()
                    }
                } catch {}
                try { if ($op.Runspace) { $op.Runspace.Dispose() } } catch {}
            }
        }
        
        if ($runspace) {
            try {
                if ($runspace.InvocationStateInfo.State -eq 'Running') {
                    $runspace.Stop()
                }
                $runspace.Dispose()
            } catch {}
        }
    }
}
