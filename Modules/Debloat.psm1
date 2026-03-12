function Remove-Bloatware {
    param(
        [Action[string]]$Logger,
        [hashtable]$Options = @{}
    )
    
    function Log($msg) { if ($Logger) { $Logger.Invoke($msg) } else { Write-Host $msg } }

    if (!(Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) {
        try {
            New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }

    Log "Starting Privacy & Debloat tweaks..."
    $EnableRemoveAppx = if ($Options.ContainsKey("RemoveAppx")) { [bool]$Options.RemoveAppx } else { $true }
    $EnableRemoveOneDrive = if ($Options.ContainsKey("RemoveOneDrive")) { [bool]$Options.RemoveOneDrive } else { $true }
    $EnableRemoveCortana = if ($Options.ContainsKey("RemoveCortana")) { [bool]$Options.RemoveCortana } else { $true }
    $EnableDisableServices = if ($Options.ContainsKey("DisableServices")) { [bool]$Options.DisableServices } else { $true }
    $EnableDisableTelemetry = if ($Options.ContainsKey("DisableTelemetry")) { [bool]$Options.DisableTelemetry } else { $true }
    $EnableDisableAdvertising = if ($Options.ContainsKey("DisableAdvertising")) { [bool]$Options.DisableAdvertising } else { $true }
    $EnableDisableLocation = if ($Options.ContainsKey("DisableLocation")) { [bool]$Options.DisableLocation } else { $true }

    if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
        Log "Warning: Get-AppxPackage not found. Attempting to load Appx module..."
        Import-Module Appx -ErrorAction SilentlyContinue
    }

    if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        Log "Warning: Get-ScheduledTask not found. Attempting to load ScheduledTasks module..."
        Import-Module ScheduledTasks -Force -ErrorAction SilentlyContinue
    }

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

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RemediationRequired" 0

    Log "Disabling Windows 11 Widgets..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0

    Log "Disabling Windows Chat/Teams..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" "ChatIcon" 3
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0

    Log "Optimizing Snap Layouts..."
    Set-Reg "HKCU:\Control Panel\Desktop" "SnapSizing" 0 # Simplifies visual feedback

    Log "Restoring Classic Context Menu..."
    Set-Reg "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" "" "" "String"

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SmartActionPlatform\SmartClipboard" "Disabled" 1

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDynamicSearchBoxEnabled" 0

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense" "AllowStorageSenseGlobal" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0

    try { Remove-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" -ErrorAction SilentlyContinue } catch {}

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapBar" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapAssistFlyout" 0

    try { Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" -Recurse -Force -ErrorAction SilentlyContinue } catch {}

    try { Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" -Recurse -Force -ErrorAction SilentlyContinue } catch {}

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "HubMode" 1

    Set-Reg "HKCU:\Control Panel\UnsupportedHardwareNotificationCache" "SV2" 0
    Set-Reg "HKLM:\SYSTEM\Setup\LabConfig" "BypassCPUCheck" 1
    Set-Reg "HKLM:\SYSTEM\Setup\LabConfig" "BypassRAMCheck" 1
    Set-Reg "HKLM:\SYSTEM\Setup\LabConfig" "BypassSecureBootCheck" 1
    Set-Reg "HKLM:\SYSTEM\Setup\LabConfig" "BypassStorageCheck" 1
    Set-Reg "HKLM:\SYSTEM\Setup\LabConfig" "BypassTPMCheck" 1
    Set-Reg "HKLM:\SYSTEM\Setup\MoSetup" "AllowUpgradesWithUnsupportedTPMOrCPU" 1

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_Layout" 1

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" "ShowRecentList" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideRecentlyAddedApps" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoInstrumentation" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoStartMenuMFUprogramsList" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoRecentDocsHistory" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "ShowOrHideMostUsedApps" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecentlyAddedApps" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedPersonalizedSites" 1

    Set-Reg "HKCU:\Software\Microsoft\input\Settings" "InsightsEnabled" 0

    $unpinnedKey = "HKCU:\Control Panel\Quick Actions\Control Center\Unpinned"
    if (-not (Test-Path $unpinnedKey)) { New-Item -Path $unpinnedKey -Force | Out-Null }
    Set-Reg $unpinnedKey "Microsoft.QuickAction.BlueLightReduction" ([byte[]]@()) "Binary"
    Set-Reg $unpinnedKey "Microsoft.QuickAction.Accessibility" ([byte[]]@()) "Binary"
    Set-Reg $unpinnedKey "Microsoft.QuickAction.NearShare" ([byte[]]@()) "Binary"
    Set-Reg $unpinnedKey "Microsoft.QuickAction.Cast" ([byte[]]@()) "Binary"
    Set-Reg $unpinnedKey "Microsoft.QuickAction.ProjectL2" ([byte[]]@()) "Binary"

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" 1

    Log "Removing Bing Apps & Disabling Bing Search..."
    $bingApps = @(
        "*BingNews*", "*BingWeather*", "*BingFinance*", "*BingMaps*", 
        "*BingSports*", "*BingTravel*", "*BingFoodAndDrink*", "*BingHealthAndFitness*"
    )
    foreach ($app in $bingApps) {
        Get-AppxPackage $app | Remove-AppxPackage -ErrorAction SilentlyContinue
    }
    
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent" 0
    Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1

    Log "Applying Extended Privacy Registry Tweaks..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" "HasAccepted" 0
    Set-Reg "HKCU:\Software\Microsoft\Input\TIPC" "Enabled" 0
    Set-Reg "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 1
    Set-Reg "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 1
    Set-Reg "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore" "HarvestContacts" 0
    Set-Reg "HKCU:\Software\Microsoft\Personalization\Settings" "AcceptedPrivacyPolicy" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0
    Set-Reg "HKCU:\Software\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0
    try { Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "PeriodInNanoSeconds" -ErrorAction SilentlyContinue } catch {}

    Log "Disabling Diagnostic & Reporting Services..."
    foreach ($svc in @("diagtrack", "wermgr")) {
        if (Get-Service $svc -ErrorAction SilentlyContinue) {
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue | Out-Null
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
        }
    }

    Log "Enforcing Strict Data Collection Policies..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "Allow" "Deny" "String"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "SensorPermissionState" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" "Status" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" "AutoUpdateEnabled" 0

    Log "Removing Xbox Gaming Overlay..."
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            & winget uninstall 9nzkpstsnw4p --silent --accept-source-agreements | Out-Null
        }
        
        $xboxOverlay = Get-AppxPackage -Name Microsoft.XboxGamingOverlay -ErrorAction SilentlyContinue
        if ($xboxOverlay) {
            $xboxOverlay | Remove-AppxPackage -ErrorAction Stop
            Log "Successfully removed Xbox Gaming Overlay"
        } else {
            Log "Xbox Overlay not found (already uninstalled)."
        }
    } catch {
        Log "Xbox Overlay removal skipped: $($_.Exception.Message)"
    }

    Log "Disabling Windows Consumer Features..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1

    Log "Disabling Global Background Access..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1

    Log "Disabling Windows AI Features..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0
    Set-Reg "HKLM:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "AllowRecallEnablement" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableClickToDo" 1
    Set-Reg "HKLM:\Software\Microsoft\Windows\Shell\Copilot\BingChat" "IsUserEligible" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint" "DisableGenerativeFill" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint" "DisableCocreator" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint" "DisableImageCreator" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\WindowsNotepad" "DisableAIFeatures" 1

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" "TaskbarEndTask" 1

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP" "RomeSdkChannelUserAuthzPolicy" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP" "NearShareChannelUserAuthzPolicy" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP" "CdpSessionUserAuthzPolicy" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP" "DragTrayEnabled" 0

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableConsumerAccountStateContent" 1

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" "BackgroundType" 1

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "ShowGlobalPrompts" 0

    Set-Reg "HKLM:\SYSTEM\ControlSet001\Services\UCPD" "Start" 4

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" "RightCompanionToggledOpen" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start\Companions\Microsoft.YourPhone_8wekyb3d8bbwe" "IsEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start\Companions\Microsoft.YourPhone_8wekyb3d8bbwe" "IsAvailable" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" "IsResumeAllowed" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" "IsOneDriveResumeAllowed" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Connectivity\DisableCrossDeviceResume" "value" 1
    Set-Reg "HKLM:\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\1387020943" "EnabledState" 1
    Set-Reg "HKLM:\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\1694661260" "EnabledState" 1

    Set-Reg "HKCU:\Software\Microsoft\Lighting" "AmbientLightingEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Lighting" "ControlledByForegroundApp" 0

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "PromptOnSecureDesktop" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "EnableLUA" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "ConsentPromptBehaviorAdmin" 0

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" "AutoDownload" 2

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideSCAMeetNow" 1

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" "EnableFeeds" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackDocs" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "ShowFrequent" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDeviceSearchHistoryEnabled" 0

    Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String"

    Log "Enforcing Dark Theme..."
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "ColorPrevalence" 1
    
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" "AccentPalette" ([byte[]](0x95,0x95,0x95,0xff,0x8b,0x8b,0x8b,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0x00)) "Binary"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" "StartColorMenu" 0xff191919
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" "AccentColorMenu" 0xff191919
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "EnableWindowColorization" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "AccentColor" 0xff191919
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "ColorizationColor" 0xc4191919
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "ColorizationAfterglow" 0xc4191919

    Set-Reg "HKCU:\Control Panel\Desktop" "LogPixels" 0x60
    Set-Reg "HKCU:\Control Panel\Desktop" "Win8DpiScaling" 0
    Set-Reg "HKCU:\Control Panel\Desktop" "EnablePerProcessSystemDPI" 0
    try { Remove-Item -Path "HKCU:\Control Panel\Desktop\PerMonitorSettings" -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "AppliedDPI" 0x60

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0

    Set-Reg "HKCU:\Software\Microsoft\Multimedia\Audio" "UserDuckingPreference" 3

    Set-Reg "HKLM:\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation" "DisableStartupSound" 1

    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String"

    Set-Reg "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" "ShowLockOption" 0
    Set-Reg "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" "ShowSleepOption" 0

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 0

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xFFFFFFFF
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 3
    Set-Reg "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x90,0x32,0x07,0x80)) "Binary"
    Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" "String"

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "EnableAeroPeek" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "AlwaysHibernateThumbnails" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconsOnly" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 0
    Set-Reg "HKCU:\Control Panel\Desktop" "DragFullWindows" "0" "String"
    Set-Reg "HKCU:\Control Panel\Desktop" "FontSmoothing" "2" "String"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewShadow" 0

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 0x26

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 0

    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
    
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AudioEncodingBitrate" 0x1f400
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AudioCaptureEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "HistoricalCaptureEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "EchoCancellationEnabled" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "CursorCaptureEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKToggleGameBar" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKMToggleGameBar" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKSaveHistoricalVideo" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKMSaveHistoricalVideo" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKToggleRecording" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKMToggleRecording" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKTakeScreenshot" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKMTakeScreenshot" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKToggleRecordingIndicator" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKMToggleRecordingIndicator" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKToggleMicrophoneCapture" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKMToggleMicrophoneCapture" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKToggleCameraCapture" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKMToggleCameraCapture" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKToggleBroadcast" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "VKMToggleBroadcast" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "MicrophoneCaptureEnabled" 0

    Log "Enforcing Strict Privacy Settings..."
    $denyCaps = @(
        "location", "webcam", "userNotificationListener", "userAccountInformation", "contacts",
        "appointments", "phoneCall", "phoneCallHistory", "email", "userDataTasks", "chat",
        "radios", "bluetoothSync", "appDiagnostics", "documentsLibrary", "downloadsFolder",
        "musicLibrary", "picturesLibrary", "videosLibrary", "broadFileSystemAccess"
    )
    foreach ($cap in $denyCaps) {
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$cap" "Value" "Deny" "String"
    }

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessLocation" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessCamera" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsActivateWithVoice" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsActivateWithVoiceAboveLock" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessNotifications" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessAccountInfo" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessContacts" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessCalendar" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessPhone" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessCallHistory" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessEmail" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessTasks" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessMessaging" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessRadios" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessTrustedDevices" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsSyncWithDevices" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessSystemAIModels" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessHumanPresence" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessBackgroundSpatialPerception" 2

    Set-Reg "HKCU:\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps" "AgentActivationEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps" "AgentActivationLastUsed" 0

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessGazeInput" 2

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsGetDiagnosticInfo" 2

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessMotion" 2

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" 2

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BackgroundAppGlobalToggle" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1

    Set-Reg "HKCU:\Control Panel\International\User Profile" "HttpAcceptLanguageOptOut" 1

    Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\EdgeUI" "DisableMFUTracking" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "DisableMFUTracking" 1

    Set-Reg "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 1
    Set-Reg "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 1
    Set-Reg "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore" "HarvestContacts" 0
    Set-Reg "HKCU:\Software\Microsoft\Personalization\Settings" "AcceptedPrivacyPolicy" 0

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0
    try { Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "PeriodInNanoSeconds" -ErrorAction SilentlyContinue } catch {}

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "SafeSearchMode" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsAADCloudSearchEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsMSACloudSearchEnabled" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" "Enabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel" "Enabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.CapabilityAccess" "Enabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.StartupApp" "Enabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.SkyDrive.Desktop" "Enabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications" "EnableAccountNotifications" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.ScreenSketch_8wekyb3d8bbwe!App" "Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.Windows.InputSwitchToastHandler" "Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.AutoPlay" "Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.BackupReminder" "Enabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.LowDisk" "Enabled" 0

    $contentDelivery = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-Reg $contentDelivery "SubscribedContent-338389Enabled" 0
    Set-Reg $contentDelivery "SubscribedContent-338388Enabled" 0
    Set-Reg $contentDelivery "SubscribedContent-310093Enabled" 0
    Set-Reg $contentDelivery "SubscribedContent-338393Enabled" 0
    Set-Reg $contentDelivery "SubscribedContent-353694Enabled" 0
    Set-Reg $contentDelivery "SubscribedContent-353696Enabled" 0
    Set-Reg $contentDelivery "SubscribedContent-353698Enabled" 0
    Set-Reg $contentDelivery "SubscribedContent-338387Enabled" 0
    Set-Reg $contentDelivery "SubscribedContent-314563Enabled" 0
    Set-Reg $contentDelivery "SubscribedContent-314559Enabled" 0
    Set-Reg $contentDelivery "SystemPaneSuggestionsEnabled" 0
    Set-Reg $contentDelivery "OemPreInstalledAppsEnabled" 0
    Set-Reg $contentDelivery "PreInstalledAppsEnabled" 0
    Set-Reg $contentDelivery "SilentInstalledAppsEnabled" 0
    Set-Reg $contentDelivery "SoftLandingEnabled" 0
    Set-Reg $contentDelivery "ContentDeliveryAllowed" 0
    Set-Reg $contentDelivery "PreInstalledAppsEverEnabled" 0
    Set-Reg $contentDelivery "SubscribedContentEnabled" 0
    try { Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions" -Recurse -Force -ErrorAction SilentlyContinue } catch {}

    try { Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "*" -ErrorAction SilentlyContinue } catch {}
    try { Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "*" -ErrorAction SilentlyContinue } catch {}

    Set-Reg "HKCU:\SOFTWARE\Microsoft\ScreenMagnifier" "FollowCaret" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\ScreenMagnifier" "FollowNarrator" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\ScreenMagnifier" "FollowMouse" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\ScreenMagnifier" "FollowFocus" 0

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Narrator" "IntonationPause" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Narrator" "ReadHints" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Narrator" "ErrorNotificationType" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Narrator" "EchoChars" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Narrator" "EchoWords" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Narrator\NarratorHome" "MinimizeType" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Narrator\NarratorHome" "AutoStart" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Narrator\NoRoam" "EchoToggleKeys" 0
    Set-Reg "HKCU:\Software\Microsoft\Narrator\NoRoam" "DuckAudio" 0
    Set-Reg "HKCU:\Software\Microsoft\Narrator\NoRoam" "WinEnterLaunchEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Narrator\NoRoam" "ScriptingEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Narrator\NoRoam" "OnlineServicesEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Narrator" "NarratorCursorHighlight" 0
    Set-Reg "HKCU:\Software\Microsoft\Narrator" "CoupleNarratorCursorKeyboard" 0

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" "SearchOrderConfig" 0

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" "MaintenanceDisabled" 1

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "DisableAutomaticRestartSignOn" 1

    Set-Reg "HKLM:\SYSTEM\Maps" "AutoUpdateEnabled" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MultiTaskingAltTabFilter" 3

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1

    Set-Reg "HKCU:\Control Panel\Desktop" "WallPaper" "" "String"
    Set-Reg "HKCU:\Control Panel\Colors" "Background" "0 0 0" "String"

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0

    Set-Reg "HKCU:\Keyboard Layout\Toggle" "Language Hotkey" "3" "String"
    Set-Reg "HKCU:\Keyboard Layout\Toggle" "Hotkey" "3" "String"
    Set-Reg "HKCU:\Keyboard Layout\Toggle" "Layout Hotkey" "3" "String"
    Set-Reg "HKCU:\SOFTWARE\Microsoft\CTF\LangBar" "ShowStatus" 3

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "DisableLogonBackgroundImage" 1

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" "DisableAutoplay" 1

    Set-Reg "HKLM:\Software\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0
    Set-Reg "HKLM:\Software\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Installer" "DisableCoInstallers" 1

    Set-Reg "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell" "FolderType" "NotSpecified" "String"

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings" "EnabledState" 0

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate" 1

    Set-Reg "HKLM:\SOFTWARE\Microsoft\FTH" "Enabled" 0

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "MaxCachedIcons" "4096" "String"

    Set-Reg "HKLM:\System\CurrentControlSet\Control\CrashControl" "DisplayParameters" 1

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 1

    $psConsole = "HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe"
    Set-Reg $psConsole "ColorTable05" 0x00562401
    Set-Reg $psConsole "ColorTable06" 0x00f0edee
    Set-Reg $psConsole "FaceName" "Consolas" "String"
    Set-Reg $psConsole "FontFamily" 0x36
    Set-Reg $psConsole "FontWeight" 0x190
    Set-Reg $psConsole "PopupColors" 0x87
    Set-Reg $psConsole "ScreenColors" 0x06

    Set-Reg "HKLM:\SYSTEM\ControlSet001\Control\Session Manager" "DisableWpbtExecution" 1

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoWebServices" 1

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoRecentDocsHistory" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "ClearRecentDocsOnExit" 1

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoLowDiskSpaceChecks" 1

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoPublishingWizard" 1

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "SettingsPageVisibility" "hide:home;" "String"

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "EnableAutoTray" 0
    Set-Reg "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify" "SystemTrayChevronVisibility" 0

    Set-Reg "HKLM:\SOFTWARE\Microsoft\MdmCommon\SettingValues" "LocationSyncEnabled" 0

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CPSS\Store\TailoredExperiencesWithDiagnosticDataEnabled" "Value" 0

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "MaxTelemetryAllowed" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CPSS\Store\AllowTelemetry" "Value" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_IrisRecommendations" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_AccountNotifications" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start" "HideRecommendedSection" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Education" "IsEducationEnvironment" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedSection" 1

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" "AllAppsViewMode" 2

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "OpenFolderInNewTab" 0

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "SleepStudyDisabled" 1

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack" "Start" 4
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" "Start" 4

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SoftLandingEnabled" 0

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenOverlayEnabled" 0

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" "CdpSessionUserAuthzPolicy" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" "NearShareChannelUserAuthzPolicy" 0

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" "IsResumeAllowed" 0

    Log "Disabling New Outlook..."
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook\Preferences" "UseNewOutlook" 0
    Set-Reg "HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General" "HideNewOutlookToggle" 1
    Set-Reg "HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Options\General" "DoNewOutlookAutoMigration" 0
    Set-Reg "HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Preferences" "NewOutlookMigrationUserSetting" 0

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "ShowFrequent" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "ShowRecent" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "TelemetrySalt" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoRecentDocsHistory" 1

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "HistoryViewEnabled" 0

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "DeviceHistoryEnabled" 0

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0

    Log "Disabling Notifications..."
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\QuietHours" "Enabled" 0
    
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System" "AllowExperimentation" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\System\AllowExperimentation" "value" 0

    Log "Configuring Privacy Settings..."
    $capabilities = @(
        "activity", "appDiagnostics", "appointments", "bluetoothSync", "broadFileSystemAccess",
        "chat", "contacts", "documentsLibrary", "email", "gazeInput", "location",
        "phoneCall", "phoneCallHistory", "picturesLibrary", "radios", "userAccountInformation",
        "userDataTasks", "userNotificationListener", "videosLibrary"
    )
    
    foreach ($cap in $capabilities) {
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$cap" "Value" "Deny" "String"
    }

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" "Value" "Allow" "String"
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" "Value" "Allow" "String"

    Log "Preventing Preinstalled Apps..."
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "PreInstalledAppsEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "OemPreInstalledAppsEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "ContentDeliveryAllowed" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContentEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "PreInstalledAppsEverEnabled" 0

    Log "Disabling Windows Suggestions..."
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled" 0
    $subscribedContents = @(
        "SubscribedContent-338388Enabled", "SubscribedContent-314559Enabled", "SubscribedContent-280815Enabled",
        "SubscribedContent-314563Enabled", "SubscribedContent-338393Enabled", "SubscribedContent-353694Enabled",
        "SubscribedContent-353696Enabled", "SubscribedContent-310093Enabled", "SubscribedContent-202914Enabled",
        "SubscribedContent-338387Enabled", "SubscribedContent-338389Enabled", "SubscribedContent-353698Enabled"
    )
    foreach ($sc in $subscribedContents) {
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" $sc 0
    }

    Log "Disabling Common Startup Apps..."
    $startupApps = @{
        "Discord" = "0300000066AF9C7C5A46D901";
        "Synapse3" = "030000007DC437B0EA9FD901";
        "Spotify" = "0300000070E93D7B5A46D901";
        "EpicGamesLauncher" = "03000000F51C70A77A48D901";
        "RiotClient" = "03000000A0EA598A88B2D901";
        "Steam" = "03000000E7766B83316FD901"
    }
    foreach ($app in $startupApps.Keys) {
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" $app ([byte[]]($startupApps[$app] -split '(.{2})' | Where-Object {$_} | ForEach-Object { [Convert]::ToByte($_, 16) })) "Binary"
    }

    Log "Disabling Setting Synchronization..."
    $syncGroups = @(
        "Accessibility", "AppSync", "BrowserSettings", "Credentials", "DesktopTheme",
        "Language", "PackageState", "Personalization", "StartLayout", "Windows"
    )
    foreach ($group in $syncGroups) {
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\$group" "Enabled" 0
    }

    Log "Disabling Windows Crash Reporting..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "Disabled" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "DoReport" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "LoggingDisabled" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\PCHealth\ErrorReporting" "DoReport" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" "Disabled" 1

    if ($EnableDisableTelemetry) {
    Log "Disabling Telemetry Tasks..."
    $tasks = @(
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\BthSQM",
        "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\Customer Experience Improvement Program\Uploader",
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\StartupAppTask",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver",
        "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
        "\Microsoft\Windows\Shell\FamilySafetyMonitor",
        "\Microsoft\Windows\Shell\FamilySafetyRefresh",
        "\Microsoft\Windows\Shell\FamilySafetyUpload",
        "\Microsoft\Windows\Autochk\Proxy",
        "\Microsoft\Windows\Maintenance\WinSAT",
        "\Microsoft\Windows\Application Experience\AitAgent",
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
        "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask",
        "\Microsoft\Windows\DiskFootprint\Diagnostics",
        "\Microsoft\Windows\FileHistory\File History (maintenance mode)",
        "\Microsoft\Windows\PI\Sqm-Tasks",
        "\Microsoft\Windows\NetTrace\GatherNetworkInfo",
        "\Microsoft\Windows\AppID\SmartScreenSpecific",
        "\Microsoft\Office\OfficeTelemetryAgentFallBack2016",
        "\Microsoft\Office\OfficeTelemetryAgentLogOn2016",
        "\Microsoft\Office\OfficeTelemetryAgentLogOn",
        "\Microsoftd\Office\OfficeTelemetryAgentFallBack",
        "\Microsoft\Office\Office 15 Subscription Heartbeat",
        "\Microsoft\Windows\Time Synchronization\ForceSynchronizeTime",
        "\Microsoft\Windows\Time Synchronization\SynchronizeTime",
        "\Microsoft\Windows\WindowsUpdate\Automatic App Update",
        "\Microsoft\Windows\Device Information\Device"
    )
    foreach ($task in $tasks) {
        Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
    }

    Log "Disabling Telemetry Registry Keys..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" "PreventDeviceMetadataFromNetwork" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 1
    Set-Reg "HKCU:\SOFTWARE\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 1
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Permissions\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" "SensorPermissionState" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" "SensorPermissionState" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WUDF" "LogEnable" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WUDF" "LogLevel" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowCommercialDataPipeline" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowDeviceNameInTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "LimitEnhancedDiagnosticDataWindowsAnalytics" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "MicrosoftEdgeDataOptIn" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" "PeriodInNanoSeconds" 0
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Assistance\Client\1.0" "NoExplicitFeedback" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Assistance\Client\1.0" "NoActiveHelp" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableUAR" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" "PreventHandwritingDataSharing" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" "DoSvc" 3
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocationScripting" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableSensors" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableWindowsLocationProvider" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\DeviceHealthAttestationService" "DisableSendGenericDriverNotFoundToWER" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings" "DisableSendGenericDriverNotFoundToWER" 1
    Set-Reg "HKLM:\SYSTEM\DriverDatabase\Policies\Settings" "DisableSendGenericDriverNotFoundToWER" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" "CEIPEnable" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\SQMClient\Reliability" "CEIPEnable" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\SQMClient\Reliability" "SqmLoggerRunning" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\SQMClient\Windows" "CEIPEnable" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\SQMClient\Windows" "DisableOptinExperience" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\SQMClient\Windows" "SqmLoggerRunning" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\SQMClient\IE" "SqmLoggerRunning" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" "PreventHandwritingErrorReports" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\FileHistory" "Disabled" 1
    Set-Reg "HKCU:\SOFTWARE\Microsoft\MediaPlayer\Preferences" "UsageTracking" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableSoftLanding" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Peernet" "Disabled" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" "value" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" "HarvestContacts" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\MRT" "DontOfferThroughWUAU" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Biometrics" "Enabled" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" "Start" 4
    Set-Reg "HKLM:\SYSTEM\DriverDatabase\Policies\Settings" "DisableSendGenericDriverNotFoundToWER" 1
    Set-Reg "HKCU:\Control Panel\International\User Profile" "HttpAcceptLanguageOptOut" 1

    Log "Disabling AutoLoggers..."
    $autoLoggersList = @(
        "AppModel", "Cellcore", "Circular Kernel Context Logger", "CloudExperienceHostOobe", "DataMarket",
        "DefenderApiLogger", "DefenderAuditLogger", "DiagLog", "HolographicDevice", "iclsClient", "iclsProxy",
        "LwtNetLog", "Mellanox-Kernel", "Microsoft-Windows-AssignedAccess-Trace", "Microsoft-Windows-Setup",
        "NBSMBLOGGER", "PEAuthLog", "RdrLog", "ReadyBoot", "SetupPlatform", "SetupPlatformTel", "SocketHeciServer",
        "SpoolerLogger", "SQMLogger", "TCPIPLOGGER", "TileStore", "Tpm", "TPMProvisioningService", "UBPM",
        "WdiContextLog", "WFP-IPsec Trace", "WiFiDriverIHVSession", "WiFiDriverIHVSessionRepro", "WiFiSession",
        "WinPhoneCritical"
    )
    foreach ($autoLogName in $autoLoggersList) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$autoLogName" "Start" 0
    }
    
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WUDF" "LogEnable" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WUDF" "LogLevel" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableThirdPartySuggestions" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp" "DebugLogLevel" 0

    Log "Disabling Telemetry Services..."
    $services = @("DiagTrack", "dmwappushservice", "diagnosticshub.standardcollector.service")
    foreach ($svc in $services) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
        Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue | Out-Null
    }
    }

    Log "Aggressively Removing OneDrive..."
    try {
        Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
        $oneDrivePaths = @(
            "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
            "$env:SystemRoot\System32\OneDriveSetup.exe"
        )
        foreach ($p in $oneDrivePaths) {
            if (Test-Path $p) { Start-Process $p "/uninstall" -NoNewWindow -Wait }
        }
        Remove-Item -Path "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:ProgramData\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1
    } catch {}

    Log "Aggressively Disabling Microsoft Edge..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate" "InstallDefault" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate" "Install{56EB18F8-8008-4784-8B02-0901D2D05090}" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "HubsFree" 1
    
    Log "Disabling Print Spooler (Deep)..."
    Stop-Service -Name "Spooler" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Set-Service -Name "Spooler" -StartupType Disabled -ErrorAction SilentlyContinue
    $printSvcs = @("PrintNotify", "Fax")
    foreach ($svc in $printSvcs) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
    }

    Log "Disabling Distributed Link Tracking..."
    Stop-Service -Name "TrkWks" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Set-Service -Name "TrkWks" -StartupType Disabled -ErrorAction SilentlyContinue

    $edgeServices = @("MicrosoftEdgeElevationService", "edgeupdate", "edgeupdatem")
    foreach ($svc in $edgeServices) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
    }

    Log "Aggressively Removing Telemetry and Reporting..."
    $telemetryServices = @("DiagTrack", "dmwappushservice", "WerSvc", "WbioSrvc")
    foreach ($svc in $telemetryServices) {
        try {
            $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($service) {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" "Start" 4
            }
        } catch {}
    }
    
    $werPath = "$env:PROGRAMDATA\Microsoft\Windows\WER"
    if (Test-Path $werPath) { Remove-Item -Path "$werPath\*" -Recurse -Force -ErrorAction SilentlyContinue }

    if ($EnableRemoveAppx) {
        Log "Removing Unnecessary Appx Packages..."
        $bloatPkgs = @(
            "*3DBuilder*", "*549981C3F5F10*", "*BingFinance*", "*BingFoodAndDrink*", "*BingHealthAndFitness*", 
            "*BingNews*", "*BingSports*", "*BingTranslator*", "*BingTravel*", "*BingWeather*", "*Clipchamp*", 
            "*Copilot*", "*Windows.AIHub*", "*PCManager*", "*Getstarted*", "*Messaging*", "*Microsoft3DViewer*", 
            "*MicrosoftJournal*", "*MicrosoftOfficeHub*", "*MicrosoftPowerBIForWindows*", "*MicrosoftSolitaireCollection*", 
            "*MicrosoftStickyNotes*", "*MixedReality.Portal*", "*NetworkSpeedTest*", "*Microsoft.News*", "*Office.OneNote*", 
            "*Office.Sway*", "*OneConnect*", "*Print3D*", "*PowerAutomateDesktop*", "*SkypeApp*", "*Todos*", 
            "*Windows.DevHome*", "*WindowsAlarms*", "*WindowsFeedbackHub*", "*WindowsMaps*", "*WindowsSoundRecorder*", 
            "*XboxApp*", "*ZuneVideo*", "*MicrosoftFamily*", "*QuickAssist*", "*MicrosoftTeams*", "*MSTeams*", 
            "*People*", "*WindowsPhone*", "*windowscommunicationsapps*", "*zune*", "*StartExperiencesApp*",

            "*ACGMediaPlayer*", "*ActiproSoftwareLLC*", "*AdobePhotoshopExpress*", "*Amazon*", "*PrimeVideo*", 
            "*Asphalt8Airborne*", "*AutodeskSketchBook*", "*CaesarsSlotsFreeCasino*", "*COOKINGFEVER*", 
            "*CyberLinkMediaSuiteEssentials*", "*DisneyMagicKingdoms*", "*Disney*", "*DrawboardPDF*", 
            "*Duolingo*", "*EclipseManager*", "*Facebook*", "*FarmVille2CountryEscape*", "*fitbit*", 
            "*Flipboard*", "*HiddenCity*", "*HULUPLUS*", "*iHeartRadio*", "*Instagram*", "*BubbleWitch3Saga*", 
            "*CandyCrushSaga*", "*CandyCrushSodaSaga*", "*LinkedIn*", "*MarchofEmpires*", "*Netflix*", 
            "*NYTCrossword*", "*OneCalendar*", "*Pandora*", "*PhototasticCollage*", "*PicsArt*", "*Plex*", 
            "*PolarrPhotoEditor*", "*Royal Revolt*", "*Shazam*", "*LiveWallpaper*", "*SlingTV*", "*Spotify*", 
            "*TikTok*", "*TuneInRadio*", "*Twitter*", "*Viber*", "*WinZipUniversal*", "*Wunderlist*", "*XING*"
        )

        $count = 0
        foreach ($pkg in $bloatPkgs) {
            $count++
            if (Get-Command Write-ProgressBar -ErrorAction SilentlyContinue) {
                Write-ProgressBar -Current $count -Total $bloatPkgs.Count -Status "Removing $pkg"
            }
            try {
                Get-AppxPackage -Name $pkg -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Out-Null
                
                Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "$pkg" } | Remove-AppxProvisionedPackage -Online -AllUsers -ErrorAction SilentlyContinue | Out-Null
            } catch { }
        }
    }

    Log "Removing Unnecessary Appx Packages..."
    $appxToRemove = @(
        "Microsoft.BingWeather",
        "Microsoft.BingNews",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.Messaging",
        "Microsoft.Microsoft3DViewer",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.MixedReality.Portal",
        "Microsoft.OneConnect",
        "Microsoft.People",
        "Microsoft.Print3D",
        "Microsoft.SkypeApp",
        "Microsoft.Todos",
        "Microsoft.WindowsAlarms",
        "Microsoft.WindowsCamera",
        "microsoft.windowscommunicationsapps",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.Xbox.TCUI",
        "Microsoft.XboxApp",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.YourPhone",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo"
    )
    foreach ($app in $appxToRemove) {
        Get-AppxPackage -AllUsers -Name $app -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
    }

    if ($EnableDisableServices) {
        Log "Disabling Unnecessary Services..."
        $unnecessaryServices = @(
            "TapiSrv", "FontCache3.0.0.0", "WpcMonSvc", "SEMgrSvc", "PNRPsvc", "LanmanWorkstation",
            "WEPHOSTSVC", "p2psvc", "p2pimsvc", "PhoneSvc", "wuauserv", "Wecsvc", "SensorDataService",
            "SensrSvc", "perceptionsimulation", "StiSvc", "OneSyncSvc", "WMPNetworkSvc", "autotimesvc",
            "edgeupdatem", "MicrosoftEdgeElevationService", "ALG", "QWAVE", "IpxlatCfgSvc", "icssvc",
            "DusmSvc", "MapsBroker", "edgeupdate", "SensorService", "shpamsvc", "svsvc", "SysMain",
            "MSiSCSI", "Netlogon", "CscService", "ssh-agent", "AppReadiness", "tzautoupdate", "NfsClnt",
            "wisvc", "defragsvc", "SharedRealitySvc", "RetailDemo", "lltdsvc", "TrkWks", "CryptSvc",
            "diagsvc", "DPS", "WdiServiceHost", "WdiSystemHost", "TroubleshootingSvc", "DsSvc",
            "FrameServer", "FontCache", "InstallService", "OSRSS", "sedsvc", "SENS", "TabletInputService",
            "Themes", "ConsentUxUserSvc", "DevicePickerUserSvc", "UnistoreSvc", "DevicesFlowUserSvc",
            "MessagingService", "CDPUserSvc", "PimIndexMaintenanceSvc", "BcastDVRUserService", "UserDataSvc",
            "DeviceAssociationBrokerSvc", "cbdhsvc", "CaptureService", "lfsvc", "SecurityHealthService",
            "RemoteRegistry", "Spooler", "WSearch", "MapsBroker", "NetTcpPortSharing", "TrkWks",
            "dmwappushsvc", "diagnosticshub.standardcollector.service",
            "Fax", "PrintWorkflowUserSvc", "PrintNotify", "RmSvc", "AssignedAccessManagerSvc", 
            "SCardSvr", "ScDeviceEnum", "SCPolicySvc", "WbioSrvc", "WalletService", "whesvc", 
            "wuqisvc", "WSAIFabricSvc", "DoSvc"
        )
        $count = 0
        foreach ($svc in $unnecessaryServices) {
            $count++
            if (Get-Command Write-ProgressBar -ErrorAction SilentlyContinue) {
                Write-ProgressBar -Current $count -Total $unnecessaryServices.Count -Status "Disabling $svc"
            }
            try {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue | Out-Null
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" "Start" 4
            } catch { }
        }
        
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" "AllowPrelaunch" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader" "AllowTabPreloading" 0
    }
    
    Log "Aggressively Removing Microsoft Edge..."
    try {
        Set-Reg "HKLM:\SOFTWARE\Microsoft\EdgeUpdateDev" "" "" "String"
        Set-Reg "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev" "AllowUninstall" 1
        
        $edgeStub = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
        if (-not (Test-Path $edgeStub)) { New-Item -Path $edgeStub -ItemType Directory -Force | Out-Null }
        if (-not (Test-Path "$edgeStub\MicrosoftEdge.exe")) { New-Item -Path "$edgeStub\MicrosoftEdge.exe" -ItemType File -Force | Out-Null }

        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate" "DoNotUpdateToEdgeWithChromium" 1
        Set-Reg "HKLM:\SOFTWARE\Microsoft\EdgeUpdate" "DoNotUpdateToEdgeWithChromium" 1
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate" "InstallDefault" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate" "Install{56EB18F8-8008-4784-8B02-0901D2D05090}" 0
        
        $edgeServices = @("MicrosoftEdgeElevationService", "edgeupdate", "edgeupdatem")
        foreach ($svc in $edgeServices) {
            if (Get-Service $svc -ErrorAction SilentlyContinue) {
                Stop-Service $svc -Force -ErrorAction SilentlyContinue
                Set-Service $svc -StartupType Disabled -ErrorAction SilentlyContinue
            }
        }
        
        $uninstallString = $null
        $uninstallKey = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" -ErrorAction SilentlyContinue
        if ($uninstallKey -and $uninstallKey.UninstallString) {
             $uninstallString = $uninstallKey.UninstallString
        } else {
             $progFiles = ${env:ProgramFiles(x86)}
             $edgeSetupPattern = Join-Path $progFiles "Microsoft\Edge\Application\*\Installer\setup.exe"
             $edgeInstaller = Get-Item $edgeSetupPattern -ErrorAction SilentlyContinue | Select-Object -First 1
             if ($edgeInstaller) { $uninstallString = "`"$($edgeInstaller.FullName)`"" }
        }

        if ($uninstallString) {
             Log "Running Edge Uninstaller..."
             $args = "--uninstall --system-level --verbose-logging --force-uninstall"
             Start-Process -FilePath $uninstallString -ArgumentList $args -Wait -NoNewWindow -ErrorAction SilentlyContinue
        }
        
        Get-Process -Name "msedge", "MicrosoftEdgeUpdate", "msedgewebview2" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        
        $edgePaths = @(
            "$env:LOCALAPPDATA\Microsoft\Edge",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
            "$env:PUBLIC\Desktop\Microsoft Edge.lnk",
            "$env:USERPROFILE\Desktop\Microsoft Edge.lnk",
            "$([Environment]::GetFolderPath('CommonStartMenu'))\Microsoft Edge.lnk",
            "$([Environment]::GetFolderPath('CommonPrograms'))\Microsoft Edge.lnk",
            "$edgeStub"
        )
        foreach ($path in $edgePaths) {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        try {
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "MicrosoftEdgeAutoLaunch_*" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Microsoft Edge Update" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "MicrosoftEdgeAutoLaunch_*" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" -Name "MicrosoftEdgeAutoLaunch_*" -ErrorAction SilentlyContinue
        } catch {}

        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.MicrosoftEdge_8wekyb3d8bbwe" "Active" 0

        Log "Edge removal process completed."
    } catch {
        Log "Edge removal failed or skipped: $($_.Exception.Message)"
    }

    Log "Configuring Focus Assist..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_TOASTS_ENABLED" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" 0

    Log "Applying Confidentiality & Privacy Tweaks..."

    if ($EnableDisableAdvertising) {
        Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
        Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Bluetooth" "AllowAdvertising" 0
    }

    $syncKeys = @("Accessibility", "BrowserSettings", "Credentials", "Language", "Personalization", "Windows")
    foreach ($k in $syncKeys) {
        Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SettingSync\Groups\$k" "Enabled" 0
    }

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Diagtrack-Listener" "Start" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" "SaveZoneInformation" 1

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1

    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowDeviceNameInTelemetry" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" "PreventHandwritingDataSharing" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" "PreventHandwritingErrorReports" 1
    Set-Reg "HKCU:\Software\Microsoft\Input\TIPC" "Enabled" 0

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" "CEIPEnable" 0
    try { Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient" -Recurse -Force -ErrorAction SilentlyContinue } catch {}

    if ($EnableDisableLocation) {
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 1
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocationScripting" 1
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableWindowsLocationProvider" 1
    }

    Set-Reg "HKCU:\Software\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0
    Set-Reg "HKCU:\Software\Microsoft\Siuf\Rules" "PeriodInNanoSeconds" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Speech" "AllowSpeechModelUpdate" 0

    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc" "Start" 4

    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System" "AllowExperimentation" 0

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableUAR" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreenCamera" 1

    Set-Reg "HKLM:\SYSTEM\Maps" "MapUpdate" 0
    Set-Reg "HKLM:\SYSTEM\Maps" "AutoUpdateEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Maps" "AutoDownloadAndUpdateMapData" 0

    if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\Telemetry") {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Telemetry" "Start" 4
    }

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" "AllowPrelaunch" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader" "AllowTabPreloading" 0

    if ($EnableRemoveCortana) {
        Log "Removing Cortana..."
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCloudSearch" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortanaAboveLock" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowSearchToUseLocation" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWebOverMeteredConnections" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 0
        Get-AppxPackage -AllUsers *Microsoft.549981C3F5F10* | Remove-AppxPackage -ErrorAction SilentlyContinue
    }

    if ($EnableRemoveOneDrive) {
    Log "Removing OneDrive..."
    try {
        $onedriveSetup = "$env:SYSTEMROOT\SYSWOW64\ONEDRIVESETUP.EXE"
        if (Test-Path $onedriveSetup) { Start-Process -FilePath $onedriveSetup -ArgumentList "/UNINSTALL" -Wait }
        Remove-Item -Path "C:\OneDriveTemp" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:PROGRAMDATA\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        
        Set-Reg "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}\ShellFolder" "Attributes" 0
        Set-Reg "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}\ShellFolder" "Attributes" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSync" 1
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableMeteredNetworkFileSync" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableLibrariesDefaultSaveToOneDrive" 0
    } catch {
        Log "Error removing OneDrive: $_"
    }
    }

    Log "Cleaning System Files..."
    $cleanupPaths = @(
        "C:\Windows\Temp",
        "C:\Windows\Prefetch",
        "$env:TEMP",
        "$env:SystemDrive\*.tmp",
        "$env:SystemDrive\*.log",
        "$env:SystemDrive\*.chk",
        "$env:SystemDrive\$Recycle.Bin",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"
    )
    foreach ($path in $cleanupPaths) {
        if ($path -like "*\*") {
             Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item -Path "$env:SystemRoot\Logs\CBS\CBS.log" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:SystemRoot\Logs\DISM\DISM.log" -Force -ErrorAction SilentlyContinue

    Log "Applying Brave browser debloat settings..."
    $braveProfiles = @(
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Preferences",
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Secure Preferences"
    )
    foreach ($bravePrefPath in $braveProfiles) {
        try {
            if (Test-Path $bravePrefPath) {
                $raw = Get-Content -Path $bravePrefPath -Raw -ErrorAction SilentlyContinue
                if ($raw) {
                    $json = $raw | ConvertFrom-Json -ErrorAction Stop
                    if (-not $json.brave) { $json | Add-Member -NotePropertyName "brave" -NotePropertyValue (@{}) }
                    if (-not $json.brave.ai_chat) { $json.brave | Add-Member -NotePropertyName "ai_chat" -NotePropertyValue (@{}) -Force }
                    if (-not $json.brave.wallet) { $json.brave | Add-Member -NotePropertyName "wallet" -NotePropertyValue (@{}) -Force }
                    if (-not $json.brave.news) { $json.brave | Add-Member -NotePropertyName "news" -NotePropertyValue (@{}) -Force }
                    if (-not $json.brave.today) { $json.brave | Add-Member -NotePropertyName "today" -NotePropertyValue (@{}) -Force }
                    
                    try { $json.brave.ai_chat.enabled = $false } catch {}
                    try { $json.brave.wallet.enabled = $false } catch {}
                    try { $json.brave.news.opted_in = $false } catch {}
                    try { $json.brave.today.opted_in = $false } catch {}
                    
                    ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $bravePrefPath -Encoding UTF8 -Force
                    Log "Updated Brave preferences at $bravePrefPath"
                }
            }
        } catch {
            Log "Brave debloat skipped for ${bravePrefPath}: $_"
        }
    }

    Log "Blocking Razer Software..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" "SearchOrderConfig" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Installer" "DisableCoInstallers" 1
    try {
        $RazerPath = "C:\Windows\Installer\Razer"
        if (Test-Path $RazerPath) { Remove-Item $RazerPath -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -Path $RazerPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        $acl = Get-Acl $RazerPath
        $denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Write", "Deny")
        $acl.AddAccessRule($denyRule)
        Set-Acl -Path $RazerPath -AclObject $acl
    } catch {
        Log "Failed to block Razer path: $_"
    }

    Log "Blocking Adobe Telemetry (Hosts)..."
    try {
        $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
        $adobeHostsUrl = "https://github.com/Ruddernation-Designs/Adobe-URL-Block-List/raw/refs/heads/master/hosts"
        $adobeBlockList = Invoke-WebRequest -Uri $adobeHostsUrl -UseBasicParsing -ErrorAction SilentlyContinue
        if ($adobeBlockList.Content) {
            Add-Content -Path $hostsPath -Value "`n# Adobe Block List" -ErrorAction SilentlyContinue
            Add-Content -Path $hostsPath -Value $adobeBlockList.Content -ErrorAction SilentlyContinue
            Log "Added Adobe Block List to Hosts file."
        }
    } catch {
        Log "Failed to apply Adobe Block List: $_"
    }

    Log "Debloat tweaks applied."

    Log "Applying GTweak Confidentiality settings..."

    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Bluetooth" "AllowAdvertising" 0

    $syncGroups = @(
        "Accessibility", "BrowserSettings", "Credentials", "Language", "Personalization", "Windows"
    )
    foreach ($group in $syncGroups) {
        Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SettingSync\Groups\$group" "Enabled" 0
    }

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" "PreventHandwritingDataSharing" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" "PreventHandwritingErrorReports" 1
    Set-Reg "HKCU:\Software\Microsoft\Input\TIPC" "Enabled" 0

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocationScripting" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableWindowsLocationProvider" 1

    Set-Reg "HKCU:\Software\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Speech" "AllowSpeechModelUpdate" 0

    Set-Reg "HKLM:\SYSTEM\Maps" "AutoUpdateEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Maps" "AutoDownloadAndUpdateMapData" 0
    Set-Reg "HKLM:\SYSTEM\Maps" "MapUpdate" 0

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowDeviceNameInTelemetry" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" "CEIPEnable" 0

    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System" "AllowExperimentation" 0

    Log "Applying optimizerNXT Privacy tweaks..."

    Set-Reg "HKLM:\SOFTWARE\Policies\Google\Chrome" "MetricsReportingEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Google\Chrome" "ChromeCleanupReportingEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Google\Chrome" "UserFeedbackAllowed" 0

    Set-Reg "HKLM:\SOFTWARE\Policies\Mozilla\Firefox" "DisableTelemetry" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Mozilla\Firefox" "DisableDefaultBrowserAgent" 1
    try {
        Unregister-ScheduledTask -TaskName "\Mozilla\Firefox Default Browser Agent*" -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}

    Set-Reg "HKCU:\SOFTWARE\Microsoft\Office\Common\ClientTelemetry" "DisableTelemetry" 1
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\ClientTelemetry" "DisableTelemetry" 1
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Office\16.0\OSM\PreventedSolutionTypes" "agave" 1
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Office\16.0\OSM\PreventedSolutionTypes" "appaddins" 1
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Office\16.0\OSM\PreventedSolutionTypes" "comaddins" 1
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Office\16.0\OSM\PreventedSolutionTypes" "documentfiles" 1
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Office\16.0\OSM\PreventedSolutionTypes" "templatefiles" 1

    Set-Reg "HKCU:\Software\Microsoft\VisualStudio\Telemetry" "TurnOffSwitch" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\VisualStudio\Feedback" "DisableFeedbackDialog" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\VisualStudio\SQM" "OptIn" 0

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "DisableAutomaticRestartSignOn" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" "PreventHandwritingDataSharing" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\TextInput" "AllowLinguisticDataCollection" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization" "AllowInputPersonalization" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "SafeSearchMode" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Biometrics" "Enabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Connect" "AllowProjectionToPC" 0

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" "AllowWindowsInkWorkspace" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" "AllowSuggestedAppsInWindowsInkWorkspace" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\TabletTip\1.7" "EnableInkingWithTouch" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\TabletTip\1.7" "EnableAutocorrection" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\TabletTip\1.7" "EnableSpellchecking" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\TabletTip\1.7" "EnableDoubleTapSpace" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\TabletTip\1.7" "EnablePredictionSpaceInsertion" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\TabletTip\1.7" "EnableTextPrediction" 0
    Set-Reg "HKCU:\Software\Microsoft\Input\Settings" "InsightsEnabled" 0

    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\OneDrive" "PreventNetworkTrafficPreUserSignIn" 1
    try {
        Unregister-ScheduledTask -TaskName "OneDrive Standalone Update Task*" -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}

    Log "Debloat tweaks applied."
}
Export-ModuleMember -Function Remove-Bloatware

