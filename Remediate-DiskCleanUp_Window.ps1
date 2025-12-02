
# =========================
# WPF Disk Cleanup Helper + Registry config for SageRun:1
# =========================
# CleanMgr: cleans everything EXCEPT Recycle Bin and Downloaded Program Files
# UI: German | Logs: English
# Features: Base64 Logo, Disk Space UI, Buttons, Indeterminate Progress, Auto Refresh
# =========================

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName PresentationCore

# --- Settings ---
$logFolder       = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$logFile         = Join-Path $logFolder "Remediate-DiskCleanUp_Windows.log"
$Picture_Base64 = "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"   # base64 string for hero image (728x360 recommended)
$HeroImagePath   = "$env:TEMP\HeroPicture.png"
$DownloadsPath   = Join-Path ([Environment]::GetFolderPath('UserProfile')) "Downloads"
$SageRunId       = 1  # /sagerun:1

# --- Ensure STA (required for WPF) ---
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Output "This script requires STA. Relaunch PowerShell with -STA or run from a STA host."
    return
}

# --- Logging ---
if (-not (Test-Path -Path $logFolder)) {
    try {
        New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
        Write-Output "Log folder created: $logFolder"
    } catch {
        Write-Output "ERROR creating log folder: $logFolder - $_"
    }
}
Function Write-Log {
    param([string]$Message)
    $TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    try {
        Add-Content -Path $logFile -Value "$TimeStamp - $Message"
    } catch {
        Write-Output "ERROR writing to log file: $_"
    }
    Write-Output $Message
}

Write-Log "=== Disk cleanup helper started ==="

# --- Helpers ---
function Get-FreeSpaceGB {
    try {
        return [math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)
    } catch {
        Write-Log "ERROR retrieving free space: $_"
        return $null
    }
}

# --- Registry configuration for CleanMgr SageRun:1 ---
# Include all relevant caches EXCEPT 'Recycle Bin' and 'Downloaded Program Files'
# (to leave deletion of user content entirely to the user).
$CleanupSelections = @(
    'Active Setup Temp Folders', 'BranchCache', 'Content Indexer Cleaner', 'Device Driver Packages',
    # 'Downloaded Program Files',   # EXCLUDED intentionally per requirements
    'GameNewsFiles', 'GameStatisticsFiles', 'GameUpdateFiles',
    'Internet Cache Files', 'Memory Dump Files', 'Offline Pages Files', 'Old ChkDsk Files',
    'Previous Installations',
    # 'Recycle Bin',                # EXCLUDED intentionally per requirements
    'Service Pack Cleanup', 'Setup Log Files',
    'System error memory dump files', 'System error minidump files',
    'Temporary Files', 'Temporary Setup Files', 'Temporary Sync Files',
    'Thumbnail Cache', 'Update Cleanup', 'Upgrade Discarded Files', 'User file versions',
    'Windows Defender',
    'Windows Error Reporting Archive Files', 'Windows Error Reporting Queue Files',
    'Windows Error Reporting System Archive Files', 'Windows Error Reporting System Queue Files',
    'Windows ESD installation files', 'Windows Upgrade Log Files'
)

