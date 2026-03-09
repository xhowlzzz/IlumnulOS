# IlumnulOS - Created by Howl
# Windows 11 Optimization & Debloating Tool - Ultimate Edition
# Features: Glass/iOS-like UI, Animations, Modern Design, Loading Screen, Custom Terminal (#517755)

# Load required assemblies
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
        
        $InstallPath = "$env:TEMP\IlumnulOS_v2"
        $RepoUrl = "https://raw.githubusercontent.com/xhowlzzz/IlumnulOS/main"
        
        # Clean cleanup to ensure fresh files
        if (Test-Path $InstallPath) {
            Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Create Directories
        New-Item -ItemType Directory -Path "$InstallPath\Modules" -Force | Out-Null
        New-Item -ItemType Directory -Path "$InstallPath\Assets" -Force | Out-Null
        New-Item -ItemType Directory -Path "$InstallPath\Config" -Force | Out-Null
        
        # Helper to download with cache busting
        function Download-File {
            param($RemotePath, $LocalPath)
            try {
                $cb = Get-Random
                Write-Host "Downloading $RemotePath..." -NoNewline
                Invoke-WebRequest -Uri "$RepoUrl/$RemotePath?v=$cb" -OutFile "$LocalPath" -UseBasicParsing
                Write-Host " [OK]" -ForegroundColor Green
            } catch {
                Write-Host " [FAILED]" -ForegroundColor Red
                Write-Error "Failed to download $RemotePath. Check internet connection."
                exit
            }
        }
    
    # Download Core Files
    Download-File "Assets/MainWindow.xaml" "$InstallPath\Assets\MainWindow.xaml"
    Download-File "Config/settings.json" "$InstallPath\Config\settings.json"
    Download-File "Modules/Debloat.psm1" "$InstallPath\Modules\Debloat.psm1"
    Download-File "Modules/Gaming.psm1" "$InstallPath\Modules\Gaming.psm1"
    Download-File "Modules/Optimize.psm1" "$InstallPath\Modules\Optimize.psm1"
    Download-File "Modules/RemoveAI.psm1" "$InstallPath\Modules\RemoveAI.psm1"
    
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
    exit
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
    exit
}

