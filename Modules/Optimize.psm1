function Invoke-SystemOptimization {
    param(
        [Action[string]]$Logger,
        [hashtable]$Options = @{}
    )
    
    function Log($msg) { if ($Logger) { $Logger.Invoke($msg) } else { Write-Host $msg } }

    Log "Starting System Optimizations..."
    
    if (!(Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
    }

    $UsePowerPlan = if ($Options.ContainsKey("PowerPlan")) { [bool]$Options.PowerPlan } else { $true }
    $DisableHibernation = if ($Options.ContainsKey("DisableHibernation")) { [bool]$Options.DisableHibernation } else { $true }
    $DisableSearchIndexing = if ($Options.ContainsKey("DisableSearchIndexing")) { [bool]$Options.DisableSearchIndexing } else { $false }
    $TuneVisualEffects = if ($Options.ContainsKey("VisualEffects")) { [bool]$Options.VisualEffects } else { $true }

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
            } else {
                Log "Error setting $Name`: $($_.Exception.Message)"
            }
        }
    }

    Log "Creating System Restore Point..."
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue 2>&1 | Out-Null
        Checkpoint-Computer -Description "System_Optimization" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
    } catch {
    }

    if ($TuneVisualEffects) {
        Log "Optimizing Visual Effects for Performance..."
        Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
        Set-Reg "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) "Binary"
        Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" "String"
    }

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

    Log "Optimizing Storage Drives..."
    try {
        Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter -ne $null } | ForEach-Object {
            Log "Optimizing Drive $($_.DriveLetter):..."
            Optimize-Volume -DriveLetter $_.DriveLetter -NormalPriority -ErrorAction SilentlyContinue
        }
    } catch {
        Log "Storage optimization failed: $_"
    }

    Log "Applying BCD Tweaks..."
    & bcdedit /set useplatformclock No 2>&1 | Out-Null
    & bcdedit /set useplatformtick No 2>&1 | Out-Null
    & bcdedit /set disabledynamictick Yes 2>&1 | Out-Null

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

    Log "Applying NTFS Tweaks..."
    & fsutil behavior set memoryusage 2 2>&1 | Out-Null
    & fsutil behavior set mftzone 4 2>&1 | Out-Null
    & fsutil behavior set disablelastaccess 1 2>&1 | Out-Null
    & fsutil behavior set disabledeletenotify 0 2>&1 | Out-Null
    & fsutil behavior set encryptpagingfile 0 2>&1 | Out-Null

    Log "Disabling Memory Compression..."

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 1

    Log "Tuning Memory Pools & System Cache..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PoolUsageMaximum" 60
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "SystemPages" 0xFFFFFFFF
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "IoPageLockLimit" 16777216 # Optimized for 16GB+
    
    Log "Disabling Memory Compression..."
    try {
        if (Get-Service "SysMain" -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq 'Running'}) {
             & Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}

    Log "Enabling Large Page Support..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargePageMinimum" 0xFFFFFFFF
    
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "SystemCacheDirtyPageThreshold" 512
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "SystemCacheDirtyPageTarget" 256

    Log "Aggressively Disabling Search Indexer..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowIndexingEncryptedStoresOrItems" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableBackoff" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\WSearch" "Start" 4
    try {
        Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        $indexPath = "C:\ProgramData\Microsoft\Search\Data\Applications\Windows"
        if (Test-Path $indexPath) { Remove-Item -Path "$indexPath\*" -Recurse -Force -ErrorAction SilentlyContinue }
    } catch {}

    Log "Activating Ultimate Performance Power Plan..."
    try {
        $ultimateScheme = & powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
        if ($ultimateScheme -match '([a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12})') {
            $schemeGuid = $matches[0]
            & powercfg -setactive $schemeGuid | Out-Null
            Log " [OK] Ultimate Performance Plan Activated ($schemeGuid)"
        } else {
            & powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
            Log " [INFO] Fallback to High Performance Plan."
        }
        
        & powercfg -h off 2>&1 | Out-Null
    } catch {
        Log " [!] Failed to set Power Plan: $_"
    }

    Log "Disabling Display Power Saving (DPST)..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" "FeatureTestControl" 0x9240
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0001" "FeatureTestControl" 0x9240

    Log "Optimizing Visual Effects for Performance..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0
    Set-Reg "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) "Binary"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2 # Adjust for best performance

    Log "Applying Advanced NTFS Tweaks..."
    & fsutil 8dot3name set 1 2>&1 | Out-Null
    & fsutil behavior set disablelastaccess 1 2>&1 | Out-Null

    if ($DisableHibernation) {
        Log "Disabling Hibernation..."
        & powercfg /h off 2>&1 | Out-Null
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 0
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "SleepReliabilityDetailedDiagnostics" 0
    }

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "SleepStudyDisabled" 1

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" "MaintenanceDisabled" 1

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 1

    Set-Reg "HKLM:\SOFTWARE\Microsoft\FTH" "Enabled" 0

    try {
        $MemoryKB = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1KB
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control" "SvcHostSplitThresholdInKB" ([int]$MemoryKB)
    } catch {
        Log "Failed to set SvcHostSplitThreshold: $_"
    }

    try {
        & bcdedit /set disabledynamictick yes | Out-Null
    } catch {
        Log "Failed to apply Dynamic Ticking tweak"
    }

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "MoveImages" 0

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

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DistributeTimers" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability" "TimeStampInterval" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability" "IoPriority" 3

    Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" 0

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy" "DisableTaggedEnergyLogging" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy" "TelemetryMaxApplication" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy" "TelemetryMaxTagPerApplication" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\GpuEnergyDrv" "Start" 4
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\GpuEnergyDr" "Start" 4

    Log "Setting Service Priorities..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System" "PassiveIntRealTimeWorkerPriority" 18
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\KernelVelocity" "DisableFGBoostDecay" 1
    
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
        if ($svc.Cpu -ne $null) { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" "CpuPriorityClass" $svc.Cpu }
        if ($svc.Io -ne $null) { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" "IoPriority" $svc.Io }
        if ($svc.Page -ne $null) { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" "PagePriority" $svc.Page }
        
        if ($svc.Cpu -ne $null) { Set-Reg "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" "CpuPriorityClass" $svc.Cpu }
        if ($svc.Io -ne $null) { Set-Reg "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" "IoPriority" $svc.Io }
        if ($svc.Page -ne $null) { Set-Reg "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" "PagePriority" $svc.Page }
    }

    Log "Setting PCIe Power Management to Off (Max Performance)..."
    try {
        & powercfg /setacvalueindex SCHEME_CURRENT 501a1069-1b6d-4610-99e4-801be973c962 ee2a9642-7819-4592-9508-cf2d47a2d45a 0 2>&1 | Out-Null
        & powercfg /setdcvalueindex SCHEME_CURRENT 501a1069-1b6d-4610-99e4-801be973c962 ee2a9642-7819-4592-9508-cf2d47a2d45a 0 2>&1 | Out-Null
        & powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
    } catch {
        Log "PCIe Power tweak failed (maybe not supported): $($_.Exception.Message)"
    }

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
    } catch {
        Log "Windows Update cleanup failed: $_"
    }

    Log "Disabling Windows Auto Updates..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions" 2
    try {
        Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        Set-Service -Name "wuauserv" -StartupType Manual -ErrorAction SilentlyContinue
    } catch {}

    Log "Disabling Unnecessary Network Protocols..."
    try {
        Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue | Out-Null
        netsh interface teredo set state disabled 2>&1 | Out-Null
        netsh interface isatap set state disabled 2>&1 | Out-Null
        netsh interface 6to4 set state disabled 2>&1 | Out-Null
    } catch {
        Log "Network protocol tweak failed: $_"
    }

    Log "Disabling Diagnostic Tools..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" "Enabled" 0
    try {
        Disable-ScheduledTask -TaskName "\Microsoft\Windows\Defrag\ScheduledDefrag" -ErrorAction SilentlyContinue | Out-Null
    } catch {}

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

    Log "Optimizing Realtek Audio Power..."
    $realtekKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}"
    if (Test-Path $realtekKey) {
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

    Log "Applying CompactOS Compression..."
    try {
        compact.exe /CompactOS:always 2>&1 | Out-Null
    } catch {
        Log "CompactOS failed: $_"
    }

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

    Log "Enabling Full Screen Optimizations..."
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_DSEBehavior" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_FSEBehaviorMode" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_EFSEFeatureFlags" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_DXGIHonorFSEWindowsCompatible" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode" 1

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
    
    Log "Setting Resource Policy Store Values..."
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\HardCap0" "CapPercentage" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\HardCap0" "SchedulingType" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\Paused" "CapPercentage" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\Paused" "SchedulingType" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\SoftCapFull" "CapPercentage" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\SoftCapFull" "SchedulingType" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\SoftCapLow" "CapPercentage" 0
    Set-Reg "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\SoftCapLow" "SchedulingType" 0
    
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

    Log "Disabling Sticky/Filter/Toggle Keys..."
    Set-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506" "String"
    Set-Reg "HKCU:\Control Panel\Accessibility\Keyboard Response" "Flags" "122" "String"
    Set-Reg "HKCU:\Control Panel\Accessibility\ToggleKeys" "Flags" "58" "String"

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
    
    Set-Reg "HKCU:\Control Panel\Mouse" "SmoothMouseXCurve" ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) "Binary"
    Set-Reg "HKCU:\Control Panel\Mouse" "SmoothMouseYCurve" ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) "Binary"

    Log "Optimizing USB Controllers (MSI Mode & Power)..."
    $usbControllers = Get-WmiObject Win32_USBController | Where-Object { $_.PNPDeviceID -match "PCI\\VEN_" }
    foreach ($usb in $usbControllers) {
        $pnpId = $usb.PNPDeviceID
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" 1
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\Affinity Policy" "DevicePriority" 0
        
        $devParams = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters"
        Set-Reg $devParams "AllowIdleIrpInD3" 0
        Set-Reg $devParams "D3ColdSupported" 0
        Set-Reg $devParams "DeviceSelectiveSuspended" 0
        Set-Reg $devParams "EnableSelectiveSuspend" 0
        Set-Reg $devParams "EnhancedPowerManagementEnabled" 0
        Set-Reg $devParams "SelectiveSuspendEnabled" 0
        Set-Reg $devParams "SelectiveSuspendOn" 0
    }
    
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

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 1

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "Startupdelayinmsec" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "ShowFrequent" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "ShowRecent" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackDocs" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" "DisableAutoplay" 1

    if ($UsePowerPlan) {
        Log "Setting Ultimate Performance Power Plan..."
        try {
            $ultimateScheme = & powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
            if ($ultimateScheme -match '([a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12})') {
                $schemeGuid = $matches[0]
                & powercfg -setactive $schemeGuid | Out-Null
                Log " [OK] Ultimate Performance Plan Activated ($schemeGuid)"
            } else {
                & powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
                Log " [INFO] Fallback to High Performance Plan."
            }
        } catch {
            Log "Failed to set Power Plan: $($_.Exception.Message)"
        }
    }

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

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\mpssvc" "Start" 4
    netsh advfirewall set allprofiles state off 2>&1 | Out-Null
    if ([System.Environment]::OSVersion.Version.Build -ge 22621) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\wtd" "Start" 4
    }

    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BackgroundAppGlobalToggle" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" 2

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" "MiscPolicyInfo" 2
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" "PassedPolicy" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" "ShippedWithReserves" 0

    & bcdedit /set disabledynamictick yes 2>&1 | Out-Null
    & bcdedit /set useplatformclock false 2>&1 | Out-Null

    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCHC" -Name "PreviousUninstall" -ErrorAction SilentlyContinue | Out-Null
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCHealthCheck" -Name "installed" -ErrorAction SilentlyContinue | Out-Null
    } catch {}

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction" "Enable" "N" "String"
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\services\defragsvc" "Start" 4
    try { Disable-ScheduledTask -TaskName "\Microsoft\Windows\Defrag\ScheduledDefrag" -ErrorAction SilentlyContinue | Out-Null } catch {}

    Log "Adding Firewall Rules to block Telemetry..."
    $telemetryIPs = @("20.189.173.20", "20.189.173.21", "20.189.173.22", "20.190.159.0/24", "20.190.160.0/24")
    foreach ($ip in $telemetryIPs) {
        New-NetFirewallRule -DisplayName "Block_Telemetry_$ip" -Direction Outbound -RemoteAddress $ip -Action Block -Enabled True -ErrorAction SilentlyContinue | Out-Null
    }

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

    Set-Reg "HKU:\.Default\Control Panel\Keyboard" "InitialKeyboardIndicators" 2
    Set-Reg "HKCU:\Control Panel\Keyboard" "InitialKeyboardIndicators" 2

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisplayParameters" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisableEmoticon" 1

    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9" "ACSettingIndex" 0

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "PlatformAoAcOverride" 0

    Log "Disabling Explorer Folder Discovery..."
    try {
        Remove-Item -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU" -Recurse -Force -ErrorAction SilentlyContinue
        $allFolders = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell"
        if (!(Test-Path $allFolders)) { New-Item -Path $allFolders -Force | Out-Null }
        Set-ItemProperty -Path $allFolders -Name "FolderType" -Value "NotSpecified" -PropertyType String -Force
    } catch {}

    Log "Setting Services to Manual (Optimization)..."
    $manualServices = @(
        "ALG", "AppMgmt", "AppReadiness", "Appinfo", "AxInstSV", "BDESVC", "BTAGService", 
        "CDPSvc", "COMSysApp", "CertPropSvc", "CscService", "DevQueryBroker", "DeviceAssociationService", 
        "DeviceInstall", "DisplayEnhancementService", "EFS", "EapHost", "FDResPub", "FrameServer", 
        "FrameServerMonitor", "GraphicsPerfSvc", "HvHost", "IKEEXT", "InstallService", "InventorySvc", 
        "IpxlatCfgSvc", "KtmRm", "LicenseManager", "LxpSvc", "MSDTC", "MSiSCSI", "McpManagementService", 
        "MicrosoftEdgeElevationService", "NaturalAuthentication", "NcaSvc", "NcbService", "NcdAutoSetup", 
        "NetSetupSvc", "Netman", "NlaSvc", "PcaSvc", "PeerDistSvc", "PerfHost", "PhoneSvc", "PlugPlay", 
        "PolicyAgent", "PrintNotify", "PushToInstall", "QWAVE", "RasAuto", "RasMan", "RetailDemo", 
        "RmSvc", "RpcLocator", "SCPolicySvc", "SCardSvr", "SDRSVC", "SEMgrSvc", "SNMPTRAP", "SNMPTrap", 
        "SSDPSRV", "ScDeviceEnum", "SensorDataService", "SensorService", "SensrSvc", "SessionEnv", 
        "SharedAccess", "SmsRouter", "SstpSvc", "StiSvc", "StorSvc", "TapiSrv", "TermService", 
        "TieringEngineService", "TokenBroker", "TroubleshootingSvc", "TrustedInstaller", "UmRdpService", 
        "UsoSvc", "VSS", "VaultSvc", "W32Time", "WEPHOSTSVC", "WFDSConMgrSvc", "WMPNetworkSvc", 
        "WManSvc", "WPDBusEnum", "WSAIFabricSvc", "WalletService", "WarpJITSvc", "WbioSrvc", 
        "WdiServiceHost", "WdiSystemHost", "WebClient", "Wecsvc", "WerSvc", "WiaRpc", "WinRM", 
        "WpcMonSvc", "WpnService", "XblAuthManager", "XblGameSave", "XboxGipSvc", "XboxNetApiSvc", 
        "autotimesvc", "bthserv", "camsvc", "cloudidsvc", "dcsvc", "defragsvc", "diagsvc", 
        "dmwappushservice", "dot3svc", "edgeupdate", "edgeupdatem", "fdPHost", "fhsvc", "hidserv", 
        "icssvc", "lfsvc", "lltdsvc", "lmhosts", "netprofm", "perceptionsimulation", "pla", "seclogon", 
        "smphost", "svsvc", "swprv", "upnphost", "vds", "vmicguestinterface", "vmicheartbeat", 
        "vmickvpexchange", "vmicrdv", "vmicshutdown", "vmictimesync", "vmicvmsession", "vmicvss", 
        "wbengine", "wcncsvc", "webthreatdefsvc", "wercplsupport", "wisvc", "wlidsvc", "wlpasvc", 
        "wmiApSrv", "workfolderssvc", "wuauserv"
    )
    foreach ($svc in $manualServices) {
        if (Get-Service $svc -ErrorAction SilentlyContinue) {
            Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
        }
    }

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
    
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK" 0
    
    $capStore = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore"
    $denyList = @("activity","appDiagnostics","appointments","bluetoothSync","broadFileSystemAccess","cellularData","chat","contacts","documentsLibrary","email","gazeInput","location","phoneCall","phoneCallHistory","picturesLibrary","radios","userAccountInformation","userDataTasks","userNotificationListener","videosLibrary")
    foreach ($cap in $denyList) {
        Set-Reg "$capStore\$cap" "Value" "Deny" "String"
    }
    Set-Reg "$capStore\microphone" "Value" "Allow" "String"
    Set-Reg "$capStore\webcam" "Value" "Allow" "String"
    try {
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

    Log "Applying GTweak Performance settings..."

    Set-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506" "String"
    Set-Reg "HKCU:\Control Panel\Accessibility\Keyboard Response" "Flags" "122" "String"

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows Defender Security Center\Notifications" "DisableNotifications" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" "DisableNotifications" 1

    Set-Reg "HKCU:\Control Panel\Desktop" "AutoEndTasks" "1"

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "Startupdelayinmsec" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BackgroundAppGlobalToggle" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" 2

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" "AutoDownload" 2

    Log "Applying optimizerNXT Performance tweaks..."

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NoLazyMode" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "AlwaysOn" 1
    
    $mmGames = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    Set-Reg $mmGames "GPU Priority" 8
    Set-Reg $mmGames "Priority" 6
    Set-Reg $mmGames "Scheduling Category" "High" "String"
    Set-Reg $mmGames "SFIO Priority" "High" "String"

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xFFFFFFFF

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control" "WaitToKillServiceTimeout" "2000" "String"
    Set-Reg "HKCU:\Control Panel\Desktop" "HungAppTimeout" "1000" "String"
    Set-Reg "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "2000" "String"
    Set-Reg "HKCU:\Control Panel\Desktop" "LowLevelHooksTimeout" "1000" "String"
    Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" 0
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseHoverTime" 0

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "CrashDumpEnabled" 3

    & fsutil behavior set disablelastaccess 1 2>&1 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoLowDiskSpaceChecks" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "LinkResolveIgnoreLinkInfo" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoResolveSearch" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoResolveTrack" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoInternetOpenWith" 1

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 0

    Set-Reg "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Media Foundation" "EnableFrameServerMode" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapAssistFlyout" 0
    Set-Reg "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" "" "" "String"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideSCAMeetNow" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideSCAMeetNow" 1
    try { Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Stickers" -Name "EnableStickers" -ErrorAction SilentlyContinue } catch {}

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" "SaveZoneInformation" 1
    Set-Reg "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" "ScanWithAntiVirus" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "ShellSmartScreenLevel" "Warn" "String"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableSmartScreen" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "SmartScreenEnabled" "Off" "String"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Internet Explorer\PhishingFilter" "EnabledV9" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost" "PreventOverride" 0

    Log "Applying Additional Performance & FPS Tweaks..."

    # System Responsiveness & Priority
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 0x26

    # Network Throttling & Latency
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xFFFFFFFF
    
    # GPU Tweaks (NVIDIA/AMD) - MSI Mode, P-States, HDCP
    # Note: Specific GPU GUIDs are dynamic, but we can set global flags where applicable
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "PlatformSupportMiracast" 0
    
    # Input Latency Reduction
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String"
    Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String"

    # Disable Game Bar & DVR (Full disable)
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
    
    # Disable Xbox Capture
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AudioCaptureEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "HistoricalCaptureEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "CursorCaptureEnabled" 0

    # Privacy & Background Apps (FPS boost by freeing resources)
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessGazeInput" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessMotion" 2
    
    # Visual Effects (Performance)
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 3
    Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" "String"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "EnableAeroPeek" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "AlwaysHibernateThumbnails" 0
    
    # File System & Cache
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "MaxCachedIcons" "4096" "String"
    
    # Disable Fault Tolerant Heap (Reduces overhead)
    Set-Reg "HKLM:\SOFTWARE\Microsoft\FTH" "Enabled" 0
    
    # Disable Sleep/Hibernate/Fast Startup
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0

    Log "System Optimizations Applied."
}
Export-ModuleMember -Function Invoke-SystemOptimization

function Invoke-GroupPolicyTweaks {
    param(
        [Action[string]]$Logger
    )

    function Log($msg) { if ($Logger) { $Logger.Invoke($msg) } else { Write-Host $msg } }

    Log "Applying Group Policy Tweaks (Update Blocking)..."

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
        } catch {}
    }

    # WSUS Spoofing to block updates
    $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    Set-Reg $wuPath "WUServer" "https://DoNotUpdateWindows10.com/" "String"
    Set-Reg $wuPath "WUStatusServer" "https://DoNotUpdateWindows10.com/" "String"
    Set-Reg $wuPath "UpdateServiceUrlAlternate" "https://DoNotUpdateWindows10.com/" "String"
    Set-Reg $wuPath "SetProxyBehaviorForUpdateDetection" 0
    Set-Reg $wuPath "SetDisableUXWUAccess" 1
    Set-Reg $wuPath "DoNotConnectToWindowsUpdateInternetLocations" 1
    Set-Reg $wuPath "ExcludeWUDriversInQualityUpdate" 1
    
    $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    Set-Reg $auPath "NoAutoUpdate" 1
    Set-Reg $auPath "UseWUServer" 1

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\UsoSvc" "Start" 4
    
    # Delivery Optimization
    Set-Reg "HKU:\S-1-5-20\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings" "DownloadMode" 0

    try {
        Disable-ScheduledTask -TaskName "\Microsoft\Windows\WindowsUpdate\Scheduled Start" -ErrorAction SilentlyContinue | Out-Null
    } catch {}

    Log "Group Policy Tweaks Applied."
}
Export-ModuleMember -Function Invoke-GroupPolicyTweaks

