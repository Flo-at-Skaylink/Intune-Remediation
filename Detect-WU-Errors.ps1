<#

.SYNOPSIS
    Detect Windows Update errors on Windows devices.

.DESCRIPTION
    Checks for common Windows Update issues by inspecting policy registry values and
    querying Windows Update Client events (Critical/Error) from the last 7 days.
    If any issues are detected, exits with 1 to trigger remediation.

.EXAMPLE
    .\Detect-WU-Errors.ps1

.NOTES
    Author: Florian Aschbichler
    Date: 01.12.2025
    Version: 1.2
    Requires administrative privileges.
    
#>

# Init & Logging
$logFolder = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$logFile = Join-Path $logFolder "Detect-WU-Errors.log"

# Ensure log folder exists
if (-not (Test-Path -Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

# Function to write logs
Function Write-Log {
    param ([string]$Message)
    $TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Add-Content -Path $logFile -Value "$TimeStamp - $Message"
}

Write-Output "Start detecting Windows Update and Upgrade errors"
Write-Log     "Start detecting Windows Update and Upgrade errors"

# Registry Path checks
$regChecksPath = @(
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators" }
)

# Registry Key-Value checks
$regChecksKeyValue = @(
    @{ Name = "DoNotConnectToWindowsUpdateInternetLocations"; Value = 0; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" },
    @{ Name = "DisableWindowsUpdateAccess"; Value = 0; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" },
    @{ Name = "DisableDualScan"; Value = 0; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" },
    @{ Name = "UseWUServer"; Value = 0; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" },
    @{ Name = "NoAutoUpdate"; Value = 0; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" },
    @{ Name = "UseUpdateClassPolicySource"; Value = 1; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" },
    @{ Name = "SetPolicyDrivenUpdateSourceForDriverUpdates"; Value = 0; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" },
    @{ Name = "SetPolicyDrivenUpdateSourceForOtherUpdates"; Value = 0; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" },
    @{ Name = "SetPolicyDrivenUpdateSourceForQualityUpdates"; Value = 0; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" },
    @{ Name = "SetPolicyDrivenUpdateSourceForFeatureUpdates"; Value = 0; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" }
)

#Registry Key presence checks
$regChecksKeys = @(
    @{ Name = "WUServer"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" },
    @{ Name = "TargetGroup"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" },
    @{ Name = "TargetGroupEnabled"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" },
    @{ Name = "WUStatusServer"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" }
    @{ Name = "UpdateServiceUrlAlternate"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" }
)

# Event filter
$filter = @{
    ProviderName = 'Microsoft-Windows-WindowsUpdateClient'
    Level        = 1, 2
    StartTime    = (Get-Date).AddDays(-7)
}

# WSUS setupconfig paths
$WSUSConfigPath = 'C:\Users\Default\AppData\Local\Microsoft\Windows\WSUS'
$ConfigPath = Join-Path $WSUSConfigPath 'setupconfig.ini'
$BackupPath = Join-Path $WSUSConfigPath 'setupconfig.ini.bak'

# Initialize remediation flag
$RemediationNeeded = $false

# Detection logic
try {
    # Check TargetVersionUpgradeExperienceIndicators
    foreach ($regCheck in $regChecksPath) {
        if (Test-Path $regCheck.Path) {
            Write-Output "Issue detected: Registry key 'TargetVersionUpgradeExperienceIndicators' exists."
            Write-Log     "Issue detected: Registry key 'TargetVersionUpgradeExperienceIndicators' exists."
            $RemediationNeeded = $true
        }
    }
    # Check regkey values
    foreach ($setting in $regChecksKeyValue) {
        if (Test-Path $setting.Path) {
            $prop = Get-ItemProperty -Path $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue
            if ($null -ne $prop) {
                if ($prop.$($setting.Name) -ne $setting.Value) {
                    Write-Output "Issue detected: Registry key value '$($setting.Name)' is '$($prop.$($setting.Name))', expected '$($setting.Value)'."
                    Write-Log     "Issue detected: Registry key value '$($setting.Name)' is '$($prop.$($setting.Name))', expected '$($setting.Value)'."
                    $RemediationNeeded = $true
                }
            }
        }
    }

    # Check regkey presence
    foreach ($setting in $regChecksKeys) {
        if (Test-Path $setting.Path) {
            $prop = Get-ItemProperty -Path $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue
            if ($null -ne $prop) {
                Write-Output "Issue detected: Registry key '$($setting.Name)' present."
                Write-Log     "Issue detected: Registry key '$($setting.Name)' present."
                $RemediationNeeded = $true
            }
        }
    }

    # Event log check
    $events = Get-WinEvent -FilterHashtable $filter -MaxEvents 200 -ErrorAction SilentlyContinue
    if ($events.Count -gt 0) {
        Write-Output "Issue detected: $($events.Count) Critical/Error Windows Update events in last 7 days."
        Write-Log     "Issue detected: $($events.Count) Critical/Error Windows Update events in last 7 days."
        $RemediationNeeded = $true
    }

    # WSUS setupconfig.ini check
    if (Test-Path $ConfigPath) {
        Write-Output "Issue detected: setupconfig.ini present → remediation required."
        Write-Log     "Issue detected: setupconfig.ini present → remediation required."
        $RemediationNeeded = $true
    }
    elseif (Test-Path $BackupPath) {
        Write-Output "Info: setupconfig.ini.bak present → previous remediation likely done."
        Write-Log     "Info: setupconfig.ini.bak present → previous remediation likely done."
    }
    else {
        Write-Output "Info: No setupconfig.ini or .bak found."
        Write-Log     "Info: No setupconfig.ini or .bak found."
    }

    # Final decision
    if ($RemediationNeeded) {
        Write-Output "Issue detected: Remediation required."
        exit 1
    }
    else {
        Write-Output "No issue: Remediation not required."
        exit 0
    }
}
catch {
    Write-Output "Error during detection: $_"
    Write-Log     "Error during detection: $_"
    exit 1
}