function Set-SageRunRegistry {
    param(
        [int]$RunId,
        [string[]]$Selections
    )
    $stateName = "StateFlags{0:D4}" -f $RunId
    $basePath  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"

    Write-Log "Configuring CleanMgr registry: $stateName = 2 for selected caches (excluding Recycle Bin & Downloaded Program Files)."
    foreach ($keyName in $Selections) {
        $path = Join-Path $basePath $keyName
        try {
            if (-not (Test-Path $path)) {
                Write-Log "INFO: VolumeCaches key missing (OS may not have this cache): $keyName"
                continue
            }
            New-ItemProperty -Path $path -Name $stateName -Value 2 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
            Write-Log "Set $stateName=2 for '$keyName'"
        } catch {
            Write-Log "ERROR setting $stateName for '$keyName': $_"
        }
    }

    # Ensure explicitly that excluded keys are NOT set to this RunId (safety guard)
    foreach ($excluded in @('Recycle Bin','Downloaded Program Files')) {
        $excludedPath = Join-Path $basePath $excluded
        if (Test-Path $excludedPath) {
            try {
                $prop = Get-ItemProperty -Path $excludedPath -ErrorAction Stop
                $existing = $prop.PSObject.Properties.Name | Where-Object { $_ -like "StateFlags*" }
                foreach ($name in $existing) {
                    if ($name -eq $stateName) {
                        Remove-ItemProperty -Path $excludedPath -Name $stateName -ErrorAction SilentlyContinue
                        Write-Log "Removed $stateName from excluded cache '$excluded'"
                    }
                }
            } catch {
                Write-Log "WARN ensuring exclusion for '$excluded': $_"
            }
        }
    }
}

function Test-SageRunRegistry {
    param([int]$RunId, [string[]]$Selections)
    $stateName = "StateFlags{0:D4}" -f $RunId
    $basePath  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"

    Write-Log "Validating CleanMgr registry configuration ($stateName)."
    foreach ($keyName in $Selections) {
        $path = Join-Path $basePath $keyName
        try {
            if (-not (Test-Path $path)) {
                Write-Log "VALIDATION: Missing key (skip): $keyName"
                continue
            }
            $prop = Get-ItemProperty -Path $path -ErrorAction Stop
            if ($prop.PSObject.Properties.Name -contains $stateName) {
                $val = $prop.$stateName
                if ($val -eq 2) {
                    Write-Log "VALIDATION: OK '$keyName' -> $stateName=2"
                } else {
                    Write-Log "VALIDATION: WARN '$keyName' -> $stateName=$val (expected 2)"
                }
            } else {
                Write-Log "VALIDATION: MISSING '$keyName' -> $stateName"
            }
        } catch {
            Write-Log "VALIDATION: ERROR reading '$keyName': $_"
        }
    }

    foreach ($excluded in @('Recycle Bin','Downloaded Program Files')) {
        $path = Join-Path $basePath $excluded
        if (Test-Path $path) {
            try {
                $prop = Get-ItemProperty -Path $path -ErrorAction Stop
                if ($prop.PSObject.Properties.Name -contains $stateName) {
                    Write-Log "VALIDATION: FAIL Excluded '$excluded' has $stateName present."
                } else {
                    Write-Log "VALIDATION: OK Excluded '$excluded' does NOT have $stateName."
                }
            } catch {
                Write-Log "VALIDATION: ERROR reading excluded '$excluded': $_"
            }
        } else {
            Write-Log "VALIDATION: INFO excluded key not present: '$excluded'"
        }
    }
}

# --- Decode Base64 Logo (if provided) ---
try {
    if ($Picture_Base64 -and $Picture_Base64 -ne 'xx') {
        [byte[]]$Bytes = [Convert]::FromBase64String($Picture_Base64)
        [System.IO.File]::WriteAllBytes($HeroImagePath, $Bytes) | Out-Null
        Write-Log "Hero image created: $HeroImagePath"
    } else {
        $HeroImagePath = $null
        Write-Log "No hero image provided (Picture_Base64 empty or 'xx')."
    }
} catch {
    Write-Log "ERROR creating hero image from Base64: $_"
    $HeroImagePath = $null
}

# --- Initial Free Space ---
$FreeSpaceGB = Get-FreeSpaceGB
if ($null -ne $FreeSpaceGB) {
    Write-Log "Current free space: $FreeSpaceGB GB"
}

# --- Apply registry configuration before UI ---
Set-SageRunRegistry -RunId $SageRunId -Selections $CleanupSelections
Validate-SageRunRegistry -RunId $SageRunId -Selections $CleanupSelections

# --- Build WPF Window ---
$Window = New-Object Windows.Window
$Window.Title = "Speicherbereinigung"
$Window.Width = 520
$Window.Height = 480
$Window.WindowStartupLocation = "CenterScreen"

