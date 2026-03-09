# Optimize Module
function Invoke-SystemOptimization {
    param(
        [Action[string]]$Logger,
        [hashtable]$Options = @{}
    )
    
    function Log($msg) { if ($Logger) { $Logger.Invoke($msg) } else { Write-Host $msg } }

    Log "Starting System Optimizations..."
    $UsePowerPlan = if ($Options.ContainsKey("PowerPlan")) { [bool]$Options.PowerPlan } else { $true }
    $DisableHibernation = if ($Options.ContainsKey("DisableHibernation")) { [bool]$Options.DisableHibernation } else { $true }
    $DisableSearchIndexing = if ($Options.ContainsKey("DisableSearchIndexing")) { [bool]$Options.DisableSearchIndexing } else { $false }
    $TuneVisualEffects = if ($Options.ContainsKey("VisualEffects")) { [bool]$Options.VisualEffects } else { $true }

    function Set-Reg {
        param($Path, $Name, $Value, $Type = "DWord")
        try {
            if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction SilentlyContinue
            Log "Set $Name to $Value in $Path"
        } catch {
            Log "Error setting $Name`: $_"
        }
    }

    # Create Restore Point
    Log "Creating System Restore Point..."
    try {
        Checkpoint-Computer -Description "IlumnulOS_Optimization" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
    } catch {
        Log "Could not create restore point. Ensure System Protection is enabled."
    }

    # Visual Effects - Performance
    if ($TuneVisualEffects) {
        Log "Optimizing Visual Effects for Performance..."
        Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
        Set-Reg "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) "Binary"
        Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" "String"
    }

    # Virtual Memory (Ensure System Managed for Stability)
    Log "Configuring Virtual Memory..."
    try {
        $sysInfo = Get-CimInstance Win32_ComputerSystem
        if (-not $sysInfo.AutomaticManagedPagefile) {
            $sysInfo.AutomaticManagedPagefile = $true
            Set-CimInstance -CimInstance $sysInfo
            Log "Enabled Automatic Managed Pagefile."
        }
    } catch {
        Log "Failed to configure Pagefile: $_"
    }

    # Storage Optimization (TRIM/Defrag)
    Log "Optimizing Storage Drives..."
    try {
        Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' } | ForEach-Object {
            Log "Optimizing Drive $($_.DriveLetter)..."
            Optimize-Volume -DriveLetter $_.DriveLetter -NormalPriority -ErrorAction SilentlyContinue
        }
    } catch {
        Log "Storage optimization failed: $_"
    }

    # BCD Tweaks
    Log "Applying BCD Tweaks..."
    & bcdedit /set useplatformclock No
    & bcdedit /set useplatformtick No
    & bcdedit /set disabledynamictick Yes

    # Disable Mitigations (Spectre/Meltdown) - Warning: Reduces Security
    Log "Disabling Mitigations..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DisableExceptionChainValidation" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "KernelSEHOPEnabled" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "EnableCfg" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "ProtectionMode" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettings" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 3
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" 3

    # NTFS Tweaks
    Log "Applying NTFS Tweaks..."
    & fsutil behavior set memoryusage 2
    & fsutil behavior set mftzone 4
    & fsutil behavior set disablelastaccess 1
    & fsutil behavior set disabledeletenotify 0
    & fsutil behavior set encryptpagingfile 0

    # Disable Memory Compression & Page Combining
    Log "Disabling Memory Compression..."
    Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
    Disable-MMAgent -PageCombining -ErrorAction SilentlyContinue

    # Win32Priority
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38

    # Large System Cache
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 1

    # Disable Fast Startup & Hibernation
    if ($DisableHibernation) {
        Log "Disabling Hibernation..."
        & powercfg /h off
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 0
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "SleepReliabilityDetailedDiagnostics" 0
    }

    # Disable Sleep Study
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "SleepStudyDisabled" 1

    # Disable DEP (Data Execution Prevention) - Warning: Reduces Security
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" "DEPOff" 1

    # Disable Automatic Maintenance
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" "MaintenanceDisabled" 1

    # Disable Paging Executive
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 1

    # Disable FTH (Fault Tolerant Heap)
    Set-Reg "HKLM:\SOFTWARE\Microsoft\FTH" "Enabled" 0

    # SvcHost Split Threshold (Set to Total RAM)
    try {
        $MemoryKB = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1KB
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control" "SvcHostSplitThresholdInKB" ([int]$MemoryKB)
    } catch {
        Log "Failed to set SvcHostSplitThreshold: $_"
    }

    # Disable Dynamic Tick (BCD)
    try {
        & bcdedit /set disabledynamictick yes
        Log "Dynamic Ticking disabled successfully"
    } catch {
        Log "Failed to apply Dynamic Ticking tweak"
    }

    # Disable ASLR
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "MoveImages" 0

    # Disable Power Throttling
    Log "Disabling Power Throttling..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1

    # MenuShowDelay
    Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" 0

    # Disable Energy Logging
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy" "DisableTaggedEnergyLogging" 1

    # Service Priorities (Kernel, DWM, etc.)
    Log "Setting Service Priorities..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System" "PassiveIntRealTimeWorkerPriority" 18
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\KernelVelocity" "DisableFGBoostDecay" 1
    
    # Image File Execution Options (CpuPriorityClass / IoPriority)
    $services = @(
        "dwm.exe", "lsass.exe", "ntoskrnl.exe", "SearchIndexer.exe", "svchost.exe", 
        "TrustedInstaller.exe", "wuauclt.exe", "audiodg.exe"
    )
    # Simplified mapping for this example (setting all to high/critical as per request)
    foreach ($svc in $services) {
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$svc\PerfOptions" "CpuPriorityClass" 4 # High
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$svc\PerfOptions" "IoPriority" 3 # High
    }

    # PCI Express Power Management (Link State Power Management - Off)
    Log "Setting PCIe Power Management to Off (Max Performance)..."
    try {
        & powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS LINK_STATE_POWER_MANAGEMENT 0
        & powercfg /setdcvalueindex SCHEME_CURRENT SUB_PCIEXPRESS LINK_STATE_POWER_MANAGEMENT 0
        & powercfg /setactive SCHEME_CURRENT
    } catch {
        Log "PCIe Power tweak failed: $_"
    }

    # Clean Windows Update Cache (SoftwareDistribution / Catroot2)
    Log "Cleaning Windows Update Cache..."
    try {
        Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "cryptSvc" -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "bits" -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "msiserver" -Force -ErrorAction SilentlyContinue
        
        Remove-Item -Path "C:\Windows\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Windows\System32\catroot2" -Recurse -Force -ErrorAction SilentlyContinue
        
        Start-Service -Name "cryptSvc" -ErrorAction SilentlyContinue
        Start-Service -Name "bits" -ErrorAction SilentlyContinue
        Start-Service -Name "msiserver" -ErrorAction SilentlyContinue
        # wuauserv left stopped/manual per previous tweak
    } catch {
        Log "Windows Update cleanup failed: $_"
    }

    # Disable Windows Updates (Partial - Pause/Disable Auto Update)
    Log "Disabling Windows Auto Updates..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions" 2
    try {
        Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
        # We don't disable wuauserv completely as it breaks Store, but we stop it and set to Manual
        Set-Service -Name "wuauserv" -StartupType Manual -ErrorAction SilentlyContinue
    } catch {}

    # Disable Network Protocols (IPv6, Teredo, ISATAP)
    Log "Disabling Unnecessary Network Protocols..."
    try {
        Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
        netsh interface teredo set state disabled
        netsh interface isatap set state disabled
        netsh interface 6to4 set state disabled
    } catch {
        Log "Network protocol tweak failed: $_"
    }

    # Disable Diagnostic Tools & Defrag
    Log "Disabling Diagnostic Tools..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" "Enabled" 0
    try {
        Disable-ScheduledTask -TaskName "\Microsoft\Windows\Defrag\ScheduledDefrag" -ErrorAction SilentlyContinue
    } catch {}

    # Block Shadow Domains (Hosts File)
    Log "Blocking Telemetry Domains..."
    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $telemetryDomains = @(
        "v10.events.data.microsoft.com", "v20.events.data.microsoft.com",
        "settings-win.data.microsoft.com", "watson.telemetry.microsoft.com",
        "oca.telemetry.microsoft.com", "telemetry.urs.microsoft.com"
    )
    try {
        $hostsContent = Get-Content $hostsPath -Raw -ErrorAction SilentlyContinue
        foreach ($domain in $telemetryDomains) {
            if ($hostsContent -notmatch $domain) {
                Add-Content -Path $hostsPath -Value "0.0.0.0 $domain" -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Log "Failed to update hosts file (Run as Admin?)"
    }

    # Realtek Audio Power Settings
    Log "Optimizing Realtek Audio Power..."
    $realtekKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}"
    if (Test-Path $realtekKey) {
        Get-ChildItem $realtekKey -Recurse | Where-Object { $_.Property -contains "PowerSettings" } | ForEach-Object {
            $key = $_.PSPath
            Set-Reg "$key\PowerSettings" "ConservationIdleTime" ([byte[]](0x00,0x00,0x00,0x00)) "Binary"
            Set-Reg "$key\PowerSettings" "IdlePowerState" ([byte[]](0x00,0x00,0x00,0x00)) "Binary"
            Set-Reg "$key\PowerSettings" "PerformanceIdleTime" ([byte[]](0x00,0x00,0x00,0x00)) "Binary"
        }
    }

    # NTFS Compression (CompactOS)
    Log "Applying CompactOS Compression..."
    try {
        compact.exe /CompactOS:always
    } catch {
        Log "CompactOS failed: $_"
    }

    # Disable Windows Defender (Partial / Registry based)
    Log "Disabling Windows Defender..."
    try {
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
        Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
    } catch {}
    
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiSpyware" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableRealtimeMonitoring" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" "SpynetReporting" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" "ConfigureAppInstallControlEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" "DisableEnhancedNotifications" 1
    
    # Latency Tolerance
    Log "Setting Latency Tolerance..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl" "MonitorLatencyTolerance" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "LatencyToleranceDefault" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "LatencyToleranceVSyncEnabled" 1

    # Resource Policy Store (CPU Scheduling & Priority)
    Log "Configuring Resource Policies (Hard Caps & Importance)..."
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\HardCap0" "CapPercentage" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\HardCap0" "SchedulingType" 0
    
    # Disable Background Flags
    $flags = @("BackgroundDefault", "Frozen", "FrozenDNCS", "FrozenDNK", "FrozenPPLE", "Paused", "PausedDNK", "Pausing", "PrelaunchForeground", "ThrottleGPUInterference")
    foreach ($flag in $flags) {
        Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Flags\$flag" "IsLowPriority" 0
    }

    # Set Importance Priorities (Boost everything to Base 82 / Target 50 as requested)
    $importanceLevels = @("Critical", "CriticalNoUi", "EmptyHostPPLE", "High", "Low", "Lowest", "Medium", "MediumHigh", "StartHost", "VeryHigh", "VeryLow")
    foreach ($level in $importanceLevels) {
        Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\$level" "BasePriority" 82
        Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\$level" "OverTargetPriority" 50
    }

    # Unlimited IO & Memory
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\IO\NoCap" "IOBandwidth" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Memory\NoCap" "CommitLimit" 4294967295
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Memory\NoCap" "CommitTarget" 4294967295

    # Accessibility Tweaks
    Log "Disabling Sticky/Filter/Toggle Keys..."
    Set-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506" "String"
    Set-Reg "HKCU:\Control Panel\Accessibility\Keyboard Response" "Flags" "122" "String"
    Set-Reg "HKCU:\Control Panel\Accessibility\ToggleKeys" "Flags" "58" "String"

    # Mouse & Keyboard Optimization
    Log "Optimizing Mouse & Keyboard Response..."
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSensitivity" "10" "String"
    Set-Reg "HKCU:\Control Panel\Keyboard" "KeyboardDelay" "0" "String"
    Set-Reg "HKCU:\Control Panel\Keyboard" "KeyboardSpeed" "31" "String"
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" "MouseDataQueueSize" 16
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" "KeyboardDataQueueSize" 16
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DebugPollInterval" 1000
    
    # Disable Mouse Smoothing
    Set-Reg "HKCU:\Control Panel\Mouse" "SmoothMouseXCurve" ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) "Binary"
    Set-Reg "HKCU:\Control Panel\Mouse" "SmoothMouseYCurve" ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) "Binary"

    # USB & MSI Mode Tweaks
    Log "Optimizing USB Controllers (MSI Mode & Power)..."
    $usbControllers = Get-WmiObject Win32_USBController | Where-Object { $_.PNPDeviceID -match "PCI\\VEN_" }
    foreach ($usb in $usbControllers) {
        $pnpId = $usb.PNPDeviceID
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" 1
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\Affinity Policy" "DevicePriority" 0
        
        # Disable USB Power Savings
        $devParams = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters"
        Set-Reg $devParams "AllowIdleIrpInD3" 0
        Set-Reg $devParams "D3ColdSupported" 0
        Set-Reg $devParams "DeviceSelectiveSuspended" 0
        Set-Reg $devParams "EnableSelectiveSuspend" 0
        Set-Reg $devParams "EnhancedPowerManagementEnabled" 0
        Set-Reg $devParams "SelectiveSuspendEnabled" 0
        Set-Reg $devParams "SelectiveSuspendOn" 0
    }
    
    # Button 13: IPv6 & Teredo (Enhanced)
    Log "Disabling Teredo, ISATAP & IPv6 Components..."
    try {
        Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
        netsh int teredo set state disabled
        netsh int ipv6 6to4 set state state=disabled undoonstop=disabled
        netsh int ipv6 isatap set state state=disabled
        netsh int ipv6 set privacy state=disabled
        netsh int ipv6 set global randomizeidentifier=disabled
        netsh int isatap set state disabled
    } catch {
        Log "Error disabling IPv6 components: $_"
    }

    # Button 14: Large System Cache
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 1

    # Button 15: Explorer Serialize (Startup Delay)
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "Startupdelayinmsec" 0

    # Button 16: Explorer Tracking (Frequent/Recent)
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "ShowFrequent" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "ShowRecent" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackDocs" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0

    # Button 17: AutoPlay
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" "DisableAutoplay" 1

    # Button 18: PowerCfg (High Performance)
    if ($UsePowerPlan) {
        Log "Setting High Performance Power Plan..."
        & powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    }

    # Button 19: Bluetooth Radio State (Off)
    Log "Disabling Bluetooth Radio..."
    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
        Function Await($WinRtTask, $ResultType) {
            $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
            $netTask = $asTask.Invoke($null, @($WinRtTask))
            $netTask.Wait(-1) | Out-Null
            $netTask.Result
        }
        [Windows.Devices.Radios.Radio,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
        [Windows.Devices.Radios.RadioAccessStatus,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
        Await ([Windows.Devices.Radios.Radio]::RequestAccessAsync()) ([Windows.Devices.Radios.RadioAccessStatus]) | Out-Null
        $radios = Await ([Windows.Devices.Radios.Radio]::GetRadiosAsync()) ([System.Collections.Generic.IReadOnlyList[Windows.Devices.Radios.Radio]])
        $bluetooth = $radios | Where-Object { $_.Kind -eq 'Bluetooth' }
        if ($bluetooth) {
            Await ($bluetooth.SetStateAsync([Windows.Devices.Radios.RadioState]::Off)) ([Windows.Devices.Radios.RadioAccessStatus]) | Out-Null
        }
    } catch {
        Log "Bluetooth tweak failed (WinRT/Assembly error): $_"
    }

    # Button 20: Firewall & Services
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\mpssvc" "Start" 4
    netsh advfirewall set allprofiles state off
    if ([System.Environment]::OSVersion.Version.Build -ge 22621) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\wtd" "Start" 4
    }

    # Button 21: Game Mode (Enable)
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1

    # Button 22: Game DVR (Disable)
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0

    # Button 23: Background Apps
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BackgroundAppGlobalToggle" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" 2

    # Button 24: Reserve Manager
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" "MiscPolicyInfo" 2
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" "PassedPolicy" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" "ShippedWithReserves" 0

    # Button 25: BCD Tweaks (Dynamic Tick)
    & bcdedit /set disabledynamictick yes
    & bcdedit /set useplatformclock false

    # Button 26: PC Health Check
    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCHC" -Name "PreviousUninstall" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCHealthCheck" -Name "installed" -ErrorAction SilentlyContinue
    } catch {}

    # Button 28: Boot Optimization (Disable Defrag as requested)
    # User requested "Turn off automatic disk defragmentation"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction" "Enable" "N" "String"
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\services\defragsvc" "Start" 4
    try { Disable-ScheduledTask -TaskName "\Microsoft\Windows\Defrag\ScheduledDefrag" -ErrorAction SilentlyContinue } catch {}

    # Firewall Rules: Block Telemetry IPs
    Log "Adding Firewall Rules to block Telemetry..."
    $telemetryIPs = @("20.189.173.20", "20.189.173.21", "20.189.173.22", "20.190.159.0/24", "20.190.160.0/24")
    foreach ($ip in $telemetryIPs) {
        New-NetFirewallRule -DisplayName "Block_Telemetry_$ip" -Direction Outbound -RemoteAddress $ip -Action Block -Enabled True -ErrorAction SilentlyContinue
    }

    # Button 29: Windows Update Pause (10 Years)
    Log "Pausing Windows Updates for 10 Years..."
    $now = [DateTime]::UtcNow
    $start = $now.ToString("yyyy-MM-ddTHH:mm:ssZ")
    $end = $now.AddYears(10).ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions" 1
    
    $uxSettings = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    Set-Reg $uxSettings "PauseFeatureUpdatesStartTime" $start "String"
    Set-Reg $uxSettings "PauseFeatureUpdatesEndTime" $end "String"
    Set-Reg $uxSettings "PauseQualityUpdatesStartTime" $start "String"
    Set-Reg $uxSettings "PauseQualityUpdatesEndTime" $end "String"
    Set-Reg $uxSettings "PauseUpdatesStartTime" $start "String"
    Set-Reg $uxSettings "PauseUpdatesExpiryTime" $end "String"

    $policySettings = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings"
    Set-Reg $policySettings "PausedFeatureStatus" 1
    Set-Reg $policySettings "PausedQualityStatus" 1
    Set-Reg $policySettings "PausedFeatureDate" $start "String"
    Set-Reg $policySettings "PausedQualityDate" $start "String"

    $policyState = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\PolicyState"
    Set-Reg $policyState "IsDeferralIsActive" 1
    Set-Reg $policyState "PolicySources" 1
    Set-Reg $policyState "QualityUpdatesPaused" 1
    Set-Reg $policyState "QualityUpdatePausePeriodInDays" 447
    Set-Reg $policyState "FeatureUpdatesPaused" 1
    Set-Reg $policyState "FeatureUpdatePausePeriodInDays" 447
    Set-Reg $policyState "PauseFeatureUpdatesStartTime" $start "String"
    Set-Reg $policyState "PauseFeatureUpdatesEndTime" $end "String"
    Set-Reg $policyState "PauseQualityUpdatesStartTime" $start "String"
    Set-Reg $policyState "PauseQualityUpdatesEndTime" $end "String"
    
    & gpupdate /force

    # Disable Global Selective Suspend
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\USB" "DisableSelectiveSuspend" 1

    Log "Applying extended system and taskbar policies..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker" "PreventDeviceEncryption" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker" "PreventAutomaticDeviceEncryption" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\FVE" "DisableExternalDMAUnderLock" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LastActiveClick" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" 2
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MMTaskbarMode" 2
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MMTaskbarGlomLevel" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableEdgeDesktopShortcutCreation" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableNotificationCenter" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HidePeopleBar" 1
    if ($DisableSearchIndexing) {
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowIndexingEncryptedStoresOrItems" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableBackoff" 1
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "PreventIndexingOutlook" 1
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\WSearch" "Start" 4
        try {
            Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
            Set-Service -Name "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue
        } catch {}
    }
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "SetAutoRestartNotificationDisable" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DOMaxUploadBandwidth" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "ConfigureWindowsSpotlight" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsSpotlightFeatures" 1
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenOverlayEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "HideFirstRunExperience" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "ShowRecommendationsEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "NewTabPageContentEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "NewTabPageHideDefaultTopSites" 1
    try {
        & powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP STANDBYNETWORK 0
        & powercfg /setdcvalueindex SCHEME_CURRENT SUB_SLEEP STANDBYNETWORK 0
        & powercfg /setactive SCHEME_CURRENT
    } catch {
        Log "Standby network policy update failed: $_"
    }
    if ([Environment]::OSVersion.Version.Build -ge 22000) {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Log "Enabled optional features: Windows Sandbox and WSL"
        } catch {
            Log "Optional feature enablement skipped: $_"
        }
    }

    Log "System Optimizations Applied."
}
Export-ModuleMember -Function Invoke-SystemOptimization
