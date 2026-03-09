# Gaming Module
function Invoke-GamingOptimization {
    param([Action[string]]$Logger)
    
    function Log($msg) { if ($Logger) { $Logger.Invoke($msg) } else { Write-Host $msg } }

    Log "Starting Gaming Tweaks..."

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

    # Backup / Restore Point
    Log "Creating System Restore Point (Gaming Optimization)..."
    try {
        Checkpoint-Computer -Description "IlumnulOS_GamingBoost" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
    } catch {
        Log "Could not create restore point. Ensure System Protection is enabled."
    }

    # =========================================================================
    # 1. NETWORK OPTIMIZATION (Latency & Throughput)
    # Impact: Advanced | Benefit: Lower ping, reduced packet loss
    # =========================================================================
    Log "Applying Network Optimizations..."
    
    # Global TCP Settings
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "GlobalMaxTcpWindowSize" 65535
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpWindowSize" 65535
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxFreeTcbs" 65535
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxHashTableSize" 65536
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "Tcp1323Opts" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "SackOpts" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "DefaultTTL" 64
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxUserPort" 65534
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpTimedWaitDelay" 30

    # Network Throttling
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xFFFFFFFF # Disabled

    # Interface Specific (Nagle's Algorithm & Offloading)
    $adapters = Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true }
    foreach ($nic in $adapters) {
        $pnpId = $nic.PNPDeviceID
        $guid = $nic.GUID
        
        # TCP Interface Parameters (Nagle's Algorithm)
        $tcpKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
        if (Test-Path $tcpKey) {
            Set-Reg $tcpKey "TcpAckFrequency" 1
            Set-Reg $tcpKey "TCPNoDelay" 1
        }

        # Adapter Advanced Properties
        $key = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters"
        
        # Power Saving
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

        # Disable Jumbo Packet (Latency)
        Set-Reg $key "JumboPacket" "1514" "String"

        # Buffer Sizes (Throughput vs Latency trade-off - Balanced)
        Set-Reg $key "ReceiveBuffers" "1024" "String"
        Set-Reg $key "TransmitBuffers" "2048" "String"

        # Offloads (Disable to reduce CPU latency on modern NICs)
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

        # RSS (Receive Side Scaling) - Enable for multi-core CPUs
        Set-Reg $key "RSS" "1" "String"
        Set-Reg $key "*NumRssQueues" "2" "String"
        Set-Reg $key "RSSProfile" "3" "String"

        # Flow Control (Disable)
        Set-Reg $key "*FlowControl" "0" "String"
        Set-Reg $key "FlowControlCap" "0" "String"

        # Interrupt Moderation (Disable for lowest latency, Enable for CPU saving)
        # Setting to 0 (Disabled) for pure gaming latency
        Set-Reg $key "TxIntDelay" "0" "String"
        Set-Reg $key "TxAbsIntDelay" "0" "String"
        Set-Reg $key "RxIntDelay" "0" "String"
        Set-Reg $key "RxAbsIntDelay" "0" "String"
        Set-Reg $key "FatChannelIntolerant" "0" "String"
        Set-Reg $key "*InterruptModeration" "0" "String"
    }

    # =========================================================================
    # 2. SYSTEM & CPU OPTIMIZATION
    # Impact: Expert | Benefit: Thread prioritization for Games
    # =========================================================================
    Log "Applying System & CPU Optimizations..."

    # System Profile (Gaming Priority)
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NoLazyMode" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "AlwaysOn" 1
    
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 8
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 6
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" "High" "String"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "SFIO Priority" "High" "String"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Latency Sensitive" "True" "String"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Background Only" "False" "String"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Clock Rate" 10000

    # CSRSS Realtime
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" "CpuPriorityClass" 4
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" "IoPriority" 3

    # Distribute Timers
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DistributeTimers" 1

    # Disable GPU Energy Driver
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\GpuEnergyDrv" "Start" 4

    # Power Plan (Ultimate Performance)
    Log "Enforcing Ultimate Performance Power Plan..."
    & powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
    & powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61

    # =========================================================================
    # 3. GPU OPTIMIZATION (DirectX / Drivers)
    # Impact: Advanced | Benefit: FPS stability, lower render latency
    # =========================================================================
    Log "Applying GPU Optimizations..."

    # HAGS (Hardware-Accelerated GPU Scheduling)
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2

    # DirectX Contiguous Memory
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "DpiMapIommuContiguous" 1

    # FSO (Full Screen Optimizations) & Game Bar
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_DSEBehavior" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_FSEBehaviorMode" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_EFSEFeatureFlags" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_DXGIHonorFSEWindowsCompatible" 0
    Set-Reg "HKCU:\SYSTEM\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode" 1
    Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "AllowAutoGameMode" 1
    Set-Reg "HKCU:\SOFTWARE\Microsoft\GameBar" "AutoGameModeEnabled" 1
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0

    # MPO (Multiplane Overlay) - Often causes flickering, disabling can help stability
    try { Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -ErrorAction SilentlyContinue } catch {}

    # Windowed Game Optimizations
    Set-Reg "HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences" "DirectXUserGlobalSettings" "VRROptimizeEnable=0;SwapEffectUpgradeEnable=1;" "String"

    # GPU P-States & MSI Mode
    $videoControllers = Get-WmiObject Win32_VideoController | Where-Object { $_.PNPDeviceID -match "PCI\\VEN_" }
    foreach ($gpu in $videoControllers) {
        $pnpId = $gpu.PNPDeviceID
        
        # P-States (Disable Power Saving)
        $driverKey = Get-ItemProperty "HKLM:\SYSTEM\ControlSet001\Enum\$pnpId" -Name "Driver"
        if ($driverKey) {
            $classId = $driverKey.Driver
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$classId" "DisableDynamicPstate" 1
        }

        # MSI Mode (Message Signaled Interrupts)
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" 1
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\Affinity Policy" "DevicePriority" 0
    }

    # NVIDIA Specific Tweaks
    if ($videoControllers.Name -match "NVIDIA") {
        Log "Applying NVIDIA Specific Tweaks..."
        
        # 1. Apply tweaks to the specific GPU Class Key (handling multiple GPUs/indices)
        foreach ($gpu in $videoControllers) {
            if ($gpu.Name -match "NVIDIA") {
                $pnpId = $gpu.PNPDeviceID
                $driverKey = Get-ItemProperty "HKLM:\SYSTEM\ControlSet001\Enum\$pnpId" -Name "Driver"
                if ($driverKey) {
                    $classId = $driverKey.Driver # e.g., {4d36e968...}\0000
                    $nvKeyBase = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$classId"
                    
                    Log "Targeting NVIDIA GPU at $nvKeyBase"

                    # Latency & Performance
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
                    
                    # Memory & System
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
                    
                    # Shortcuts & Filters
                    Set-Reg $nvKeyBase "DesktopStereoShortcuts" 0
                    Set-Reg $nvKeyBase "FeatureControl" 4
                    Set-Reg $nvKeyBase "NVDeviceSupportKFilter" 0
                }
            }
        }

        # 2. Global Driver Service Tweaks (nvlddmkm)
        $nvService = "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm"
        if (Test-Path $nvService) {
            Log "Applying NVIDIA Driver Service Tweaks..."
            Set-Reg "$nvService\Global\NVTweak" "DisplayPowerSaving" 0
            Set-Reg $nvService "DisableWriteCombining" 1
            
            # DPC Per Core
            Set-Reg $nvService "RmGpsPsEnablePerCpuCoreDpc" 1
            Set-Reg "$nvService\NVAPI" "RmGpsPsEnablePerCpuCoreDpc" 1
            Set-Reg "$nvService\Global\NVTweak" "RmGpsPsEnablePerCpuCoreDpc" 1
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "RmGpsPsEnablePerCpuCoreDpc" 1
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" "RmGpsPsEnablePerCpuCoreDpc" 1
        }

        # 3. Telemetry & Tasks
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
            Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
        }

        # 4. TDR (Timeout Detection and Recovery) - Disable
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

    # =========================================================================
    # 4. INPUT OPTIMIZATION
    # Impact: Safe | Benefit: 1:1 Mouse Movement
    # =========================================================================
    Log "Optimizing Input Latency..."
    
    # Disable Mouse Acceleration (Enhance Pointer Precision)
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String"
    
    # 1:1 Pixel Mapping Curve
    Set-Reg "HKCU:\Control Panel\Mouse" "SmoothMouseXCurve" ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) "Binary"
    Set-Reg "HKCU:\Control Panel\Mouse" "SmoothMouseYCurve" ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) "Binary"

    Log "Gaming Optimization Complete."
}