function Invoke-ModernCursor {
    param(
        [Action[string]]$Logger
    )

    function Log($msg) { if ($Logger) { $Logger.Invoke($msg) } else { Write-Host $msg } }

    Log "Installing Modern Cursor Scheme..."
    
    # Locate ModernCursors folder in Modules
    $sourceCursors = Join-Path $PSScriptRoot "ModernCursors"
    $destCursors = "$env:SystemRoot\Cursors\Fluent Cursor"
    
    if (Test-Path $sourceCursors) {
        if (!(Test-Path $destCursors)) {
            New-Item -Path $destCursors -ItemType Directory -Force | Out-Null
        }
        
        Log "Copying cursor files..."
        Copy-Item "$sourceCursors\*" -Destination $destCursors -Force -Recurse -Exclude "*.reg"
        
        Log "Registering cursor scheme..."
        $regFile = Join-Path $sourceCursors "ModernCursorScheme.reg"
        if (Test-Path $regFile) {
            Start-Process regedit.exe -ArgumentList "/s `"$regFile`"" -Wait
        }
        
        Log "Refreshing system cursors..."
        $code = @"
using System;
using System.Runtime.InteropServices;
public class CursorRefresher {
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
}
"@
        try {
            if (-not ([System.Management.Automation.PSTypeName]'WinAPI.CursorRefresher').Type) {
                Add-Type -TypeDefinition $code -Name "CursorRefresher" -Namespace "WinAPI" -ErrorAction Stop
            }
            [WinAPI.CursorRefresher]::SystemParametersInfo(0x0057, 0, [IntPtr]::Zero, 0) # SPI_SETCURSORS
        } catch {
            Log "Failed to refresh cursors via API: $_"
        }
        
        Log "Modern Cursor applied."
    } else {
        Log "ModernCursors folder not found in: $sourceCursors"
    }
}
Export-ModuleMember -Function Invoke-ModernCursor
