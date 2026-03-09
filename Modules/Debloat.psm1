# Debloat Module
function Remove-Bloatware {
    param([Action[string]]$Logger)
    
    function Log($msg) { if ($Logger) { $Logger.Invoke($msg) } else { Write-Host $msg } }

    Log "Starting Privacy & Debloat tweaks..."

    # Ensure Appx module is available
    if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
        Log "Warning: Get-AppxPackage not found. Attempting to load Appx module..."
        Import-Module Appx -ErrorAction SilentlyContinue
    }

    if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        Log "Warning: Get-ScheduledTask not found. Attempting to load ScheduledTasks module..."
        Import-Module ScheduledTasks -Force -ErrorAction SilentlyContinue
    }

    # Helper to set registry key safely
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

    # Disable Windows Remediation
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RemediationRequired" 0

    # Windows 11: Disable Widgets
    Log "Disabling Windows 11 Widgets..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0

    # Windows 11: Disable Chat / Teams
    Log "Disabling Windows Chat/Teams..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" "ChatIcon" 3
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0

    # Windows 11: Snap Layouts (Reduce Delay)
    Log "Optimizing Snap Layouts..."
    Set-Reg "HKCU:\Control Panel\Desktop" "SnapSizing" 0 # Simplifies visual feedback

    # Restore Classic Context Menu
    Log "Restoring Classic Context Menu..."
    Set-Reg "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" "" "" "String"

    # Disable Suggested Actions
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SmartActionPlatform\SmartClipboard" "Disabled" 1

    # Disable Search Highlights
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDynamicSearchBoxEnabled" 0

    # Disable Storage Sense
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense" "AllowStorageSenseGlobal" 0

    # Leftmost Taskbar
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0

    # Enable Action Center
    try { Remove-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" -ErrorAction SilentlyContinue } catch {}

    # Disable Snap Layout
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapBar" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapAssistFlyout" 0

    # Remove Gallery Shortcut
    try { Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" -Recurse -Force -ErrorAction SilentlyContinue } catch {}

    # Remove Home Shortcut
    try { Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" -Recurse -Force -ErrorAction SilentlyContinue } catch {}

    # Open File Explorer to This PC
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "HubMode" 1

    # Disable Win 11 System Requirements
    Set-Reg "HKCU:\Control Panel\UnsupportedHardwareNotificationCache" "SV2" 0
    Set-Reg "HKLM:\SYSTEM\Setup\LabConfig" "BypassCPUCheck" 1
    Set-Reg "HKLM:\SYSTEM\Setup\LabConfig" "BypassRAMCheck" 1
    Set-Reg "HKLM:\SYSTEM\Setup\LabConfig" "BypassSecureBootCheck" 1
    Set-Reg "HKLM:\SYSTEM\Setup\LabConfig" "BypassStorageCheck" 1
    Set-Reg "HKLM:\SYSTEM\Setup\LabConfig" "BypassTPMCheck" 1
    Set-Reg "HKLM:\SYSTEM\Setup\MoSetup" "AllowUpgradesWithUnsupportedTPMOrCPU" 1

    # Show More Pins
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_Layout" 1

    # Disable Show Recently Added Apps & Recommendations
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" "ShowRecentList" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideRecentlyAddedApps" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoInstrumentation" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoStartMenuMFUprogramsList" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoRecentDocsHistory" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "ShowOrHideMostUsedApps" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecentlyAddedApps" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedPersonalizedSites" 1

    # Disable AI Insights
    Set-Reg "HKCU:\Software\Microsoft\input\Settings" "InsightsEnabled" 0

    # Remove Pinned Items in Network/Sound Flyout
    $unpinnedKey = "HKCU:\Control Panel\Quick Actions\Control Center\Unpinned"
    if (-not (Test-Path $unpinnedKey)) { New-Item -Path $unpinnedKey -Force | Out-Null }
    Set-Reg $unpinnedKey "Microsoft.QuickAction.BlueLightReduction" ([byte[]]@()) "Binary"
    Set-Reg $unpinnedKey "Microsoft.QuickAction.Accessibility" ([byte[]]@()) "Binary"
    Set-Reg $unpinnedKey "Microsoft.QuickAction.NearShare" ([byte[]]@()) "Binary"
    Set-Reg $unpinnedKey "Microsoft.QuickAction.Cast" ([byte[]]@()) "Binary"
    Set-Reg $unpinnedKey "Microsoft.QuickAction.ProjectL2" ([byte[]]@()) "Binary"

    # Disable WPBT (Windows Platform Binary Table)
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" 1

    # Remove Bing Apps & Disable Bing Search
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

    # Additional Privacy Registry Tweaks
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

    # Disable DiagTrack & WerMgr Services
    Log "Disabling Diagnostic & Reporting Services..."
    foreach ($svc in @("diagtrack", "wermgr")) {
        if (Get-Service $svc -ErrorAction SilentlyContinue) {
            Set-Service -Name $svc -StartupType Disabled
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        }
    }

    # Strict Data Collection Policies
    Log "Enforcing Strict Data Collection Policies..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "Allow" "Deny" "String"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "SensorPermissionState" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" "Status" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" "AutoUpdateEnabled" 0

    # Remove Xbox Gaming Overlay
    Log "Removing Xbox Gaming Overlay..."
    try {
        winget uninstall 9nzkpstsnw4p --silent --accept-source-agreements
        Get-AppxPackage Microsoft.XboxGamingOverlay | Remove-AppxPackage -ErrorAction Stop
        Log "Successfully removed Xbox Gaming Overlay"
    } catch {
        Log "Xbox Overlay removal encountered an issue (it may already be gone)."
    }

    # Disable Windows Consumer Features
    Log "Disabling Windows Consumer Features..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1

    # Disable Background Access Global
    Log "Disabling Global Background Access..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1

    # Disable Windows AI (Copilot, Recall, etc.)
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

    # Enable End Task in Taskbar
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" "TaskbarEndTask" 1

    # Disable Share App Experiences
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP" "RomeSdkChannelUserAuthzPolicy" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP" "NearShareChannelUserAuthzPolicy" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP" "CdpSessionUserAuthzPolicy" 0

    # Set Wallpaper to Solid Color
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" "BackgroundType" 1

    # Disable Prompt For Location Privacy
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "ShowGlobalPrompts" 0

    # Disable User Choice Driver
    Set-Reg "HKLM:\SYSTEM\ControlSet001\Services\UCPD" "Start" 4

    # Disable Phone Companion
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" "RightCompanionToggledOpen" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start\Companions\Microsoft.YourPhone_8wekyb3d8bbwe" "IsEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start\Companions\Microsoft.YourPhone_8wekyb3d8bbwe" "IsAvailable" 0

    # Disable Cross Device Resume
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" "IsResumeAllowed" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" "IsOneDriveResumeAllowed" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Connectivity\DisableCrossDeviceResume" "value" 1
    Set-Reg "HKLM:\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\1387020943" "EnabledState" 1
    Set-Reg "HKLM:\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\1694661260" "EnabledState" 1

    # Disable Dynamic Lighting
    Set-Reg "HKCU:\Software\Microsoft\Lighting" "AmbientLightingEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Lighting" "ControlledByForegroundApp" 0

    # Disable UAC (Warning: Security Risk)
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "PromptOnSecureDesktop" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "EnableLUA" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "ConsentPromptBehaviorAdmin" 0

    # Disable Update Apps Automatically
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" "AutoDownload" 2

    # Remove Chat/Task View/Search from Taskbar
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 0

    # Remove Meet Now
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideSCAMeetNow" 1

    # Remove News and Interests
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" "EnableFeeds" 0

    # Disable Track Docs/Progs
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackDocs" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0

    # Hide Frequent Folders
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "ShowFrequent" 0

    # Show File Name Extensions
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0

    # Disable Search History
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDeviceSearchHistoryEnabled" 0

    # Disable Menu Show Delay
    Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String"

    # Dark Theme Enforce
    Log "Enforcing Dark Theme..."
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "ColorPrevalence" 1
    
    # Accent Colors (Dark Grey/Red Scheme from Reg)
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" "AccentPalette" ([byte[]](0x95,0x95,0x95,0xff,0x8b,0x8b,0x8b,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0x00)) "Binary"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" "StartColorMenu" 0xff191919
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" "AccentColorMenu" 0xff191919
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "EnableWindowColorization" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "AccentColor" 0xff191919
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "ColorizationColor" 0xc4191919
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "ColorizationAfterglow" 0xc4191919

    # 100% DPI Scaling
    Set-Reg "HKCU:\Control Panel\Desktop" "LogPixels" 0x60
    Set-Reg "HKCU:\Control Panel\Desktop" "Win8DpiScaling" 0
    Set-Reg "HKCU:\Control Panel\Desktop" "EnablePerProcessSystemDPI" 0
    try { Remove-Item -Path "HKCU:\Control Panel\Desktop\PerMonitorSettings" -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "AppliedDPI" 0x60

    # Disable Transparency
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0

    # Sound Communications Do Nothing
    Set-Reg "HKCU:\Software\Microsoft\Multimedia\Audio" "UserDuckingPreference" 3

    # Disable Startup Sound
    Set-Reg "HKLM:\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation" "DisableStartupSound" 1

    # Mouse Settings
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String"

    # Disable Lock/Sleep Options
    Set-Reg "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" "ShowLockOption" 0
    Set-Reg "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" "ShowSleepOption" 0

    # Disable Hibernate
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 0

    # System Responsiveness
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xFFFFFFFF
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0

    # Visual Effects (Custom/Best Performance)
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 3
    # Updated UserPreferencesMask to (144,50,7,128) as requested
    Set-Reg "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x90,0x32,0x07,0x80)) "Binary"
    Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" "String"

    # Turn Off HAGS (User requested off in this block, though Gaming module enables it. Debloat usually cleans up, but this is specific preference)
    # Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 1 

    # Taskbar Animations Off
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0

    # Disable Peek & Thumbnails
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "EnableAeroPeek" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "AlwaysHibernateThumbnails" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconsOnly" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 0
    Set-Reg "HKCU:\Control Panel\Desktop" "DragFullWindows" "0" "String"
    Set-Reg "HKCU:\Control Panel\Desktop" "FontSmoothing" "2" "String"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewShadow" 0

    # Win32 Priority
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 0x26

    # Disable Remote Assistance
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 0

    # Disable Game Bar & Capture (Debloat version)
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
    
    # Disable Xbox Capture Details
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

    # Privacy: Deny All Capability Access
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

    # App Privacy Policies
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

    # Voice Activation
    Set-Reg "HKCU:\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps" "AgentActivationEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps" "AgentActivationLastUsed" 0

    # Privacy: Eye Tracker Deny
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessGazeInput" 2

    # Privacy: GetDiagnosticInfo Deny
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsGetDiagnosticInfo" 2

    # Privacy: Motion Deny
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessMotion" 2

    # Privacy: Background Apps Deny
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" 2

    # Disable Background Apps Global
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BackgroundAppGlobalToggle" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1

    # Disable Language List Tracking
    Set-Reg "HKCU:\Control Panel\International\User Profile" "HttpAcceptLanguageOptOut" 1

    # Disable MFU Tracking
    Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\EdgeUI" "DisableMFUTracking" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "DisableMFUTracking" 1

    # Disable Personal Inking & Typing Dictionary
    Set-Reg "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 1
    Set-Reg "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 1
    Set-Reg "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore" "HarvestContacts" 0
    Set-Reg "HKCU:\Software\Microsoft\Personalization\Settings" "AcceptedPrivacyPolicy" 0

    # Feedback Frequency Never
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0
    try { Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "PeriodInNanoSeconds" -ErrorAction SilentlyContinue } catch {}

    # Disable Activity History
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0

    # Safe Search Off
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "SafeSearchMode" 0

    # Disable Cloud Content Search
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsAADCloudSearchEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsMSACloudSearchEnabled" 0

    # Disable Notifications (Comprehensive)
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

    # Disable SubscribedContent
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

    # Remove Logons
    try { Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "*" -ErrorAction SilentlyContinue } catch {}
    try { Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "*" -ErrorAction SilentlyContinue } catch {}

    # Disable Magnifier
    Set-Reg "HKCU:\SOFTWARE\Microsoft\ScreenMagnifier" "FollowCaret" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\ScreenMagnifier" "FollowNarrator" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\ScreenMagnifier" "FollowMouse" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\ScreenMagnifier" "FollowFocus" 0

    # Disable Narrator
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

    # Disable Driver Searching
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" "SearchOrderConfig" 0

    # Disable Automatic Maintenance
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" "MaintenanceDisabled" 1

    # Disable Auto Restart Sign On
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "DisableAutomaticRestartSignOn" 1

    # Disable Maps Auto Update
    Set-Reg "HKLM:\SYSTEM\Maps" "AutoUpdateEnabled" 0

    # Alt Tab Open Windows Only
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MultiTaskingAltTabFilter" 3

    # Show Hidden Files
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1

    # Remove Picture Wallpaper & Set Black Background
    Set-Reg "HKCU:\Control Panel\Desktop" "WallPaper" "" "String"
    Set-Reg "HKCU:\Control Panel\Colors" "Background" "0 0 0" "String"

    # Disable Finish Setting Up Your Device
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0

    # Disable Language Hotkey & Bar
    Set-Reg "HKCU:\Keyboard Layout\Toggle" "Language Hotkey" "3" "String"
    Set-Reg "HKCU:\Keyboard Layout\Toggle" "Hotkey" "3" "String"
    Set-Reg "HKCU:\Keyboard Layout\Toggle" "Layout Hotkey" "3" "String"
    Set-Reg "HKCU:\SOFTWARE\Microsoft\CTF\LangBar" "ShowStatus" 3

    # Disable Lock Screen Image
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "DisableLogonBackgroundImage" 1

    # Disable Search Web Results
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1

    # Disable AutoPlay
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" "DisableAutoplay" 1

    # Disable Web Search
    Set-Reg "HKLM:\Software\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0
    Set-Reg "HKLM:\Software\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1

    # Disable Co Installers
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Installer" "DisableCoInstallers" 1

    # Disable Windows Automatic Folder Type
    Set-Reg "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell" "FolderType" "NotSpecified" "String"

    # Disable Windows Spotlight
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings" "EnabledState" 0

    # Disable Last Access Time
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate" 1

    # Disable Fault Tolerant Heap
    Set-Reg "HKLM:\SOFTWARE\Microsoft\FTH" "Enabled" 0

    # Increase Icon Cache Size
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "MaxCachedIcons" "4096" "String"

    # More Info In BSOD Screen
    Set-Reg "HKLM:\System\CurrentControlSet\Control\CrashControl" "DisplayParameters" 1

    # Enable Long Paths
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 1

    # Black PowerShell Console
    $psConsole = "HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe"
    Set-Reg $psConsole "ColorTable05" 0x00562401
    Set-Reg $psConsole "ColorTable06" 0x00f0edee
    Set-Reg $psConsole "FaceName" "Consolas" "String"
    Set-Reg $psConsole "FontFamily" 0x36
    Set-Reg $psConsole "FontWeight" 0x190
    Set-Reg $psConsole "PopupColors" 0x87
    Set-Reg $psConsole "ScreenColors" 0x06

    # Disable Windows Platform Binary Table
    Set-Reg "HKLM:\SYSTEM\ControlSet001\Control\Session Manager" "DisableWpbtExecution" 1

    # No Web Services In Explorer
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoWebServices" 1

    # No Document History Tracking
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoRecentDocsHistory" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "ClearRecentDocsOnExit" 1

    # Disable Low Disk Space Checks
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoLowDiskSpaceChecks" 1

    # Disable Publish to Web
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoPublishingWizard" 1

    # Disable Home Page in Settings
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "SettingsPageVisibility" "hide:home;" "String"

    # Show all taskbar icons
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "EnableAutoTray" 0
    Set-Reg "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify" "SystemTrayChevronVisibility" 0

    # Disable Track my Device
    Set-Reg "HKLM:\SOFTWARE\Microsoft\MdmCommon\SettingValues" "LocationSyncEnabled" 0

    # Disable Personalized Offers
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CPSS\Store\TailoredExperiencesWithDiagnosticDataEnabled" "Value" 0

    # Disable Data Collection
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "MaxTelemetryAllowed" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CPSS\Store\AllowTelemetry" "Value" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0

    # Disable Startmenu recommendation section
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_IrisRecommendations" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_AccountNotifications" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start" "HideRecommendedSection" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Education" "IsEducationEnvironment" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedSection" 1

    # Set startmenu apps to list
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" "AllAppsViewMode" 2

    # Disable Explorer Open in New tab
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "OpenFolderInNewTab" 0

    # Disable SleepStudy
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "SleepStudyDisabled" 1

    # Disable Data Collection & Telemetry (Completed)
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack" "Start" 4
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" "Start" 4

    # Disable Windows Tips
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SoftLandingEnabled" 0

    # Disable Windows Spotlight
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenOverlayEnabled" 0

    # Disable Shared Experiences
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" "CdpSessionUserAuthzPolicy" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" "NearShareChannelUserAuthzPolicy" 0

    # Stop Explorer from Showing Frequent/Recent Files
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "ShowFrequent" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "ShowRecent" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "TelemetrySalt" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoRecentDocsHistory" 1

    # Disable Tailored Experiences
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0

    # Disable Search History Logging
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "HistoryViewEnabled" 0

    # Disable Device History
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "DeviceHistoryEnabled" 0

    # Disable Bing Search
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0

    # Disable Notifications
    Log "Disabling Notifications..."
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\QuietHours" "Enabled" 0
    
    # Disable Windows Insider Experiments
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System" "AllowExperimentation" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\System\AllowExperimentation" "value" 0

    # Windows Privacy Settings (CapabilityAccessManager)
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

    # Allow specific ones (Microphone/Webcam mostly needed, but script said Allow/Prompt)
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" "Value" "Allow" "String"
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" "Value" "Allow" "String"

    # Stop Windows from Reinstalling Preinstalled apps
    Log "Preventing Preinstalled Apps..."
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "PreInstalledAppsEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "OemPreInstalledAppsEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "ContentDeliveryAllowed" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContentEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "PreInstalledAppsEverEnabled" 0

    # Disable Windows Suggestions (Start Menu)
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

    # Disable Startup Apps (Common ones)
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

    # Disable Microsoft Setting Synchronization
    Log "Disabling Setting Synchronization..."
    $syncGroups = @(
        "Accessibility", "AppSync", "BrowserSettings", "Credentials", "DesktopTheme",
        "Language", "PackageState", "Personalization", "StartLayout", "Windows"
    )
    foreach ($group in $syncGroups) {
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\$group" "Enabled" 0
    }

    # Disable Windows Error Reporting
    Log "Disabling Windows Error Reporting..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "Disabled" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "DoReport" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "LoggingDisabled" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\PCHealth\ErrorReporting" "DoReport" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" "Disabled" 1

    # Disable Telemetry (Task Scheduler)
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
        Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
    }

    # Disable Telemetry (Registry)
    Log "Disabling Telemetry Registry Keys..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" "PreventDeviceMetadataFromNetwork" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SQMClient\Windows" "CEIPEnable" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0

    # Disable AutoLoggers
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
    foreach ($logName in $autoLoggersList) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$logName" "Start" 0
    }
    
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WUDF" "LogEnable" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WUDF" "LogLevel" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableThirdPartySuggestions" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp" "DebugLogLevel" 0

    # Disable Telemetry Services
    Log "Disabling Telemetry Services..."
    $services = @("DiagTrack", "dmwappushservice", "diagnosticshub.standardcollector.service")
    foreach ($svc in $services) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
    }

    # Removing Unnecessary Powershell Packages
    Log "Removing Unnecessary Appx Packages..."
    $bloatPkgs = @(
        "*3DBuilder*", "*bing*", "*bingfinance*", "*bingsports*", "*BingWeather*", "*CommsPhone*",
        "*Drawboard PDF*", "*Facebook*", "*Getstarted*", "*Microsoft.Messaging*", "*MicrosoftOfficeHub*",
        "*Office.OneNote*", "*OneNote*", "*people*", "*SkypeApp*", "*solit*", "*Sway*", "*Twitter*",
        "*WindowsAlarms*", "*WindowsPhone*", "*WindowsMaps*", "*WindowsFeedbackHub*", "*WindowsSoundRecorder*",
        "*windowscommunicationsapps*", "*zune*",
        # User Added
        "*Clipchamp*", "*DevHome*", "*PowerAutomate*", "*StickyNotes*", "*XboxApp*"
    )
    foreach ($pkg in $bloatPkgs) {
        try {
            Get-AppxPackage -AllUsers $pkg | Remove-AppxPackage -ErrorAction SilentlyContinue
            Log "Removed $pkg"
        } catch {
            Log "Failed to remove $pkg"
        }
    }

    # Disable Unnecessary Services (Extensive List)
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
        "RemoteRegistry", "Spooler", "WSearch", "MapsBroker", "NetTcpPortSharing", "TrkWks"
    )
    foreach ($svc in $unnecessaryServices) {
        try {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" "Start" 4
            Log "Disabled Service: $svc"
        } catch {
            Log "Failed to disable service: $svc"
        }
    }
    
    # Edge Removal (Aggressive - Use Caution)
    Log "Removing Microsoft Edge..."
    try {
        $edgeSetup = Join-Path $env:ProgramFiles(x86) "Microsoft\Edge\Application\*\Installer\setup.exe"
        $edgeInstaller = Get-Item $edgeSetup -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($edgeInstaller) {
            Start-Process -FilePath $edgeInstaller.FullName -ArgumentList "--uninstall --system-level --verbose-logging --force-uninstall" -Wait -NoNewWindow
            Log "Edge uninstalled via setup.exe"
        }
        
        # Cleanup Edge User Data
        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Edge" -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Log "Edge removal failed or skipped: $_"
    }

    # Focus Assist (Alarms Only / Priority)
    Log "Configuring Focus Assist..."
    # 0 = Off, 1 = Priority Only, 2 = Alarms Only
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_TOASTS_ENABLED" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" 0

    # Additional Confidentiality & Privacy Tweaks (From C# ConfidentialityTweaks)
    Log "Applying Confidentiality & Privacy Tweaks..."

    # Button 1: Advertising
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Bluetooth" "AllowAdvertising" 0

    # Button 2: Setting Sync (Completed above, but ensuring all subkeys)
    $syncKeys = @("Accessibility", "BrowserSettings", "Credentials", "Language", "Personalization", "Windows")
    foreach ($k in $syncKeys) {
        Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SettingSync\Groups\$k" "Enabled" 0
    }

    # Button 3: Diagtrack-Listener & Attachments
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Diagtrack-Listener" "Start" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" "SaveZoneInformation" 1

    # Button 5: Inventory
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1

    # Button 6: Telemetry & AIT
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowDeviceNameInTelemetry" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0

    # Button 7: Handwriting & TIPC
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" "PreventHandwritingDataSharing" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" "PreventHandwritingErrorReports" 1
    Set-Reg "HKCU:\Software\Microsoft\Input\TIPC" "Enabled" 0

    # Button 8: CEIP
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" "CEIPEnable" 0
    try { Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient" -Recurse -Force -ErrorAction SilentlyContinue } catch {}

    # Button 10: Location & Sensors
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocationScripting" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableWindowsLocationProvider" 1

    # Button 11: Feedback (SIUF)
    Set-Reg "HKCU:\Software\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0
    Set-Reg "HKCU:\Software\Microsoft\Siuf\Rules" "PeriodInNanoSeconds" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1

    # Button 12: Speech
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Speech" "AllowSpeechModelUpdate" 0

    # Button 13: CDPUserSvc (Ensure disabled)
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc" "Start" 4

    # Button 14: Experimentation
    Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System" "AllowExperimentation" 0

    # Button 18: UAR & LockScreen Camera
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableUAR" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreenCamera" 1

    # Button 19: Maps
    Set-Reg "HKLM:\SYSTEM\Maps" "MapUpdate" 0
    Set-Reg "HKLM:\SYSTEM\Maps" "AutoUpdateEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Maps" "AutoDownloadAndUpdateMapData" 0

    # Button 20: Telemetry Service
    if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\Telemetry") {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Telemetry" "Start" 4
    }

    # Disable Edge Prelaunch
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" "AllowPrelaunch" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader" "AllowTabPreloading" 0

    # Disable Cortana (Registry & Package)
    Log "Removing Cortana..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCloudSearch" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortanaAboveLock" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowSearchToUseLocation" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWebOverMeteredConnections" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 0
    Get-AppxPackage -AllUsers *Microsoft.549981C3F5F10* | Remove-AppxPackage -ErrorAction SilentlyContinue

    # Disable OneDrive
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

    # System Cleanup
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
             # Simple file pattern or directory
             Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    # Clear specific logs
    Remove-Item -Path "$env:SystemRoot\Logs\CBS\CBS.log" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:SystemRoot\Logs\DISM\DISM.log" -Force -ErrorAction SilentlyContinue

    Log "Debloat tweaks applied."
}
Export-ModuleMember -Function Remove-Bloatware
