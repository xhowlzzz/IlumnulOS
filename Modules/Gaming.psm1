function Invoke-GamingOptimization {
    param(
        [Action[string]]$Logger,
        [hashtable]$Options = @{}
    )
    
    function Log($msg) { if ($Logger) { $Logger.Invoke($msg) } else { Write-Host $msg } }

    Log "Starting Gaming Tweaks..."
    $EnableGameMode = if ($Options.ContainsKey("GameMode")) { [bool]$Options.GameMode } else { $true }
    $EnableGpuPriority = if ($Options.ContainsKey("GPUPriority")) { [bool]$Options.GPUPriority } else { $true }
    $DisableGameBar = if ($Options.ContainsKey("DisableGameBar")) { [bool]$Options.DisableGameBar } else { $true }
    $EnableHags = if ($Options.ContainsKey("HAGS")) { [bool]$Options.HAGS } else { $true }
    $EnableNetworkTweaks = if ($Options.ContainsKey("NetworkTweaks")) { [bool]$Options.NetworkTweaks } else { $true }

    function Set-Reg {
        param($Path, $Name, $Value, $Type = "DWord")
        try {
            $Path = $Path.TrimEnd('\')
            if ($Path -like "HKU:*" -and -not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
                New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
            }
            if (!(Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
            
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

    Log "Creating System Restore Point (Gaming Optimization)..."
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
        Checkpoint-Computer -Description "IlumnulOS_GamingBoost" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
    } catch {
    }

    if ($EnableNetworkTweaks) {
    Log "Applying Network Optimizations..."
    
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "GlobalMaxTcpWindowSize" 65535
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpWindowSize" 65535
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxFreeTcbs" 65535
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxHashTableSize" 65536
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "Tcp1323Opts" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "SackOpts" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "DefaultTTL" 64
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxUserPort" 65534
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpTimedWaitDelay" 30

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xFFFFFFFF # Disabled

    $adapters = Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true }
    foreach ($nic in $adapters) {
        $pnpId = $nic.PNPDeviceID
        $guid = $nic.GUID
        
        $tcpKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
        if (Test-Path $tcpKey) {
            Set-Reg $tcpKey "TcpAckFrequency" 1
            Set-Reg $tcpKey "TCPNoDelay" 1
        }

        $key = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters"
        
        Set-Reg $key "*InterruptModeration" "0" "String"
        Set-Reg $key "InterruptModeration" "0" "String"
        Set-Reg $key "AutoPowerSaveModeEnabled" "0" "String"
        Set-Reg $key "AutoDisableGigabit" "0" "String"
        Set-Reg $key "AdvancedEEE" "0" "String"
        Set-Reg $key "DisableDelayedPowerUp" "2" "String"
        Set-Reg $key "*EEE" "0" "String"
        Set-Reg $key "EEE" "0" "String"
        Set-Reg $key "EnablePME" "0" "String"
        Set-Reg $key "EEELinkAdvertisement" "0" "String"
        Set-Reg $key "EnableGreenEthernet" "0" "String"
        Set-Reg $key "EnableSavePowerNow" "0" "String"
        Set-Reg $key "EnablePowerManagement" "0" "String"
        Set-Reg $key "EnableDynamicPowerGating" "0" "String"
        Set-Reg $key "EnableConnectedPowerGating" "0" "String"
        Set-Reg $key "EnableWakeOnLan" "0" "String"
        Set-Reg $key "GigaLite" "0" "String"
        Set-Reg $key "NicAutoPowerSaver" "2" "String"
        Set-Reg $key "PowerDownPll" "0" "String"
        Set-Reg $key "PowerSavingMode" "0" "String"
        Set-Reg $key "ReduceSpeedOnPowerDown" "0" "String"
        Set-Reg $key "SmartPowerDownEnable" "0" "String"
        Set-Reg $key "S5NicKeepOverrideMacAddrV2" "0" "String"
        Set-Reg $key "S5WakeOnLan" "0" "String"
        Set-Reg $key "ULPMode" "0" "String"
        Set-Reg $key "WakeOnDisconnect" "0" "String"
        Set-Reg $key "*WakeOnMagicPacket" "0" "String"
        Set-Reg $key "*WakeOnPattern" "0" "String"
        Set-Reg $key "WakeOnLink" "0" "String"
        Set-Reg $key "WolShutdownLinkSpeed" "2" "String"

        Set-Reg $key "JumboPacket" "1514" "String"

        Set-Reg $key "ReceiveBuffers" "1024" "String"
        Set-Reg $key "TransmitBuffers" "2048" "String"

        Set-Reg $key "IPChecksumOffloadIPv4" "0" "String"
        Set-Reg $key "LsoV1IPv4" "0" "String"
        Set-Reg $key "LsoV2IPv4" "0" "String"
        Set-Reg $key "LsoV2IPv6" "0" "String"
        Set-Reg $key "PMARPOffload" "0" "String"
        Set-Reg $key "PMNSOffload" "0" "String"
        Set-Reg $key "TCPChecksumOffloadIPv4" "0" "String"
        Set-Reg $key "TCPChecksumOffloadIPv6" "0" "String"
        Set-Reg $key "UDPChecksumOffloadIPv6" "0" "String"
        Set-Reg $key "UDPChecksumOffloadIPv4" "0" "String"

        Set-Reg $key "RSS" "1" "String"
        Set-Reg $key "*NumRssQueues" "2" "String"
        Set-Reg $key "RSSProfile" "3" "String"

        Set-Reg $key "*FlowControl" "0" "String"
        Set-Reg $key "FlowControlCap" "0" "String"

        Set-Reg $key "TxIntDelay" "0" "String"
        Set-Reg $key "TxAbsIntDelay" "0" "String"
        Set-Reg $key "RxIntDelay" "0" "String"
        Set-Reg $key "RxAbsIntDelay" "0" "String"
        Set-Reg $key "FatChannelIntolerant" "0" "String"
        Set-Reg $key "*InterruptModeration" "0" "String"
    }
    }

    Log "Applying System & CPU Optimizations..."

    Log "[P10] Applying System Profile..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NoLazyMode" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "AlwaysOn" 1
    
    if ($EnableGpuPriority) {
        Log "[P20] Setting GPU Priority..."
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 8
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 6
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" "High" "String"
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "SFIO Priority" "High" "String"
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Latency Sensitive" "True" "String"
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Background Only" "False" "String"
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Clock Rate" 10000
    }

    Log "[P30] Optimizing CSRSS..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" "CpuPriorityClass" 4
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" "IoPriority" 3
    
    Log "[P40] Disabling Network Throttling..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xFFFFFFFF # Disabled
    
    Log "[P60] Optimizing System Process Affinity..."
    try {
        $cpuCount = (Get-CimInstance Win32_Processor).NumberOfCores
        if ($cpuCount -gt 4) {
            $mask = [Math]::Pow(2, $cpuCount - 1) + [Math]::Pow(2, $cpuCount - 2) # Last 2 cores
            $processes = Get-Process -Name "dwm", "explorer" -ErrorAction SilentlyContinue
            foreach ($p in $processes) {
                $p.ProcessorAffinity = [IntPtr]$mask
            }
        }
    } catch {}

    Log "[P80] Boosting Thread Priority..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 0x28

    Log "[P100] Gaming Tweaks Applied."
    try {
        $plans = & powercfg /list 2>&1
        if ($plans -match "e9a42b02-d5df-448d-aa00-03f14749eb61") {
            & powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null
        } else {
            & powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null
            & powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null
        }
    } catch {
        Log "Failed to set Ultimate Performance plan: $($_.Exception.Message)"
    }

    Log "Applying GPU Optimizations..."

    if ($EnableHags) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
    }

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "DpiMapIommuContiguous" 1

    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_DSEBehavior" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_FSEBehaviorMode" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_EFSEFeatureFlags" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_DXGIHonorFSEWindowsCompatible" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode" 1
    if ($EnableGameMode) {
        Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "AllowAutoGameMode" 1
        Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "AutoGameModeEnabled" 1
    }
    if ($DisableGameBar) {
        Log "Disabling Game Bar & DVR (optimizerNXT)..."
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AudioCaptureEnabled" 0
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "CursorCaptureEnabled" 0
        Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
        Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "ShowStartupPanel" 0
        Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
        Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 2
        Set-Reg "HKLM:\Software\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
        
        $xboxServices = @("XboxNetApiSvc", "XblAuthManager", "XblGameSave", "XboxGipSvc", "xbgm")
        foreach ($svc in $xboxServices) {
            try {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            } catch {}
        }
        
        try {
            Unregister-ScheduledTask -TaskName "\Microsoft\XblGameSave\XblGameSaveTask" -Confirm:$false -ErrorAction SilentlyContinue
            Unregister-ScheduledTask -TaskName "\Microsoft\XblGameSave\XblGameSaveTaskLogon" -Confirm:$false -ErrorAction SilentlyContinue
        } catch {}
    }

    try { Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -ErrorAction SilentlyContinue } catch {}

    Set-Reg "HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences" "DirectXUserGlobalSettings" "VRROptimizeEnable=0;SwapEffectUpgradeEnable=1;" "String"

    $videoControllers = Get-WmiObject Win32_VideoController | Where-Object { $_.PNPDeviceID -match "PCI\\VEN_" }
    foreach ($gpu in $videoControllers) {
        $pnpId = $gpu.PNPDeviceID
        
        $driverKey = Get-ItemProperty "HKLM:\SYSTEM\ControlSet001\Enum\$pnpId" -Name "Driver"
        if ($driverKey) {
            $classId = $driverKey.Driver
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$classId" "DisableDynamicPstate" 1
        }

        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" 1
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\Affinity Policy" "DevicePriority" 0
    }

    if ($videoControllers.Name -match "NVIDIA") {
        Log "Applying NVIDIA Specific Tweaks..."
        
        foreach ($gpu in $videoControllers) {
            if ($gpu.Name -match "NVIDIA") {
                $pnpId = $gpu.PNPDeviceID
                $driverKey = Get-ItemProperty "HKLM:\SYSTEM\ControlSet001\Enum\$pnpId" -Name "Driver"
                if ($driverKey) {
                    $classId = $driverKey.Driver # e.g., {4d36e968...}\0000
                    $nvKeyBase = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$classId"
                    
                    Log "Targeting NVIDIA GPU at $nvKeyBase"

                    Set-Reg $nvKeyBase "D3PCLatency" 1
                    Set-Reg $nvKeyBase "F1TransitionLatency" 1
                    Set-Reg $nvKeyBase "LOWLATENCY" 1
                    Set-Reg $nvKeyBase "Node3DLowLatency" 1
                    Set-Reg $nvKeyBase "PciLatencyTimerControl" 20
                    Set-Reg $nvKeyBase "RMDeepL1EntryLatencyUsec" 1
                    Set-Reg $nvKeyBase "RmGspcMaxFtuS" 1
                    Set-Reg $nvKeyBase "RmGspcMinFtuS" 1
                    Set-Reg $nvKeyBase "RmGspcPerioduS" 1
                    Set-Reg $nvKeyBase "RMLpwrEiIdleThresholdUs" 1
                    Set-Reg $nvKeyBase "RMLpwrGrIdleThresholdUs" 1
                    Set-Reg $nvKeyBase "RMLpwrGrRgIdleThresholdUs" 1
                    Set-Reg $nvKeyBase "RMLpwrMsIdleThresholdUs" 1
                    Set-Reg $nvKeyBase "VRDirectFlipDPCDelayUs" 1
                    Set-Reg $nvKeyBase "VRDirectFlipTimingMarginUs" 1
                    Set-Reg $nvKeyBase "VRDirectJITFlipMsHybridFlipDelayUs" 1
                    Set-Reg $nvKeyBase "vrrCursorMarginUs" 1
                    Set-Reg $nvKeyBase "vrrDeflickerMarginUs" 1
                    Set-Reg $nvKeyBase "vrrDeflickerMaxUs" 1
                    
                    Set-Reg $nvKeyBase "PreferSystemMemoryContiguous" 1
                    Set-Reg $nvKeyBase "RMHdcpKeyGlobZero" 1 # Disable HDCP
                    Set-Reg $nvKeyBase "TCCSupported" 0
                    Set-Reg $nvKeyBase "Acceleration.Level" 0
                    Set-Reg $nvKeyBase "RmCacheLoc" 0 # Increased Dedicated Memory
                    Set-Reg $nvKeyBase "RmDisableInst2Sys" 0
                    Set-Reg $nvKeyBase "RmFbsrPagedDMA" 1
                    Set-Reg $nvKeyBase "RmProfilingAdminOnly" 0
                    Set-Reg $nvKeyBase "TrackResetEngine" 0
                    Set-Reg $nvKeyBase "ValidateBlitSubRects" 0
                    
                    Set-Reg $nvKeyBase "DesktopStereoShortcuts" 0
                    Set-Reg $nvKeyBase "FeatureControl" 4
                    Set-Reg $nvKeyBase "NVDeviceSupportKFilter" 0
                }
            }
        }

        $nvService = "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm"
        if (Test-Path $nvService) {
            Log "Applying NVIDIA Driver Service Tweaks..."
            Set-Reg "$nvService\Global\NVTweak" "DisplayPowerSaving" 0
            Set-Reg $nvService "DisableWriteCombining" 1
            
            Set-Reg $nvService "RmGpsPsEnablePerCpuCoreDpc" 1
            Set-Reg "$nvService\NVAPI" "RmGpsPsEnablePerCpuCoreDpc" 1
            Set-Reg "$nvService\Global\NVTweak" "RmGpsPsEnablePerCpuCoreDpc" 1
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "RmGpsPsEnablePerCpuCoreDpc" 1
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" "RmGpsPsEnablePerCpuCoreDpc" 1
        }

        Log "Disabling NVIDIA Telemetry..."
        try { Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "NvBackend" -ErrorAction SilentlyContinue } catch {}
        Set-Reg "HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client" "OptInOrOutPreference" 0
        Set-Reg "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" "EnableRID66610" 0
        Set-Reg "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" "EnableRID64640" 0
        Set-Reg "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" "EnableRID44231" 0
        
        $nvTasks = @(
            "NvTmRep_CrashReport1_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
            "NvTmRep_CrashReport2_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
            "NvTmRep_CrashReport3_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
            "NvTmRep_CrashReport4_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
            "NvDriverUpdateCheckDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
            "NVIDIA GeForce Experience SelfUpdate_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
            "NvTmMon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"
        )
        foreach ($task in $nvTasks) {
            Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
        }

        Log "Disabling TDR..."
        $gfxDrivers = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        Set-Reg $gfxDrivers "TdrLevel" 0
        Set-Reg $gfxDrivers "TdrDelay" 0
        Set-Reg $gfxDrivers "TdrDdiDelay" 0
        Set-Reg $gfxDrivers "TdrDebugMode" 0
        Set-Reg $gfxDrivers "TdrLimitCount" 0
        Set-Reg $gfxDrivers "TdrLimitTime" 0
        Set-Reg $gfxDrivers "TdrTestMode" 0
    }

    if ($videoControllers.Name -match "AMD" -or $videoControllers.Name -match "Radeon") {
        Log "Applying AMD Specific Tweaks..."
        foreach ($gpu in $videoControllers) {
            if ($gpu.Name -match "AMD" -or $gpu.Name -match "Radeon") {
                $pnpId = $gpu.PNPDeviceID
                $driverKey = Get-ItemProperty "HKLM:\SYSTEM\ControlSet001\Enum\$pnpId" -Name "Driver"
                if ($driverKey) {
                    $classId = $driverKey.Driver
                    $amdKeyBase = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$classId"
                    
                    Log "Targeting AMD GPU at $amdKeyBase"

                    Set-Reg $amdKeyBase "3D_Refresh_Rate_Override_DEF" 0
                    Set-Reg $amdKeyBase "AllowSnapshot" 0
                    Set-Reg $amdKeyBase "AllowRSOverlay" "false" "String"
                    Set-Reg $amdKeyBase "AllowSkins" "false" "String"
                    Set-Reg $amdKeyBase "AllowSubscription" 0
                    Set-Reg $amdKeyBase "AutoColorDepthReduction_NA" 0

                    Set-Reg $amdKeyBase "AAF_NA" 0
                    Set-Reg $amdKeyBase "AntiAlias_NA" "0" "String"
                    Set-Reg $amdKeyBase "ASTT_NA" "0" "String"
                    Set-Reg $amdKeyBase "AreaAniso_NA" "0" "String"

                    Set-Reg $amdKeyBase "DisableSAMUPowerGating" 1
                    Set-Reg $amdKeyBase "DisableUVDPowerGatingDynamic" 1
                    Set-Reg $amdKeyBase "DisableVCEPowerGating" 1
                    Set-Reg $amdKeyBase "DisablePowerGating" 1
                    Set-Reg $amdKeyBase "DisableDrmdmaPowerGating" 1
                    Set-Reg $amdKeyBase "EnableVceSwClockGating" 0
                    Set-Reg $amdKeyBase "EnableUvdClockGating" 0
                    Set-Reg $amdKeyBase "EnableAspmL0s" 0
                    Set-Reg $amdKeyBase "EnableAspmL1" 0
                    Set-Reg $amdKeyBase "EnableUlps" 0
                    Set-Reg $amdKeyBase "EnableUlps_NA" "0" "String"
                    Set-Reg $amdKeyBase "PP_SclkDeepSleepDisable" 1

                    Set-Reg $amdKeyBase "KMD_DeLagEnabled" 1
                    Set-Reg $amdKeyBase "KMD_FRTEnabled" 0
                    Set-Reg $amdKeyBase "DisableDMACopy" 1
                    Set-Reg $amdKeyBase "DisableBlockWrite" 0
                    Set-Reg $amdKeyBase "StutterMode" 0
                    Set-Reg $amdKeyBase "Adaptive De-interlacing" 1
                }
            }
        }
    }

    Log "Optimizing Input Latency..."
    
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String"
    
    Set-Reg "HKCU:\Control Panel\Mouse" "SmoothMouseXCurve" ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) "Binary"
    Set-Reg "HKCU:\Control Panel\Mouse" "SmoothMouseYCurve" ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) "Binary"

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xFFFFFFFF
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0

    Log "Applying Low Latency Networking (TCP Tweaks)..."
    $interfaces = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    foreach ($interface in $interfaces) {
        Set-Reg $interface.PSPath "TcpAckFrequency" 1
        Set-Reg $interface.PSPath "TcpNoDelay" 1
        Set-Reg $interface.PSPath "TcpDelAckTicks" 0
    }

    Log "Enforcing Global Timer Resolution (0.5ms)..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "GlobalTimerResolution" 5000 # 0.5ms

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\Game.exe" "IoPriority" 3 # High
    
    Log "Optimizing System Process Affinity..."
    try {
        $cpuCount = (Get-CimInstance Win32_Processor).NumberOfCores
        if ($cpuCount -gt 4) {
            $mask = [Math]::Pow(2, $cpuCount - 1) + [Math]::Pow(2, $cpuCount - 2) # Last 2 cores
            $processes = Get-Process -Name "dwm", "explorer" -ErrorAction SilentlyContinue
            foreach ($p in $processes) {
                $p.ProcessorAffinity = [IntPtr]$mask
            }
        }
    } catch {}

    Log "Boosting Thread Priority for Gaming..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 0x28
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" "High" "String"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "SFIO Priority" "High" "String"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Background Only" "False" "String"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 8
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 8
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Clock Rate" 10000

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System" "CountOperations" 0

    Log "Disabling Mouse Acceleration (Raw Input)..."
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "SmoothMouseXCurve" ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) "Binary"
    Set-Reg "HKCU:\Control Panel\Mouse" "SmoothMouseYCurve" ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) "Binary"

    Log "Tuning TCP Chimney & Advanced Networking..."
    & netsh int tcp set global chimney=enabled 2>&1 | Out-Null
    & netsh int tcp set global rss=enabled 2>&1 | Out-Null
    & netsh int tcp set global netdma=enabled 2>&1 | Out-Null
    & netsh int tcp set global dca=enabled 2>&1 | Out-Null
    & netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
    & netsh int tcp set global ecncapability=enabled 2>&1 | Out-Null
    & netsh int tcp set global timestamps=disabled 2>&1 | Out-Null

    Log "Cleaning Shader Cache (DirectX)..."
    $shaderPaths = @(
        "$env:LOCALAPPDATA\D3DSCache\*",
        "$env:LOCALAPPDATA\NVIDIA\DXCache\*",
        "$env:LOCALAPPDATA\AMD\DxCache\*"
    )
    foreach ($path in $shaderPaths) {
        try { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
    }

    if ($EnableHags) {
        Log "Enforcing Hardware-Accelerated GPU Scheduling (HAGS)..."
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
    }

    Log "Applying Advanced GPU & Rendering Tweaks..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" "GDIProcessHandleQuota" 10000
    Set-Reg "HKLM:\SOFTWARE\NVIDIA Corporation\Global\System" "EnableHDCP" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" "Digital_Check_Disable" 1

    Log "Enforcing MSI Mode for GPU and USB Controllers..."
    $devices = Get-WmiObject Win32_PnPEntity | Where-Object { $_.Service -match "nvlddmkm|amdgpu|i915|usb" }
    foreach ($dev in $devices) {
        $pnpId = $dev.PNPDeviceID
        $msiKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId") {
            Set-Reg $msiKey "MSISupported" 1
            Set-Reg $msiKey "MessageNumberLimit" 1
        }
    }

    try {
        $cpu = Get-CimInstance Win32_Processor
        if ($cpu.Manufacturer -match "Intel") {
            Log "Intel CPU Detected. Checking for Hybrid Architecture (E-Cores)..."
            if ($cpu.Name -match "i[3579]-1[2345]") {
                Log "Hybrid CPU Detected (12th Gen+). Optimizing thread scheduling for P-Cores..."
                & powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 7f2f5cfa-1f7b-4b4d-82c0-6671c0429000 1 2>&1 | Out-Null
                & powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 93b2201f-9bbc-42be-8811-945c3a2130c0 1 2>&1 | Out-Null
                & powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
            }
        } elseif ($cpu.Manufacturer -match "AMD") {
            Log "AMD CPU Detected. Applying AMD-specific core parking optimization..."
            & powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c30e-4540-a213-566968a9510e 100 2>&1 | Out-Null
            & powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
        }
    } catch {
        Log "CPU specific optimization skipped: $_"
    }

    Log "Gaming tweaks applied."
}

