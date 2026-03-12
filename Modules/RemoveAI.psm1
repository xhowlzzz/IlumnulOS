# AI Removal Module
# Systematically disables and removes Windows 11 AI components (Copilot, Recall, etc.)

function Remove-WindowsAI {
    param(
        [Action[string]]$Logger,
        [hashtable]$Options = @{}
    )
    
    function Log($msg) { 
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMsg = "[$timestamp] $msg"
        if ($Logger) { $Logger.Invoke($logMsg) } else { Write-Host $logMsg } 
    }
    
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
                Log "Error setting registry key $Name`: $($_.Exception.Message)"
            }
        }
    }

    function Remove-Reg {
        param($Path, $Name)
        try {
            if (Test-Path $Path) {
                Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
                Log "Registry: Removed $Name from $Path"
            }
        } catch {
            Log "Error removing registry key $Name`: $_"
        }
    }

    Log "Starting Comprehensive AI Removal..."
    $DisableCopilot = if ($Options.ContainsKey("DisableCopilot")) { [bool]$Options.DisableCopilot } else { $true }
    $DisableRecall = if ($Options.ContainsKey("DisableRecall")) { [bool]$Options.DisableRecall } else { $true }
    $DisableOfficeAI = if ($Options.ContainsKey("DisableOfficeAI")) { [bool]$Options.DisableOfficeAI } else { $true }

    # =========================================================================
    # 0. PRIVILEGE ESCALATION (TrustedInstaller Trick)
    # =========================================================================
    # Note: We incorporate the "TrustedInstaller" logic for locked packages
    function Run-AsTrusted {
        param([string]$Command)
        Log "Attempting to run command as TrustedInstaller..."
        # Simplified TI logic for module integration
        try {
            Stop-Service -Name TrustedInstaller -Force -ErrorAction SilentlyContinue
            $psexe = 'PowerShell.exe'
            $bytes = [System.Text.Encoding]::Unicode.GetBytes($Command)
            $base64 = [Convert]::ToBase64String($bytes)
            sc.exe config TrustedInstaller binPath= "cmd.exe /c $psexe -encodedcommand $base64" | Out-Null
            sc.exe start TrustedInstaller | Out-Null
            Start-Sleep -Seconds 2
            # Revert TI path
            sc.exe config TrustedInstaller binpath= "C:\Windows\servicing\TrustedInstaller.exe" | Out-Null
        } catch {
            Log "TrustedInstaller escalation failed: $($_.Exception.Message)"
        }
    }

    # =========================================================================
    # 1. REGISTRY OPERATIONS (Block AI Features)
    # =========================================================================
    Log "--- Phase 1: Registry Operations ---"
    
    # Windows AI Policy
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
    if ($DisableRecall) {
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "AllowRecallEnablement" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableClickToDo" 1
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\StudioEffects" "DisableStudioEffects" 1
    }
    if ($DisableCopilot) {
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
        
        # Additional Copilot Blockers (winutil)
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Shell\Copilot" "IsCopilotAvailable" 0
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Shell\Copilot" "CopilotDisabledReason" "IsEnabledForGeographicRegionFailed" "String"
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsCopilot" "AllowCopilotRuntime" 0
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" "{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}" "" "String"

        # --- optimizerNXT Integration (AI & Search) ---
        Log "Applying optimizerNXT AI & Search tweaks..."
        
        # Disable AI Data Analysis
        Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
        
        # Remove Copilot Button
        Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0
        
        # Edge AI & Campaigns
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "DefaultBrowserSettingsCampaignEnabled" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "ComposeInlineEnabled" 0
        
        # Disable Web Search & Cortana
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWebOverMeteredConnections" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCloudSearch" 0
        
        # Disable Search History & Bing
        Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDeviceSearchHistoryEnabled" 0
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "HistoryViewEnabled" 0
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "DeviceHistoryEnabled" 0
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "AllowSearchToUseLocation" 0
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
        Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent" 0
    }
    
    # User Preferences
    if ($DisableCopilot) {
        Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0
        Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
        Set-Reg "HKCU:\Software\Microsoft\OneDrive" "EnablePhotoTagging" 0
    }
    
    # Edge Copilot
    if ($DisableOfficeAI) {
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "HubsSidebarEnabled" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "CopilotEnabled" 0
    }
    
    # Paint & Notepad AI
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint" "DisableGenerativeFill" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint" "DisableCocreator" 1
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint" "DisableImageCreator" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\WindowsNotepad" "DisableAIFeatures" 1
    Set-Reg "HKCU:\Software\Microsoft\Notepad" "ShowStoreBanner" 0

    # Search & Input
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDynamicSearchBoxEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Input\Settings" "InsightsEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoSearchInSettings" 1

    # Voice Access
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\VoiceAccess" "VoiceAccessEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\VoiceAccess" "VoiceAccessIsOn" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Speech" "AllowSpeechModelUpdate" 0

    # Gaming Copilot
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameBar" "ShowCopilotButton" 0
    if ($DisableCopilot) {
        Set-Reg "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
    }
    
    # App Privacy (AI Access)
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessSystemAIModels" 2

    # Photos AI
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Photos" "DisableAI" 1

    # =========================================================================
    # 2. SERVICE MANAGEMENT
    # =========================================================================
    Log "--- Phase 2: Service Management ---"
    
    $aiServices = @("AIFabricService", "InputInsights", "NaturalAuthentication")
    if ($DisableCopilot) { $aiServices += "WindowsCopilot" }
    if ($DisableRecall) { $aiServices += "RecallService" }
    foreach ($svc in $aiServices) {
        if (Get-Service $svc -ErrorAction SilentlyContinue) {
            try {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 3>$null 2>&1 | Out-Null
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 3>$null 2>&1 | Out-Null
                Log "Service: Disabled $svc"
            } catch {
                Log "Service: Failed to disable $svc - $_"
            }
        }
    }

    # =========================================================================
    # 3. APP REMOVAL (Appx Packages)
    # =========================================================================
    Log "--- Phase 3: Package Removal ---"
    
    # Ensure Appx and Dism modules are available
    if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
        Log "Warning: Get-AppxPackage not found. Attempting to load Appx module..."
        Import-Module Appx -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
    }
    
    if (-not (Get-Command Get-AppxProvisionedPackage -ErrorAction SilentlyContinue)) {
        Log "Warning: Get-AppxProvisionedPackage not found. Attempting to load Dism module..."
        Import-Module Dism -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
    }
    
    if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        Log "Warning: Get-ScheduledTask not found. Attempting to load ScheduledTasks module..."
        Import-Module ScheduledTasks -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
    }

    $aiPackages = @(
        "*Microsoft.Windows.Search*",
        "*Microsoft.Windows.PeopleExperienceHost*",
        "*Microsoft.Windows.ContentDeliveryManager*",
        "*MicrosoftWindows.Client.AIX*",
        "*Microsoft.Edge.GameAssist*",
        "*Microsoft.Office.ActionsServer*",
        "*aimgr*",
        "*Microsoft.WritingAssistant*",
        "*MicrosoftWindows.*.Voiess*",
        "*MicrosoftWindows.*.Speion*",
        "*MicrosoftWindows.*.Livtop*",
        "*MicrosoftWindows.*.InpApp*",
        "*MicrosoftWindows.*.Filons*",
        "*WindowsWorkload.Data.Analysis.Stx.*",
        "*WindowsWorkload.Manager.*",
        "*WindowsWorkload.PSOnnxRuntime.Stx.*",
        "*WindowsWorkload.PSTokenizer.Stx.*",
        "*WindowsWorkload.QueryBlockList.*",
        "*WindowsWorkload.QueryProcessor.Data.*",
        "*WindowsWorkload.QueryProcessor.Stx.*",
        "*WindowsWorkload.SemanticText.Data.*",
        "*WindowsWorkload.SemanticText.Stx.*",
        "*WindowsWorkload.Data.ContentExtraction.Stx.*",
        "*WindowsWorkload.ScrRegDetection.Data.*",
        "*WindowsWorkload.ScrRegDetection.Stx.*",
        "*WindowsWorkload.TextRecognition.Stx.*",
        "*WindowsWorkload.Data.ImageSearch.Stx.*",
        "*WindowsWorkload.ImageContentModeration.*",
        "*WindowsWorkload.ImageContentModeration.Data.*",
        "*WindowsWorkload.ImageSearch.Data.*",
        "*WindowsWorkload.ImageSearch.Stx.*",
        "*WindowsWorkload.ImageTextSearch.Data.*",
        "*WindowsWorkload.PSOnnxRuntime.Stx.*",
        "*WindowsWorkload.PSTokenizerShared.Data.*",
        "*WindowsWorkload.PSTokenizerShared.Stx.*",
        "*WindowsWorkload.ImageTextSearch.Stx.*"
    )
    if ($DisableCopilot) {
        $aiPackages += "*Microsoft.Windows.Ai.Copilot.Provider*"
        $aiPackages += "*Microsoft.Copilot*"
        $aiPackages += "*Microsoft.BingChat*"
        $aiPackages += "*Copilot*"
        $aiPackages += "*MicrosoftWindows.Client.CoPilot*"
        $aiPackages += "*Microsoft.MicrosoftOfficeHub*"
        $aiPackages += "*MicrosoftWindows.Client.CoreAI*"
    }
    if ($DisableRecall) {
        $aiPackages += "*Microsoft.Windows.Recall*"
        $aiPackages += "*Microsoft.Windows.Photos*"
    }
    
    $store = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore'

    foreach ($pkg in $aiPackages) {
        # 1. Deprovisioning & Registry Tricks
        try {
            $provisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $pkg }
            foreach ($p in $provisioned) {
                # Create Deprovisioned key to block return
                try {
                     $family = (Get-AppxPackage -Name $p.DisplayName -AllUsers -ErrorAction SilentlyContinue).PackageFamilyName
                     if ($family) {
                         New-Item "$store\Deprovisioned\$family" -Force -ErrorAction SilentlyContinue | Out-Null
                     }
                } catch {}
                
                Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
                Log "Package: Deprovisioned $($p.DisplayName)"
            }
        } catch {}

        # 2. User Package Removal
        try {
            $foundPkgs = Get-AppxPackage -AllUsers $pkg -ErrorAction SilentlyContinue
            foreach ($foundPkg in $foundPkgs) {
                # Inbox App Removal Trick
                try {
                    $inboxPath = "$store\InboxApplications\$($foundPkg.PackageFullName)"
                    if (Test-Path $inboxPath) {
                        Remove-Item -Path $inboxPath -Force -ErrorAction SilentlyContinue
                    }
                } catch {}

                Remove-AppxPackage -Package $foundPkg.PackageFullName -AllUsers -ErrorAction Stop 3>$null 2>&1 | Out-Null
                Log "Package: Removed $($foundPkg.Name)"
            }
        } catch {
            if ($_.Exception.Message -match "0x80070032" -or $_.Exception.Message -match "part of Windows") {
                 Log "Package: Skipped $pkg (System Protected)"
            } else {
                 Log "Package: Failed to remove $pkg - $($_.Exception.Message)"
            }
        }
    }

    # Additional Photos App Removal (Explicit)
    if ($DisableRecall) {
        try {
            Get-AppxPackage *Microsoft.Windows.Photos* | Remove-AppxPackage -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
        } catch {}
    }

    # Optional Features (Recall)
    if ($DisableRecall) {
        try {
            $recallFeature = Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue
            if ($recallFeature -and $recallFeature.State -eq "Enabled") {
                Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
                Log "Feature: Disabled Recall Optional Feature"
            }
        } catch {
            Log "Feature: Failed to disable Recall - $_"
        }
    }

    # =========================================================================
    # 4. OFFICE SUITE INTEGRATION
    # =========================================================================
    Log "--- Phase 4: Office Integration ---"
    
    # Office Policies (HKCU & HKLM)
    $officePaths = @(
        "HKCU:\Software\Policies\Microsoft\office\16.0\common",
        "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common"
    )

    if ($DisableOfficeAI) {
        foreach ($basePath in $officePaths) {
            Set-Reg "$basePath\research" "disableoneclickresearch" 1
            Set-Reg "$basePath\ai" "enableai" 0
            Set-Reg "$basePath\copilot" "enablecopilot" 0
            Set-Reg "$basePath\internet" "useonlinecontent" 0
        }
    }
    
    # Block Copilot Ribbon
    # This is often controlled by policy but can be reinforced via registry if specific keys are known.
    # The 'enablecopilot' policy above is the primary method.

    # =========================================================================
    # 5. FILE SYSTEM CLEANUP
    # =========================================================================
    Log "--- Phase 5: File System Cleanup ---"
    
    $paths = @()
    if ($DisableCopilot) {
        $paths += "$env:LOCALAPPDATA\Microsoft\Windows\Copilot"
        $paths += "$env:LOCALAPPDATA\Packages\Microsoft.Windows.Ai.Copilot.Provider*"
        $paths += "$env:LOCALAPPDATA\Packages\Microsoft.Copilot*"
    }
    if ($DisableRecall) {
        $paths += "$env:LOCALAPPDATA\Microsoft\Recall"
        $paths += "$env:PROGRAMDATA\Microsoft\Windows\Recall"
    }
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            try {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
                Log "FileSystem: Removed $path"
            } catch {
                Log "FileSystem: Failed to remove $path - $_"
            }
        }
    }

    # IntegratedServicesRegionPolicySet.json Modification
    # This requires TrustedInstaller or high privileges. We'll attempt a safe modification if possible.
    $policyFile = "$env:SystemRoot\System32\IntegratedServicesRegionPolicySet.json"
    if (Test-Path $policyFile) {
        try {
            # Backup
            Copy-Item -Path $policyFile -Destination "$policyFile.bak" -Force -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
            Log "Policy: Backed up IntegratedServicesRegionPolicySet.json"
            
            # We can't easily parse this large JSON safely in a script without potentially breaking it if the schema changes.
            # However, we can try to block access to it or log that it needs manual intervention if we can't edit it.
            # For now, we will skip complex JSON editing to avoid system corruption, but log the recommendation.
            Log "Policy: Manual intervention recommended for IntegratedServicesRegionPolicySet.json to fully disable regional AI policies."
            
            # Alternative: ACL restriction (Advanced)
            # $acl = Get-Acl $policyFile
            # ... deny read access to SYSTEM/Users? (Risky)
        } catch {
            Log "Policy: Failed to backup/modify policy file - $_"
        }
    }

    # =========================================================================
    # 6. TASK SCHEDULER
    # =========================================================================
    Log "--- Phase 6: Task Scheduler ---"
    
    # Recall & AI Tasks
    $tasks = Get-ScheduledTask | Where-Object {
        (($DisableRecall) -and ($_.TaskName -like "*Recall*" -or $_.TaskPath -like "*Recall*")) -or
        (($DisableCopilot) -and ($_.TaskName -like "*Copilot*")) -or
        $_.TaskPath -like "*WindowsAI*"
    }
    foreach ($task in $tasks) {
        try {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction SilentlyContinue 3>$null 2>&1 | Out-Null
            Log "Task: Removed $($task.TaskName)"
        } catch {
            Log "Task: Failed to remove $($task.TaskName) - $_"
        }
    }

    Log "Comprehensive AI Removal Completed."
}

function Test-WindowsAI {
    param()
    
    Write-Host "--- AI Verification Report ---" -ForegroundColor Cyan
    
    $checks = @{
        "Registry: DisableAIDataAnalysis" = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -ErrorAction SilentlyContinue).DisableAIDataAnalysis -eq 1
        "Registry: TurnOffWindowsCopilot" = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue).TurnOffWindowsCopilot -eq 1
        "Service: WindowsCopilot" = (Get-Service "WindowsCopilot" -ErrorAction SilentlyContinue).Status -ne "Running"
        "Service: RecallService" = (Get-Service "RecallService" -ErrorAction SilentlyContinue).Status -ne "Running"
        "Package: Copilot Provider" = !(Get-AppxPackage -AllUsers "*Microsoft.Windows.Ai.Copilot.Provider*")
        "Task: Recall Tasks" = !(Get-ScheduledTask | Where-Object { $_.TaskName -like "*Recall*" })
    }
    
    foreach ($check in $checks.Keys) {
        if ($checks[$check]) {
            Write-Host "[PASS] $check" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] $check" -ForegroundColor Red
        }
    }
}

Export-ModuleMember -Function Remove-WindowsAI, Test-WindowsAI