# -----------------------------------------------------------------------------
# Async Execution Helper
# -----------------------------------------------------------------------------
function Start-AsyncOperation {
    param(
        [ScriptBlock]$ScriptBlock,
        [string]$SuccessMessage = "Operation Completed.",
        [switch]$ShowTerminal = $true
    )

    if ($ShowTerminal) {
        Switch-View "Terminal"
        $window.FindName("navTerminal").IsChecked = $true
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
        param($Path, $SyncHash, $Task, $SuccessMsg, $HostModulePath)

        # Set Global Root for modules to use
        $global:IlumnulRoot = $Path
        
        # Debug Log for Troubleshooting Path Issues
        $timestamp = Get-Date -Format "HH:mm:ss"
        $SyncHash.Window.Dispatcher.Invoke([Action]{
             if ($SyncHash.OutputBox) {
                 $SyncHash.OutputBox.Text += "[$timestamp] Runspace Initialized. Root Path: '$Path'`n"
             }
        })

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

        # Define Log function inside runspace that calls back to UI
        function Log($msg) {
            $timestamp = Get-Date -Format "HH:mm:ss"
            $SyncHash.Window.Dispatcher.Invoke([Action]{
                if ($SyncHash.OutputBox) {
                    $SyncHash.OutputBox.Text += "[$timestamp] $msg`n"
                    if ($SyncHash.OutputBox.Parent -is [System.Windows.Controls.ScrollViewer]) {
                        $SyncHash.OutputBox.Parent.ScrollToBottom()
                    }
                }
                if ($SyncHash.StatusBox) { $SyncHash.StatusBox.Text = $msg }
            })
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
            & $Task -Logger $LoggerProxy
            Log $SuccessMsg
            
        } catch {
            Log "ERROR: $_"
        }
    }).AddArgument($modulePath).AddArgument($syncHash).AddArgument($ScriptBlock).AddArgument($SuccessMessage).AddArgument($hostModulePath)

    # Run async
    $rs.BeginInvoke()
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
            if ($txtCpuLoad) { $txtCpuLoad.Text = $syncHash.CpuLoad }
            if ($pbCpu) { $pbCpu.Value = $syncHash.CpuRaw }
            if ($txtCpuDetail) { $txtCpuDetail.Text = $syncHash.CpuDetail }

            if ($txtRamDetail) { $txtRamDetail.Text = $syncHash.RamDetail }
            if ($txtRamLoad) { $txtRamLoad.Text = $syncHash.RamLoad }
            if ($pbRam) { $pbRam.Value = $syncHash.RamPercent }

            if ($txtDiskDetail) { $txtDiskDetail.Text = $syncHash.DiskDetail }
            if ($txtDiskLoad) { $txtDiskLoad.Text = $syncHash.DiskLoad }
            if ($pbDisk) { $pbDisk.Value = $syncHash.DiskPercent }

            if ($txtUptime) { $txtUptime.Text = $syncHash.Uptime }
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

    # Logging System
    $txtTerminalOutput = $window.FindName("txtTerminalOutput")
    $txtStatus = $window.FindName("txtStatus")
    
    function Log-Message {
        param([string]$Message)
        $timestamp = Get-Date -Format "HH:mm:ss"
        if ($txtTerminalOutput) {
            $txtTerminalOutput.Text += "[$timestamp] $Message`n"
            if ($txtTerminalOutput.Parent -is [System.Windows.Controls.ScrollViewer]) {
                $txtTerminalOutput.Parent.ScrollToBottom()
            }
        }
        if ($txtStatus) { $txtStatus.Text = $Message }
        $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
    }
    
    $window.FindName("btnClearTerminal").Add_Click({ if ($txtTerminalOutput) { $txtTerminalOutput.Text = "" } })

    # Actions
    $btnOneClick = $window.FindName("btnOneClick")
    $btnRunDebloat = $window.FindName("btnRunDebloat")
    $btnRunGaming = $window.FindName("btnRunGaming")
    $btnNvidiaProfile = $window.FindName("btnNvidiaProfile")
    $btnRunPrivacy = $window.FindName("btnRunPrivacy")
    $btnRunAI = $window.FindName("btnRunAI")
    $btnRunOptimize = $window.FindName("btnRunOptimize")

    $logAction = [Action[string]] { param($msg) Log-Message $msg }

    if ($btnRunDebloat) {
        $btnRunDebloat.Add_Click({
            if ([System.Windows.MessageBox]::Show("This will remove pre-installed apps and disable services. Continue?", "Confirm Debloat", "YesNo", "Warning") -eq "Yes") {
                Start-AsyncOperation -ScriptBlock { param($Logger) Remove-Bloatware -Logger $Logger } -SuccessMessage "Debloat Finished."
            }
        })
    }
    
    if ($btnRunGaming) {
        $btnRunGaming.Add_Click({
            if ([System.Windows.MessageBox]::Show("This will apply gaming optimizations and power plans. Continue?", "Confirm Gaming Boost", "YesNo", "Information") -eq "Yes") {
                Start-AsyncOperation -ScriptBlock { param($Logger) Invoke-GamingOptimization -Logger $Logger } -SuccessMessage "Gaming Boost Finished."
            }
        })
    }

    if ($btnNvidiaProfile) {
        $btnNvidiaProfile.Add_Click({
            if ([System.Windows.MessageBox]::Show("This will download and apply a custom NVIDIA Profile. Continue?", "Confirm NVIDIA Profile", "YesNo", "Information") -eq "Yes") {
                Start-AsyncOperation -ScriptBlock { param($Logger) Invoke-NvidiaProfile -Logger $Logger } -SuccessMessage "NVIDIA Profile Process Finished."
            }
        })
    }

    if ($btnRunPrivacy) {
        $btnRunPrivacy.Add_Click({
            if ([System.Windows.MessageBox]::Show("This will disable telemetry and tracking features. Continue?", "Confirm Privacy", "YesNo", "Information") -eq "Yes") {
                Start-AsyncOperation -ScriptBlock { param($Logger) Remove-Bloatware -Logger $Logger } -SuccessMessage "Privacy Tweaks Applied."
            }
        })
    }

    if ($btnRunAI) {
        $btnRunAI.Add_Click({
            if ([System.Windows.MessageBox]::Show("WARNING: This will permanently remove Copilot, Recall, and AI components. This action is aggressive. Continue?", "Confirm AI Removal", "YesNo", "Warning") -eq "Yes") {
                Start-AsyncOperation -ScriptBlock { param($Logger) Remove-WindowsAI -Logger $Logger } -SuccessMessage "AI Removal Complete."
            }
        })
    }

    if ($btnRunOptimize) {
        $btnRunOptimize.Add_Click({
            if ([System.Windows.MessageBox]::Show("This will apply general system performance tweaks. Continue?", "Confirm Optimization", "YesNo", "Information") -eq "Yes") {
                Start-AsyncOperation -ScriptBlock { param($Logger) Invoke-SystemOptimization -Logger $Logger } -SuccessMessage "System Optimization Finished."
            }
        })
    }

    if ($btnOneClick) {
        $btnOneClick.Add_Click({
            if ([System.Windows.MessageBox]::Show("ONE-CLICK MODE: This will run ALL optimizations (Debloat, Gaming, AI Removal, System). This may take a while. Are you sure?", "Confirm One-Click", "YesNo", "Warning") -eq "Yes") {
                Start-AsyncOperation -ScriptBlock { 
                    param($Logger) 
                    Invoke-SystemOptimization -Logger $Logger
                    Invoke-GamingOptimization -Logger $Logger
                    Remove-Bloatware -Logger $Logger
                    Remove-WindowsAI -Logger $Logger
                } -SuccessMessage "One-Click Optimization Complete."
            }
        })
    }

    # Quick Actions
    $window.FindName("btnCleanTemp").Add_Click({
        Log-Message "Cleaning Temp Files..."
        Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        Log-Message "Temp Files Cleaned."
    })
    
    $window.FindName("btnRestartExplorer").Add_Click({
        Log-Message "Restarting Explorer..."
        Stop-Process -Name "explorer" -Force
        Log-Message "Explorer Restarted."
    })

    $window.FindName("btnFlushDNS").Add_Click({
        Log-Message "Flushing DNS..."
        ipconfig /flushdns | Out-Null
        Log-Message "DNS Flushed."
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