function Invoke-UltimateCleanup {
    param(
        [Action[string]]$Logger
    )

    function Log($msg) { if ($Logger) { $Logger.Invoke($msg) } else { Write-Host $msg } }

    Log "Starting Ultimate Cleanup..."

    # Clear Event Viewer Logs
    Log "Clearing Event Viewer Logs..."
    try {
        wevtutil el | Foreach-Object { wevtutil cl "$_" >$null 2>&1 }
    } catch {
        Log "Error clearing Event Viewer logs: $_"
    }

    # Clear Windows Log Files
    Log "Clearing Windows Log Files..."
    $logFiles = @(
        "$env:SystemRoot\DtcInstall.log",
        "$env:SystemRoot\comsetup.log",
        "$env:SystemRoot\PFRO.log",
        "$env:SystemRoot\setupact.log",
        "$env:SystemRoot\setuperr.log",
        "$env:SystemRoot\setupapi.log",
        "$env:SystemRoot\inf\setupapi.app.log",
        "$env:SystemRoot\inf\setupapi.dev.log",
        "$env:SystemRoot\inf\setupapi.offline.log",
        "$env:SystemRoot\Performance\WinSAT\winsat.log",
        "$env:SystemRoot\debug\PASSWD.LOG",
        "$env:SystemRoot\System32\catroot2\dberr.txt",
        "$env:SystemRoot\System32\catroot2.log",
        "$env:SystemRoot\System32\catroot2.jrs",
        "$env:SystemRoot\System32\catroot2.edb",
        "$env:SystemRoot\System32\catroot2.chk"
    )

    foreach ($file in $logFiles) {
        if (Test-Path $file) {
            Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
        }
    }

    $logDirs = @(
        "$env:SystemRoot\Panther\*",
        "$env:SystemRoot\Logs\CBS\*",
        "$env:SystemRoot\Logs\DISM\*",
        "$env:SystemRoot\Logs\SIH\*",
        "$env:LocalAppData\Microsoft\CLR_v4.0\UsageTraces\*",
        "$env:LocalAppData\Microsoft\CLR_v4.0_32\UsageTraces\*",
        "$env:SystemRoot\Logs\NetSetup\*",
        "$env:SystemRoot\System32\LogFiles\setupcln\*",
        "$env:SystemRoot\Temp\CBS\*",
        "$env:SystemRoot\Traces\WindowsUpdate\*"
    )

    foreach ($dir in $logDirs) {
        Remove-Item -Path $dir -Force -Recurse -ErrorAction SilentlyContinue
    }

    # Clear Windows Update Medic Service logs (requires permissions)
    try {
        $waasPath = "$env:SystemRoot\Logs\waasmedic"
        if (Test-Path $waasPath) {
            takeown /f $waasPath /r /d Y *>$null
            icacls $waasPath /grant *S-1-5-32-544:F /t *>$null
            Remove-Item -Path $waasPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {}

    # Clear TEMP Files
    Log "Clearing TEMP Files..."
    $tempDirs = @(
        "C:\Windows\Temp",
        $env:TEMP
    )
    foreach ($tempDir in $tempDirs) {
        if (Test-Path $tempDir) {
            Get-ChildItem -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Clean Nvidia Cache
    Log "Cleaning Nvidia Cache..."
    $nvidiaDirs = @(
        "$env:LocalAppData\NVIDIA\GLCache",
        "$env:USERPROFILE\AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache"
    )
    foreach ($dir in $nvidiaDirs) {
        if (Test-Path $dir) {
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Remove Windows.old
    if (Test-Path "$env:SystemDrive\Windows.old") {
        Log "Removing Windows.old Folder..."
        try {
            takeown /f "$env:SystemDrive\Windows.old" /r /d Y *>$null
            icacls "$env:SystemDrive\Windows.old" /grant *S-1-5-32-544:F /t *>$null
            Remove-Item -Path "$env:SystemDrive\Windows.old" -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Log "Failed to remove Windows.old: $_"
        }
    }

    Log "Ultimate Cleanup Completed."
}
Export-ModuleMember -Function Invoke-UltimateCleanup