function Invoke-NvidiaProfile {
    param([Action[string]]$Logger)
    
    function Log($msg) { if ($Logger) { $Logger.Invoke($msg) } else { Write-Host $msg } }

    Log "Applying NVIDIA Inspector Profile..."

    if ($global:IlumnulRoot) {
        $ScriptPath = $global:IlumnulRoot
    } elseif ($env:TEMP -and (Test-Path "$env:TEMP\IlumnulOS_v2")) {
        # Fallback for remote execution if global var lost
        $ScriptPath = "$env:TEMP\IlumnulOS_v2"
    } else {
        $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    
    if (-not $ScriptPath) {
        Log "ERROR: Could not determine script path. Aborting."
        return
    }

    $ConfigPath = Join-Path -Path $ScriptPath -ChildPath "Config\settings.json"
    
    if (!(Test-Path $ConfigPath)) {
        Log "Error: Config file not found at $ConfigPath"
        return
    }

    try {
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        $zipUrl = $config.Tools.NvidiaInspector.Url
        # $expectedHash = $config.Tools.NvidiaInspector.Hash
        $profileUrl = $config.Tools.IlumnulProfile.Url
    } catch {
        Log "Error reading configuration: $_"
        return
    }

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

        # Hash Verification Skipped as requested
        # if ($expectedHash) { ... }

        Log "Extracting..."
        Expand-Archive -Path $zipPath -DestinationPath $destDir -Force -ErrorAction Stop

        Log "Downloading IlumnulOS Profile..."
        try {
            Invoke-WebRequest -Uri $profileUrl -OutFile $profilePath -ErrorAction Stop
        } catch {
             $wc = New-Object System.Net.WebClient
             $wc.DownloadFile($profileUrl, $profilePath)
        }

        Log "Applying Profile..."
        if (Test-Path $exePath) {
            Start-Process -FilePath $exePath -ArgumentList "`"$profilePath`"" -Wait -NoNewWindow
            Log "NVIDIA Profile Applied Successfully."
        } else {
            Log "Error: Executable not found at $exePath"
        }

    } catch {
        Log "Error applying NVIDIA profile: $_"
    } finally {
        # Cleanup temp zip
        if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Export-ModuleMember -Function Invoke-GamingOptimization, Invoke-NvidiaProfile
