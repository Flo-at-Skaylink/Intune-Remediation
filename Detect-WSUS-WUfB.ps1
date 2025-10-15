<#

.SYNOPSIS
    Detects WSUS configuration by checking the presence of setupconfig.ini and setupconfig.ini.bak files.

.DESCRIPTION
    This script checks for the presence of setupconfig.ini and setupconfig.ini.bak files
    and determines the current state of WSUS configuration.

.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    .\Remediate-WSUS-WUfB.ps1
    Runs the script to remediate WSUS configuration on Windows devices.

.NOTES
    Author: Florian Aschbichler
    Date: 27.08.2025
    Version: 1.0
    Requires administrative privileges.

#>

#Log folder
$logfolder = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"

# Create log file name
$logFile = Join-Path $logfolder "Detect-WSUS-WUfB.log"

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
Write-Output "Start detecting WSUS configuration"
Write-Log -message "Start detecting WSUS configuration"

# Set error action preference
$ErrorActionPreference = 'Stop'

# Define paths
$BasePath = 'C:\Users\Default\AppData\Local\Microsoft\Windows\WSUS'
$Config   = Join-Path -Path $BasePath -ChildPath 'setupconfig.ini'
$Backup   = Join-Path -Path $BasePath -ChildPath 'setupconfig.ini.bak'

# Start detection process
try {
    if (Test-Path -LiteralPath $Config) {
        Write-Output "setupconfig.ini present → remediation required."
        Write-Log "setupconfig.ini present → remediation required."
        exit 1
    }

    if (Test-Path -LiteralPath $Backup) {
        Write-Output "setupconfig.ini.bak already present → no action needed."
        Write-Log "setupconfig.ini.bak already present → no action needed."
        exit 0
    }

    Write-Output "Neither setupconfig.ini nor setupconfig.ini.bak present → no action."
    Write-Log "Neither setupconfig.ini nor setupconfig.ini.bak present → no action."
    exit 0
}
catch {
    Write-Error "Detection failed: $($_.Exception.Message)"
    Write-Log "Detection failed: $($_.Exception.Message)"
    # Be conservative: trigger remediation on detection error.
    exit 1
}