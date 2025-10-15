<#

.SYNOPSIS
    Remediates WSUS configuration by renaming setupconfig.ini to setupconfig.ini.bak.

.DESCRIPTION
    This script checks for the presence of setupconfig.ini and setupconfig.ini.bak files
    and performs the necessary renaming to ensure proper WSUS configuration.

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
$logFile = Join-Path $logfolder "Remediate-WSUS-WUfB.log"

# Function to write logs
# This function logs messages to a specified log file with a timestamp.
Function Write-Log {
    param (
        $message
    )

    $TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Add-Content $logFile  "$TimeStamp - $message"
}

# Start remediation process
Write-Output "Start remediating WSUS configuration"
Write-Log -message "Start remediating WSUS configuration"

# Set error action preference
$ErrorActionPreference = 'Stop'

# Define paths
$BasePath   = 'C:\Users\Default\AppData\Local\Microsoft\Windows\WSUS'
$Config     = Join-Path -Path $BasePath -ChildPath 'setupconfig.ini'
$Backup     = Join-Path -Path $BasePath -ChildPath 'setupconfig.ini.bak'


try {
    # Ensure folder exists (no-op if it already does)
    if (-not (Test-Path -LiteralPath $BasePath)) {
        Write-Output "Base path not found: $BasePath. Nothing to rename."
        Write-Log "Base path not found: $BasePath. Nothing to rename."
        exit 0
    }

    if (-not (Test-Path -LiteralPath $Config)) {
        Write-Output "setupconfig.ini not found. Nothing to rename."
        Write-Log "setupconfig.ini not found. Nothing to rename."
        exit 0
    }

    # If a .bak already exists, archive it rather than overwriting
    if (Test-Path -LiteralPath $Backup) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $Archive = "$Backup.$stamp.old"
        Move-Item -LiteralPath $Backup -Destination $Archive -Force
        Write-Output "Archived existing setupconfig.ini.bak to: $Archive"
        Write-Log "Archived existing setupconfig.ini.bak to: $Archive"
    }

    # Perform the rename
    Move-Item -LiteralPath $Config -Destination $Backup -Force
    Write-Output "Renamed setupconfig.ini → setupconfig.ini.bak successfully."
    Write-Log "Renamed setupconfig.ini → setupconfig.ini.bak successfully."
    exit 0
}
catch {
    Write-Output "Remediation failed: $($_.Exception.Message)"
    Write-Log "Remediation failed: $($_.Exception.Message)"
    exit 1
}