$Root = New-Object Windows.Controls.Grid
$Root.Margin = "20"
$Root.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition)) | Out-Null  # Logo
$Root.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition)) | Out-Null  # Title
$Root.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition)) | Out-Null  # Message
$Root.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition)) | Out-Null  # Progress
$Root.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition)) | Out-Null  # Buttons
$Window.Content = $Root

# Logo
if ($HeroImagePath -and (Test-Path $HeroImagePath)) {
    $ImageControl = New-Object Windows.Controls.Image
    $ImageControl.Source = [System.Windows.Media.Imaging.BitmapImage]::new([Uri]::new($HeroImagePath))
    $ImageControl.Height = 100
    $ImageControl.Margin = "0,0,0,10"
    [Windows.Controls.Grid]::SetRow($ImageControl, 0)
    $Root.Children.Add($ImageControl) | Out-Null
}

# Title
$Title = New-Object Windows.Controls.TextBlock
$Title.Text = "Mehr Speicher für Windows 11 Upgrade"
$Title.FontSize = 18
$Title.FontWeight = 'Bold'
$Title.Margin = "0,0,0,6"
[Windows.Controls.Grid]::SetRow($Title, 1)
$Root.Children.Add($Title) | Out-Null

# Message
$Message = New-Object Windows.Controls.TextBlock
$Message.Text = "Freier Speicher auf C:: " + ($null -ne $FreeSpaceGB ? "$FreeSpaceGB GB" : "unbekannt") + ". Bitte nutzen Sie die Optionen unten."
$Message.TextWrapping = "Wrap"
$Message.Margin = "0,0,0,16"
[Windows.Controls.Grid]::SetRow($Message, 2)
$Root.Children.Add($Message) | Out-Null

# Progress area
$ProgressPanel = New-Object Windows.Controls.StackPanel
$ProgressPanel.Orientation = 'Vertical'
$ProgressPanel.Margin = "0,0,0,16"
[Windows.Controls.Grid]::SetRow($ProgressPanel, 3)
$Root.Children.Add($ProgressPanel) | Out-Null

$StatusText = New-Object Windows.Controls.TextBlock
$StatusText.Text = "Bereit."
$StatusText.Margin = "0,0,0,6"
$ProgressPanel.Children.Add($StatusText) | Out-Null

$ProgressBar = New-Object Windows.Controls.ProgressBar
$ProgressBar.Height = 16
$ProgressBar.Minimum = 0
$ProgressBar.Maximum = 100
$ProgressBar.Value = 0
$ProgressBar.IsIndeterminate = $false
$ProgressPanel.Children.Add($ProgressBar) | Out-Null

# Buttons
$ButtonsPanel = New-Object Windows.Controls.StackPanel
$ButtonsPanel.Orientation = 'Vertical'
$ButtonsPanel.Margin = "0,0,0,0"
[Windows.Controls.Grid]::SetRow($ButtonsPanel, 4)
$Root.Children.Add($ButtonsPanel) | Out-Null

$BtnDownloads = New-Object Windows.Controls.Button
$BtnDownloads.Content = "Downloads öffnen"
$BtnDownloads.Margin = "0,0,0,8"
$ButtonsPanel.Children.Add($BtnDownloads) | Out-Null

$BtnRecycle = New-Object Windows.Controls.Button
$BtnRecycle.Content = "Papierkorb öffnen"
$BtnRecycle.Margin = "0,0,0,8"
$ButtonsPanel.Children.Add($BtnRecycle) | Out-Null

$BtnClean = New-Object Windows.Controls.Button
$BtnClean.Content = "Jetzt bereinigen"
$BtnClean.Margin = "0,0,0,8"
$ButtonsPanel.Children.Add($BtnClean) | Out-Null

