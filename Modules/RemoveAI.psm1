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
    
    function Set-Reg {
        param($Path, $Name, $Value, $Type = "DWord")
        try {
            if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction SilentlyContinue
            Log "Registry: Set $Name to $Value in $Path"
        } catch {
            Log "Error setting registry key $Name`: $_"
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
    # 1. REGISTRY OPERATIONS (Block AI Features)
    # =========================================================================
    Log "--- Phase 1: Registry Operations ---"
    
    # Windows AI Policy
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
    if ($DisableRecall) {
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "AllowRecallEnablement" 0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableClickToDo" 1
    }
    if ($DisableCopilot) {
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
    }
    
    # User Preferences
    if ($DisableCopilot) {
        Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0
        Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
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
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
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
        Import-Module Appx -ErrorAction SilentlyContinue
    }
    
    if (-not (Get-Command Get-AppxProvisionedPackage -ErrorAction SilentlyContinue)) {
        Log "Warning: Get-AppxProvisionedPackage not found. Attempting to load Dism module..."
        Import-Module Dism -ErrorAction SilentlyContinue
    }

    if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        Log "Warning: Get-ScheduledTask not found. Attempting to load ScheduledTasks module..."
        Import-Module ScheduledTasks -ErrorAction SilentlyContinue
    }

    $aiPackages = @(
        "*Microsoft.Windows.Search*",
        "*Microsoft.Windows.PeopleExperienceHost*",
        "*Microsoft.Windows.ContentDeliveryManager*"
    )
    if ($DisableCopilot) {
        $aiPackages += "*Microsoft.Windows.Ai.Copilot.Provider*"
        $aiPackages += "*Microsoft.Copilot*"
        $aiPackages += "*Microsoft.BingChat*"
    }
    if ($DisableRecall) {
        $aiPackages += "*Microsoft.Windows.Recall*"
    }
    
    foreach ($pkg in $aiPackages) {
        try {
            $foundPkg = Get-AppxPackage -AllUsers $pkg -ErrorAction SilentlyContinue
            if ($foundPkg) {
                $foundPkg | Remove-AppxPackage -AllUsers -ErrorAction Stop
                Log "Package: Removed $pkg"
            }
        } catch {
            if ($_.Exception.Message -match "0x80070032" -or $_.Exception.Message -match "part of Windows") {
                 Log "Package: Skipped $pkg (System Protected)"
            } else {
                 Log "Package: Failed to remove $pkg - $($_.Exception.Message)"
            }
        }
        
        # Provisioned Packages (separate try/catch)
        try {
            Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $pkg } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }

    # Optional Features (Recall)
    if ($DisableRecall) {
        try {
            if (Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue) {
                Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction SilentlyContinue
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
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
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
            Copy-Item -Path $policyFile -Destination "$policyFile.bak" -Force -ErrorAction SilentlyContinue
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
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction SilentlyContinue
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
