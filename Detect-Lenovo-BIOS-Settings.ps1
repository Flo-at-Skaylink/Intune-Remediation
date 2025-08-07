<#

.SYNOPSIS
    This script detects if Secure Boot is enabled and if a BIOS password is set on Lenovo devices manufactured after 2018.

.DESCRIPTION
    The script checks the current BIOS settings for Secure Boot status on Lenovo devices. 
    If Secure Boot is enabled, it reports compliance; otherwise, it reports non-compliance.
    It also checks if a BIOS password is set and reports the status accordingly.
    The script handles errors gracefully and provides appropriate output messages.

.PARAMETER None
    This script does not take any parameters.

.EXAMPLE
    Run the script without any parameters:
    .\Detect-Lenovo-BIOS-Settings.ps1

.NOTES
    Author: Florian Aschbichler
    Date: 01.08.2025
    Version: 1.0
    This script requires administrative privileges to run.

#>

#Log folder
$logfolder = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"

# Create log file name
$logFile = Join-Path $logfolder "Detect-Lenovo-BIOS-Settings.log"

# Function to write logs
# This function logs messages to a specified log file with a timestamp.
Function Write-Log {
    param (
        $message
    )

    $TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Add-Content $LogFile  "$TimeStamp - $message"
}

Write-Output "Start detecting Lenovo BIOS Settings"
Write-Log -message "Start detecting Lenovo BIOS Settings"

# Get BIOS Setup Mode
try {
    $isInSetupMode = (Get-SecureBootUEFI -Name SetupMode).Bytes[0] -eq 1
}
catch {
    $isInSetupMode = $false
}

# Check if BIOS is in Setup Mode
if ($isInSetupMode) {
    Write-Output "Bios is in Setup Mode, cannot activate secureboot until this is manually resolved"
    Write-Log -message "Bios is in Setup Mode, cannot activate secureboot until this is manually resolved"
    Exit 1
}
else {
    Write-Output "Bios is not in Setup Mode, proceeding with secureboot check"
    Write-Log -message "Bios is not in Setup Mode, proceeding with secureboot check"
}

# Get BIOS Password State
try {
    $isPasswordState = (Get-WmiObject -Namespace root\wmi -Class Lenovo_BiosPasswordSettings).PasswordState
    switch ($isPasswordState) {
        0 { $returnMessage = 'No passwords set' }
        2 { $returnMessage = 'Supervisor password set' }
        3 { $returnMessage = 'Power on and supervisor passwords set' }
        4 { $returnMessage = 'Hard drive password(s) set' }
        5 { $returnMessage = 'Power on and hard drive passwords set' }
        6 { $returnMessage = 'Supervisor and hard drive passwords set' }
        7 { $returnMessage = 'Supervisor, power on, and hard drive passwords set' }
        64 { $returnMessage = 'Only the System Management Password set' }
        65 { $returnMessage = 'Only the Power-On + System Management Password set' }
        66 { $returnMessage = 'Supervisor + System Management Password set' }
        128 { $returnMessage = 'No passwords - BIOS Certificate in use' }
    }
}
catch {
    $isPasswordState = $false
    $returnMessage = 'Unable to determine password state'
}

# BIOS Supervisor Password is set
if ($isPasswordState -notin (0, 4, 5, 64, 65)) {
    Write-Output "Bios password is set: $returnMessage"
    Write-Log -message "Bios password is set: $returnMessage"
}
# BIOS Supervisor Password is not set
else {
    Write-Output "Bios password is set: $returnMessage"
    Write-Log -message "Bios password is set: $returnMessage"
}

# Get BIOS Secure Boot State
try {
    $isSecureBoot = ((Get-CimInstance -class Lenovo_BiosSetting -namespace root\wmi) | Where-Object { $_.CurrentSetting.StartsWith("SecureBoot") }).CurrentSetting
}
catch {
    $isSecureBoot = $false
}

# Check if Secure Boot is enabled and BIOS password is set
if ($isSecureBoot -eq "SecureBoot,Enable" -and $isPasswordState -in (2, 3, 6, 7, 66)) {
    Write-Output "Compliant - Secure Boot is enabled and BIOS password is set"
    Write-Log -message "Compliant - Secure Boot is enabled and BIOS password is set"
    Exit 0
} 
# Check if Secure Boot is enabled but BIOS password is not set
Elseif ($isSecureBoot -eq "SecureBoot,Enable") {
    Write-Output "Compliant - Secure Boot is enabled"
    Write-Log -message "Compliant - Secure Boot is enabled"
    Exit 0
}
# Secure Boot is not enabled
else {
    Write-Output "NonCompliant - Secure Boot is not enabled"
    Write-Log -message "NonCompliant - Secure Boot is not enabled"
    Exit 1
}