$BtnRefresh = New-Object Windows.Controls.Button
$BtnRefresh.Content = "Freien Speicher aktualisieren"
$BtnRefresh.Margin = "0,12,0,0"
$ButtonsPanel.Children.Add($BtnRefresh) | Out-Null

# --- Event handlers ---
$BtnDownloads.Add_Click({
    try {
        Start-Process explorer.exe $DownloadsPath
        Write-Log "Downloads opened: $DownloadsPath"
    } catch {
        Write-Log "ERROR opening Downloads: $_"
        [System.Windows.MessageBox]::Show("Fehler beim Öffnen der Downloads.", "Fehler")
    }
})

$BtnRecycle.Add_Click({
    try {
        Start-Process explorer.exe "shell:RecycleBinFolder"
        Write-Log "Recycle Bin opened."
    } catch {
        Write-Log "ERROR opening Recycle Bin: $_"
        [System.Windows.MessageBox]::Show("Fehler beim Öffnen des Papierkorbs.", "Fehler")
    }
})

function Update-FreeSpaceUi {
    $fs = Get-FreeSpaceGB
    if ($null -ne $fs) {
        $Message.Text = "Freier Speicher auf C:: $fs GB. Bitte nutzen Sie die Optionen unten."
        Write-Log "Free space refreshed: $fs GB"
    } else {
        $Message.Text = "Freier Speicher auf C:: unbekannt."
        Write-Log "Free space refresh failed."
    }
}

$BtnRefresh.Add_Click({ Update-FreeSpaceUi })

# Clean action with animated progress and auto refresh
$BtnClean.Add_Click({
    try {
        # Ensure registry config right before run (in case of external changes)
        Set-SageRunRegistry -RunId $SageRunId -Selections $CleanupSelections
        Test-SageRunRegistry -RunId $SageRunId -Selections $CleanupSelections

        # Prepare UI
        $StatusText.Text = "Bereinigung läuft..."
        $ProgressBar.IsIndeterminate = $true
        $BtnClean.IsEnabled = $false
        $BtnDownloads.IsEnabled = $false
        $BtnRecycle.IsEnabled = $false
        $BtnRefresh.IsEnabled = $false

        Write-Log "Cleanup started (CleanMgr /sagerun:$SageRunId)."

        # Start CleanMgr (no -Wait, to allow animation)
        $proc = Start-Process -FilePath CleanMgr.exe -ArgumentList "/sagerun:$SageRunId" -PassThru -ErrorAction Stop

        # Timer: poll process state and keep UI responsive
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(400)
        $timer.Add_Tick({
            if (-not (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
                $timer.Stop()

                # Finalize UI
                $ProgressBar.IsIndeterminate = $false
                $ProgressBar.Value = 100
                $StatusText.Text = "Bereinigung abgeschlossen."

                # Re-enable buttons
                $BtnClean.IsEnabled = $true
                $BtnDownloads.IsEnabled = $true
                $BtnRecycle.IsEnabled = $true
                $BtnRefresh.IsEnabled = $true

                # Auto-refresh free space
                Update-FreeSpaceUi

                Write-Log "Cleanup completed."
                [System.Windows.MessageBox]::Show("Bereinigung abgeschlossen. Der freie Speicher wurde aktualisiert.", "Fertig")
            } else {
                $StatusText.Text = "Bereinigung läuft..."
            }
        })
        $timer.Start()
    } catch {
        $ProgressBar.IsIndeterminate = $false
        $ProgressBar.Value = 0
        $StatusText.Text = "Fehler bei der Bereinigung."
        $BtnClean.IsEnabled = $true
        $BtnDownloads.IsEnabled = $true
        $BtnRecycle.IsEnabled = $true
        $BtnRefresh.IsEnabled = $true

        Write-Log "ERROR starting cleanup: $_"
        [System.Windows.MessageBox]::Show("Fehler beim Starten von CleanMgr.", "Fehler")
    }
})

# Show window
$Window.ShowDialog() | Out-Null

Write-Log "=== Disk cleanup helper closed ==="