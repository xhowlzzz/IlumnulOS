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

    # Helper to set registry key safely
    function Set-Reg {
        param($Path, $Name, $Value, $Type = "DWord")
        try {
            $Path = $Path.TrimEnd('\')
            if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
            
            if ([string]::IsNullOrEmpty($Name)) {
                Set-Item -Path $Path -Value $Value -Force -ErrorAction Stop
            } else {
                Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
            }
        } catch {
            if ($_.Exception.Message -match "access is not allowed") {
                # Silently ignore access denied for protected keys
            } else {
                Log "Error setting $Name`: $($_.Exception.Message)"
            }
        }
    }

    # Create Restore Point
    Log "Creating System Restore Point..."
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue 2>&1 | Out-Null
        # Checkpoint-Computer writes warning to host even with ErrorAction SilentlyContinue if frequency limit is hit
        # We redirect the warning stream 3 to $null
        Checkpoint-Computer -Description "System_Optimization" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
    } catch {
        # Suppress all restore point warnings/errors
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
        Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter -ne $null } | ForEach-Object {
            Log "Optimizing Drive $($_.DriveLetter):..."
            Optimize-Volume -DriveLetter $_.DriveLetter -NormalPriority -ErrorAction SilentlyContinue
        }
    } catch {
        Log "Storage optimization failed: $_"
    }

    # BCD Tweaks
    Log "Applying BCD Tweaks..."
    & bcdedit /set useplatformclock No 2>&1 | Out-Null
    & bcdedit /set useplatformtick No 2>&1 | Out-Null
    & bcdedit /set disabledynamictick Yes 2>&1 | Out-Null

    # Mitigations (Spectre/Meltdown) - Left Default for Security
    # Log "Disabling Mitigations..."
    # try {
    #    ForEach ($v in (Get-Command -Name "Set-ProcessMitigation").Parameters["Disable"].Attributes.ValidValues) {
    #         Set-ProcessMitigation -System -Disable $v.ToString() -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
    #    }
    # } catch {}
    
    # VBS (Virtualization Based Security) - ENABLED as requested
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" "EnableVirtualizationBasedSecurity" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" "HVCIMATRequired" 1
    
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DisableExceptionChainValidation" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "KernelSEHOPEnabled" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "EnableCfg" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "ProtectionMode" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettings" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 3
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" 3
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "MitigationOptions" ([byte[]](0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22)) "Binary"

    # NTFS Tweaks
    Log "Applying NTFS Tweaks..."
    & fsutil behavior set memoryusage 2 2>&1 | Out-Null
    & fsutil behavior set mftzone 4 2>&1 | Out-Null
    & fsutil behavior set disablelastaccess 1 2>&1 | Out-Null
    & fsutil behavior set disabledeletenotify 0 2>&1 | Out-Null
    & fsutil behavior set encryptpagingfile 0 2>&1 | Out-Null

    # Disable Memory Compression & Page Combining
    Log "Disabling Memory Compression..."
    # Disable-MMAgent requires SysMain to be running. We check later in the script.
    # Removed unsafe direct calls to prevent service errors.

    # Win32Priority
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38

    # Large System Cache
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 1

    # Manual Memory Pool & Cache Tuning
    Log "Tuning Memory Pools & System Cache..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PoolUsageMaximum" 60
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "SystemPages" 0xFFFFFFFF
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "IoPageLockLimit" 16777216 # Optimized for 16GB+
    
    # Disable Memory Compression (MM Agent)
    Log "Disabling Memory Compression..."
    try {
        if (Get-Service "SysMain" -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq 'Running'}) {
             & Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}

    # Large Page Support
    Log "Enabling Large Page Support..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargePageMinimum" 0xFFFFFFFF
    
    # System Cache Dirty Page Tuning (Prevents micro-stutters)
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "SystemCacheDirtyPageThreshold" 512
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "SystemCacheDirtyPageTarget" 256

    # Windows Search Indexer Deep Disable
    Log "Aggressively Disabling Search Indexer..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowIndexingEncryptedStoresOrItems" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableBackoff" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\WSearch" "Start" 4
    try {
        Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        # Delete Index files (aggressive)
        $indexPath = "C:\ProgramData\Microsoft\Search\Data\Applications\Windows"
        if (Test-Path $indexPath) { Remove-Item -Path "$indexPath\*" -Recurse -Force -ErrorAction SilentlyContinue }
    } catch {}

    # Ultimate Performance Power Plan
    Log "Activating Ultimate Performance Power Plan..."
    try {
        # Duplicate the Ultimate Performance scheme (e9a42b02-d5df-448d-aa00-03f14749eb61)
        $ultimateScheme = & powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
        if ($ultimateScheme -match '([a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12})') {
            $schemeGuid = $matches[0]
            & powercfg -setactive $schemeGuid | Out-Null
            Log " [OK] Ultimate Performance Plan Activated ($schemeGuid)"
        } else {
            # Fallback to High Performance if Ultimate is not available
            & powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
            Log " [INFO] Fallback to High Performance Plan."
        }
        
        # Ensure Hibernate is OFF (Powercfg)
        & powercfg -h off 2>&1 | Out-Null
    } catch {
        Log " [!] Failed to set Power Plan: $_"
    }

    # Disable Display Power Saving (DPST) - Common on Laptops/Modern Monitors
    Log "Disabling Display Power Saving (DPST)..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" "FeatureTestControl" 0x9240
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0001" "FeatureTestControl" 0x9240

    # Visual Effects -> Best Performance
    Log "Optimizing Visual Effects for Performance..."
    # Disable Transparency
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0
    # Disable Animations
    Set-Reg "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) "Binary"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2 # Adjust for best performance

    # NTFS 8dot3NameCreation & LastAccess (Enhanced)
    Log "Applying Advanced NTFS Tweaks..."
    & fsutil 8dot3name set 1 2>&1 | Out-Null
    & fsutil behavior set disablelastaccess 1 2>&1 | Out-Null

    # Disable Fast Startup & Hibernation
    if ($DisableHibernation) {
        Log "Disabling Hibernation..."
        & powercfg /h off 2>&1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 0
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "SleepReliabilityDetailedDiagnostics" 0
    }

    # Disable Sleep Study
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "SleepStudyDisabled" 1

    # DEP (Data Execution Prevention) - Enabled (Default)
    # Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" "DEPOff" 1

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
        & bcdedit /set disabledynamictick yes | Out-Null
    } catch {
        Log "Failed to apply Dynamic Ticking tweak"
    }

    # Disable ASLR
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "MoveImages" 0

    # Disable Power Throttling
    Log "Disabling Power Throttling..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "CoalescingTimerInterval" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "CoalescingTimerInterval" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "CoalescingTimerInterval" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "CoalescingTimerInterval" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Executive" "CoalescingTimerInterval" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\ModernSleep" "CoalescingTimerInterval" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "CoalescingTimerInterval" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "PlatformAoAcOverride" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "EnergyEstimationEnabled" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "EventProcessorEnabled" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "CsEnabled" 0

    # Distribute Timers & Timestamp
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DistributeTimers" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability" "TimeStampInterval" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability" "IoPriority" 3

    # MenuShowDelay
    Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" 0

    # Disable Energy Logging
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy" "DisableTaggedEnergyLogging" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy" "TelemetryMaxApplication" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy" "TelemetryMaxTagPerApplication" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\GpuEnergyDrv" "Start" 4
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\GpuEnergyDr" "Start" 4

    # Service Priorities (Kernel, DWM, etc.)
    Log "Setting Service Priorities..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System" "PassiveIntRealTimeWorkerPriority" 18
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\KernelVelocity" "DisableFGBoostDecay" 1
    
    # Image File Execution Options (CpuPriorityClass / IoPriority / PagePriority)
    $services = @(
        @{Name="dwm.exe"; Cpu=4; Io=3; Page=$null},
        @{Name="lsass.exe"; Cpu=1; Io=0; Page=0},
        @{Name="ntoskrnl.exe"; Cpu=4; Io=3; Page=$null},
        @{Name="SearchIndexer.exe"; Cpu=1; Io=0; Page=$null},
        @{Name="svchost.exe"; Cpu=1; Io=$null; Page=$null},
        @{Name="TrustedInstaller.exe"; Cpu=1; Io=0; Page=$null},
        @{Name="wuauclt.exe"; Cpu=1; Io=0; Page=$null},
        @{Name="audiodg.exe"; Cpu=2; Io=$null; Page=$null},
        @{Name="csrss.exe"; Cpu=4; Io=3; Page=$null}
    )
    
    foreach ($svc in $services) {
        $exe = $svc.Name
        # Set for 64-bit
        if ($svc.Cpu -ne $null) { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" "CpuPriorityClass" $svc.Cpu }
        if ($svc.Io -ne $null) { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" "IoPriority" $svc.Io }
        if ($svc.Page -ne $null) { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" "PagePriority" $svc.Page }
        
        # Set for WOW6432Node (32-bit compatibility)
        if ($svc.Cpu -ne $null) { Set-Reg "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" "CpuPriorityClass" $svc.Cpu }
        if ($svc.Io -ne $null) { Set-Reg "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" "IoPriority" $svc.Io }
        if ($svc.Page -ne $null) { Set-Reg "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" "PagePriority" $svc.Page }
    }

    # PCI Express Power Management (Link State Power Management - Off)
    Log "Setting PCIe Power Management to Off (Max Performance)..."
    try {
        # Using GUIDs for better compatibility
        # Subgroup: 501a1069-1b6d-4610-99e4-801be973c962 (PCI Express)
        # Setting:  ee2a9642-7819-4592-9508-cf2d47a2d45a (Link State Power Management)
        # Value: 0 (Off)
        & powercfg /setacvalueindex SCHEME_CURRENT 501a1069-1b6d-4610-99e4-801be973c962 ee2a9642-7819-4592-9508-cf2d47a2d45a 0 2>&1 | Out-Null
        & powercfg /setdcvalueindex SCHEME_CURRENT 501a1069-1b6d-4610-99e4-801be973c962 ee2a9642-7819-4592-9508-cf2d47a2d45a 0 2>&1 | Out-Null
        & powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
    } catch {
        Log "PCIe Power tweak failed (maybe not supported): $($_.Exception.Message)"
    }

    # Clean Windows Update Cache (SoftwareDistribution / Catroot2)
    Log "Cleaning Windows Update Cache..."
    try {
        Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        Stop-Service -Name "cryptSvc" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        Stop-Service -Name "bits" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        Stop-Service -Name "msiserver" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        
        Remove-Item -Path "C:\Windows\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Windows\System32\catroot2" -Recurse -Force -ErrorAction SilentlyContinue
        
        Start-Service -Name "cryptSvc" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        Start-Service -Name "bits" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        Start-Service -Name "msiserver" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        # wuauserv left stopped/manual per previous tweak
    } catch {
        Log "Windows Update cleanup failed: $_"
    }

    # Disable Windows Updates (Partial - Pause/Disable Auto Update)
    Log "Disabling Windows Auto Updates..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions" 2
    try {
        Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        # We don't disable wuauserv completely as it breaks Store, but we stop it and set to Manual
        Set-Service -Name "wuauserv" -StartupType Manual -ErrorAction SilentlyContinue
    } catch {}

    # Disable Network Protocols (IPv6, Teredo, ISATAP)
    Log "Disabling Unnecessary Network Protocols..."
    try {
        Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue | Out-Null
        netsh interface teredo set state disabled 2>&1 | Out-Null
        netsh interface isatap set state disabled 2>&1 | Out-Null
        netsh interface 6to4 set state disabled 2>&1 | Out-Null
    } catch {
        Log "Network protocol tweak failed: $_"
    }

    # Disable Diagnostic Tools & Defrag
    Log "Disabling Diagnostic Tools..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" "Enabled" 0
    try {
        Disable-ScheduledTask -TaskName "\Microsoft\Windows\Defrag\ScheduledDefrag" -ErrorAction SilentlyContinue | Out-Null
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
        # Fix: Add -ErrorAction SilentlyContinue to skip restricted keys
        Get-ChildItem $realtekKey -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                if ($_.Property -contains "PowerSettings") {
                    $key = $_.PSPath
                    Set-Reg "$key\PowerSettings" "ConservationIdleTime" ([byte[]](0x00,0x00,0x00,0x00)) "Binary"
                    Set-Reg "$key\PowerSettings" "IdlePowerState" ([byte[]](0x00,0x00,0x00,0x00)) "Binary"
                    Set-Reg "$key\PowerSettings" "PerformanceIdleTime" ([byte[]](0x00,0x00,0x00,0x00)) "Binary"
                }
            } catch {}
        }
    }

    # NTFS Compression (CompactOS)
    Log "Applying CompactOS Compression..."
    try {
        compact.exe /CompactOS:always 2>&1 | Out-Null
    } catch {
        Log "CompactOS failed: $_"
    }

    # Disable Windows Defender (Partial / Registry based)
    Log "Disabling Windows Defender..."
    try {
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue | Out-Null
        Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue | Out-Null
    } catch {}
    
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiSpyware" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableRealtimeMonitoring" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" "SpynetReporting" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" "ConfigureAppInstallControlEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" "DisableEnhancedNotifications" 1
    
    # Windows Defender (Advanced Disabling)
    Log "Disabling Windows Defender Advanced..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" "DisableGenericReports" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" "LocalSettingOverrideSpynetReporting" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" "SpynetReporting" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" "SubmitSamplesConsent" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" "ConfigureAppInstallControlEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Threats" "Threats_ThreatSeverityDefaultAction" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Threats\ThreatSeverityDefaultAction" "1" "6" "String"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Threats\ThreatSeverityDefaultAction" "2" "6" "String"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Threats\ThreatSeverityDefaultAction" "4" "6" "String"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Threats\ThreatSeverityDefaultAction" "5" "6" "String"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\UX Configuration" "Notification_Suppress" 1
    
    # Disable Defender Services
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Sense" "Start" 4
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\WdNisSvc" "Start" 4
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend" "Start" 4
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\SecurityHealthService" "Start" 4
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\wscsvc" "Start" 4
    
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiSpyware" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableRoutinelyTakingAction" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "ServiceKeepAlive" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableBehaviorMonitoring" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableIOAVProtection" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableOnAccessProtection" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableRealtimeMonitoring" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" "DisableEnhancedNotifications" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" "DisableNotifications" 1
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" "NoToastApplicationNotification" 1
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" "NoToastApplicationNotificationOnLockScreen" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\MsMpEng.exe\PerfOptions" "CpuPriorityClass" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\MsMpEngCP.exe\PerfOptions" "CpuPriorityClass" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\MRT" "DontReportInfectionInformation" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableSmartScreen" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" "EnabledV9" 0

    # Enable Full Screen Optimizations (FSO)
    Log "Enabling Full Screen Optimizations..."
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_DSEBehavior" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_FSEBehaviorMode" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_EFSEFeatureFlags" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_DXGIHonorFSEWindowsCompatible" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode" 1

    # Advanced Latency & Power Management
    Log "Setting Advanced Latency Tolerance..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl" "MonitorLatencyTolerance" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl" "MonitorRefreshLatencyTolerance" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "ExitLatency" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "ExitLatencyCheckEnabled" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "Latency" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "LatencyToleranceDefault" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "LatencyToleranceFSVP" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "LatencyTolerancePerfOverride" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "LatencyToleranceScreenOffIR" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "LatencyToleranceVSyncEnabled" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "RtlCapabilityCheckLatency" 1
    
    $gfxPower = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"
    Set-Reg $gfxPower "DefaultD3TransitionLatencyActivelyUsed" 1
    Set-Reg $gfxPower "DefaultD3TransitionLatencyIdleLongTime" 1
    Set-Reg $gfxPower "DefaultD3TransitionLatencyIdleMonitorOff" 1
    Set-Reg $gfxPower "DefaultD3TransitionLatencyIdleNoContext" 1
    Set-Reg $gfxPower "DefaultD3TransitionLatencyIdleShortTime" 1
    Set-Reg $gfxPower "DefaultD3TransitionLatencyIdleVeryLongTime" 1
    Set-Reg $gfxPower "DefaultLatencyToleranceIdle0" 1
    Set-Reg $gfxPower "DefaultLatencyToleranceIdle0MonitorOff" 1
    Set-Reg $gfxPower "DefaultLatencyToleranceIdle1" 1
    Set-Reg $gfxPower "DefaultLatencyToleranceIdle1MonitorOff" 1
    Set-Reg $gfxPower "DefaultLatencyToleranceMemory" 1
    Set-Reg $gfxPower "DefaultLatencyToleranceNoContext" 1
    Set-Reg $gfxPower "DefaultLatencyToleranceNoContextMonitorOff" 1
    Set-Reg $gfxPower "DefaultLatencyToleranceOther" 1
    Set-Reg $gfxPower "DefaultLatencyToleranceTimerPeriod" 1
    Set-Reg $gfxPower "DefaultMemoryRefreshLatencyToleranceActivelyUsed" 1
    Set-Reg $gfxPower "DefaultMemoryRefreshLatencyToleranceMonitorOff" 1
    Set-Reg $gfxPower "DefaultMemoryRefreshLatencyToleranceNoContext" 1
    Set-Reg $gfxPower "Latency" 1
    Set-Reg $gfxPower "MaxIAverageGraphicsLatencyInOneBucket" 1
    Set-Reg $gfxPower "MiracastPerfTrackGraphicsLatency" 1
    Set-Reg $gfxPower "MonitorLatencyTolerance" 1
    Set-Reg $gfxPower "MonitorRefreshLatencyTolerance" 1
    Set-Reg $gfxPower "TransitionLatency" 1
    
    # Resource Policy Values
    Log "Setting Resource Policy Store Values..."
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\HardCap0" "CapPercentage" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\HardCap0" "SchedulingType" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\Paused" "CapPercentage" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\Paused" "SchedulingType" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\SoftCapFull" "CapPercentage" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\SoftCapFull" "SchedulingType" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\SoftCapLow" "CapPercentage" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\SoftCapLow" "SchedulingType" 0
    
    # Flags & Importance
    $flags = @("BackgroundDefault", "Frozen", "FrozenDNCS", "FrozenDNK", "FrozenPPLE", "Paused", "PausedDNK", "Pausing", "PrelaunchForeground", "ThrottleGPUInterference")
    foreach ($flag in $flags) {
        Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Flags\$flag" "IsLowPriority" 0
    }
    
    $importanceLevels = @("Critical", "CriticalNoUi", "EmptyHostPPLE", "High", "Low", "Lowest", "Medium", "MediumHigh", "StartHost", "VeryHigh", "VeryLow")
    foreach ($level in $importanceLevels) {
        Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\$level" "BasePriority" 82
        Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\$level" "OverTargetPriority" 50
    }
    
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
        Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue | Out-Null
        netsh int teredo set state disabled 2>&1 | Out-Null
        netsh int ipv6 6to4 set state state=disabled undoonstop=disabled 2>&1 | Out-Null
        netsh int ipv6 isatap set state state=disabled 2>&1 | Out-Null
        netsh int ipv6 set privacy state=disabled 2>&1 | Out-Null
        netsh int ipv6 set global randomizeidentifier=disabled 2>&1 | Out-Null
        netsh int isatap set state disabled 2>&1 | Out-Null
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
        try {
            # Check if High Performance plan exists
            $plans = & powercfg /list
            if ($plans -match "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c") {
                & powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
            } else {
                # Fallback: Duplicate and set if missing
                & powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
                & powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
            }
        } catch {
            Log "Failed to set High Performance power plan: $($_.Exception.Message)"
        }
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
    netsh advfirewall set allprofiles state off 2>&1 | Out-Null
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
    & bcdedit /set disabledynamictick yes 2>&1 | Out-Null
    & bcdedit /set useplatformclock false 2>&1 | Out-Null

    # Button 26: PC Health Check
    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCHC" -Name "PreviousUninstall" -ErrorAction SilentlyContinue | Out-Null
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCHealthCheck" -Name "installed" -ErrorAction SilentlyContinue | Out-Null
    } catch {}

    # Button 28: Boot Optimization (Disable Defrag as requested)
    # User requested "Turn off automatic disk defragmentation"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction" "Enable" "N" "String"
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\services\defragsvc" "Start" 4
    try { Disable-ScheduledTask -TaskName "\Microsoft\Windows\Defrag\ScheduledDefrag" -ErrorAction SilentlyContinue | Out-Null } catch {}

    # Firewall Rules: Block Telemetry IPs
    Log "Adding Firewall Rules to block Telemetry..."
    $telemetryIPs = @("20.189.173.20", "20.189.173.21", "20.189.173.22", "20.190.159.0/24", "20.190.160.0/24")
    foreach ($ip in $telemetryIPs) {
        New-NetFirewallRule -DisplayName "Block_Telemetry_$ip" -Direction Outbound -RemoteAddress $ip -Action Block -Enabled True -ErrorAction SilentlyContinue | Out-Null
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
    Set-Reg $policyState "IsDeferralActive" 1
    Set-Reg $policyState "PolicySources" 1
    Set-Reg $policyState "QualityUpdatesPaused" 1
    Set-Reg $policyState "QualityUpdatePausePeriodInDays" 447
    Set-Reg $policyState "FeatureUpdatesPaused" 1
    Set-Reg $policyState "FeatureUpdatePausePeriodInDays" 447
    Set-Reg $policyState "PauseFeatureUpdatesStartTime" $start "String"
    Set-Reg $policyState "PauseFeatureUpdatesEndTime" $end "String"
    Set-Reg $policyState "PauseQualityUpdatesStartTime" $start "String"
    Set-Reg $policyState "PauseQualityUpdatesEndTime" $end "String"
    
    & gpupdate /force | Out-Null

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
            Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
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
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RemediationRequired" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SoftLandingEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "PreInstalledAppsEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "OemPreInstalledAppsEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "ContentDeliveryAllowed" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContentEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "PreInstalledAppsEverEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-314559Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-280815Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-314563Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338393Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353694Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353696Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-310093Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-202914Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338387Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353698Enabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "HideFirstRunExperience" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "ShowRecommendationsEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "NewTabPageContentEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "NewTabPageHideDefaultTopSites" 1

    # Windows Insider & Privacy Extensions
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System" "AllowExperimentation" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\System\AllowExperimentation" "value" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" "CdpSessionUserAuthzPolicy" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" "NearShareChannelUserAuthzPolicy" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "TelemetrySalt" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoRecentDocsHistory" 1
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "HistoryViewEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "DeviceHistoryEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
    
    # Notifications
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK" 0
    
    # Capability Access Manager (Privacy)
    $capStore = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore"
    $denyList = @("activity","appDiagnostics","appointments","bluetoothSync","broadFileSystemAccess","cellularData","chat","contacts","documentsLibrary","email","gazeInput","location","phoneCall","phoneCallHistory","picturesLibrary","radios","userAccountInformation","userDataTasks","userNotificationListener","videosLibrary")
    foreach ($cap in $denyList) {
        Set-Reg "$capStore\$cap" "Value" "Deny" "String"
    }
    Set-Reg "$capStore\microphone" "Value" "Allow" "String"
    Set-Reg "$capStore\webcam" "Value" "Allow" "String"
    try {
        # Using GUIDs for better compatibility
        # Subgroup: 238c9fa8-0aad-41ed-83f4-97be242c8d20 (Sleep)
        # Setting:  d4c8d97d-4807-41b5-90b9-3557568117ca (Networking connectivity in Standby)
        & powercfg /setacvalueindex SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8d20 d4c8d97d-4807-41b5-90b9-3557568117ca 0 2>&1 | Out-Null
        & powercfg /setdcvalueindex SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8d20 d4c8d97d-4807-41b5-90b9-3557568117ca 0 2>&1 | Out-Null
        & powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
    } catch {
        Log "Standby network policy update failed: $($_.Exception.Message)"
    }
    if ([Environment]::OSVersion.Version.Build -ge 22000) {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All -NoRestart -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
            Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -All -NoRestart -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
            Log "Enabled optional features: Windows Sandbox and WSL"
        } catch {
            Log "Optional feature enablement skipped: $_"
        }
    }

    Log "System Optimizations Applied."
}
Export-ModuleMember -Function Invoke-SystemOptimization
