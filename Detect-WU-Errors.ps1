<#

.SYNOPSIS


.DESCRIPTION


.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    .\Detect-WU-Errors.ps1
    Runs the script to detect Windows Update errors on Windows devices.

.NOTES
    Author: Florian Aschbichler
    Date: 27.08.2025
    Version: 1.0
    Requires administrative privileges.

#>

#Log folder
$logfolder = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"

# Create log file name
$logFile = Join-Path $logfolder "Detect-WU-Errors.log"

# Function to write logs
# This function logs messages to a specified log file with a timestamp.
Function Write-Log {
    param (
        $message
    )

    $TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Add-Content $LogFile  "$TimeStamp - $message"
}

# Start detection process
Write-Output "Start detecting Windows Upgrade errors"
Write-Log -message "Start detecting Windows Upgrade errors"

# Set error action preference
$ErrorActionPreference = 'Stop'

$sinceDays = 7
$since      = (Get-Date).AddDays(-$sinceDays)
$needsFix   = $false
$log        = @()

try {
    # 1) Bereits 24H2?
    $cvKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $dispVer = (Get-ItemProperty -Path $cvKey -Name DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion
    if ($dispVer -eq '24H2') {
        Write-Output "Already on 24H2. No action."
        exit 0
    }

    # 2) Fehlercode 0xC190012E in den Events?
    $evtFail = @()

    # System-Log: WindowsUpdateClient ID 20 = Installation failure
    $evtFail += Get-WinEvent -FilterHashtable @{
        LogName      = 'System'
        ProviderName = 'Microsoft-Windows-WindowsUpdateClient'
        Id           = 20
        StartTime    = $since
    } -ErrorAction SilentlyContinue

    # Operational-Log des WindowsUpdateClient (breiter filtern, dann Text prüfen)
    $evtOp = Get-WinEvent -FilterHashtable @{
        LogName   = 'Microsoft-Windows-WindowsUpdateClient/Operational'
        StartTime = $since
    } -ErrorAction SilentlyContinue

    if ($evtOp) {
        # Nur Events, die typischerweise Fehler tragen
        $evtFail += $evtOp | Where-Object { $_.Id -in 20,25,31,34,35,40,2004,204,205 }
    }

    $hit = $evtFail | Where-Object { $_.Message -match '0xC190012E' }

    if ($hit) {
        $needsFix = $true
        $last = $hit | Select-Object -First 1
        $log += "Last 0xC190012E at: $($last.TimeCreated)"
    }

    if ($needsFix) {
        Write-Output ("Detection: 0xC190012E found within last {0} days. Remediation required." -f $sinceDays)
        Write-Output ($log -join "`n")
        exit 1
    } else {
        Write-Output "Detection: No recent 0xC190012E found or already on 24H2."
        exit 0
    }
}
catch {
    Write-Warning "Detection error: $_"
    # Im Zweifel lieber remediaten
    exit 1
}