function Invoke-NvidiaProfile {
    param([Action[string]]$Logger)
    
    function Log($msg) { if ($Logger) { $Logger.Invoke($msg) } else { Write-Host $msg } }

    Log "Applying NVIDIA Inspector Profile..."

    $zipUrl = "https://github.com/Orbmu2k/nvidiaProfileInspector/releases/download/2.4.0.19/nvidiaProfileInspector.zip"
    $profileUrl = "https://github.com/xhowlzzz/IlumnulOS/raw/main/Tools/IlumnulOS.nip"

    $tempDir = "$env:TEMP\NvidiaInspector"
    $destDir = "C:\NvidiaProfileInspector"
    $zipPath = "$tempDir\nvidiaProfileInspector.zip"
    $profilePath = "$destDir\IlumnulOS.nip"
    $exePath = "$destDir\nvidiaProfileInspector.exe"

    try {
        if (!(Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force | Out-Null }
        if (!(Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }

        Log "Downloading NVIDIA Profile Inspector..."
        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -ErrorAction Stop
        } catch {
            Log "Standard download failed, trying web client..."
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($zipUrl, $zipPath)
        }

        Log "Extracting..."
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            if (Test-Path "$destDir\nvidiaProfileInspector.exe") { Remove-Item "$destDir\*" -Recurse -Force -ErrorAction SilentlyContinue }
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $destDir)
        } catch {
             Log "NET Extract failed, trying Expand-Archive..."
             Expand-Archive -Path $zipPath -DestinationPath $destDir -Force -ErrorAction SilentlyContinue | Out-Null
        }

        Log "Downloading IlumnulOS Profile..."
        try {
            Invoke-WebRequest -Uri $profileUrl -OutFile $profilePath -ErrorAction Stop
        } catch {
             $wc = New-Object System.Net.WebClient
             $wc.DownloadFile($profileUrl, $profilePath)
        }

        Log "Applying Profile..."
        if (Test-Path $exePath) {
            $absProfilePath = (Get-Item $profilePath).FullName
            Start-Process -FilePath $exePath -ArgumentList "`"$absProfilePath`"" -Wait
            Log "NVIDIA Profile applied. You should see a success message."
        } else {
            Log "Error: Executable not found at $exePath"
        }

    } catch {
        Log "Error applying NVIDIA profile: $_"
    } finally {
        if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Export-ModuleMember -Function Invoke-GamingOptimization, Invoke-NvidiaProfile
