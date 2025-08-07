<#

.SYNOPSIS
    Remediates BIOS settings on Lenovo devices by enabling Secure Boot with a BIOS password if required.

.DESCRIPTION
    Checks current BIOS settings on Lenovo devices and applies remediation as needed.
    Specifically, enables Secure Boot with a configured BIOS password if it is set.

.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    .\Remediate-Lenovo-BIOS-Settings.ps1
    Runs the script to remediate BIOS settings on Lenovo devices.

.NOTES
    Author: Florian Aschbichler
    Date: 01.08.2025
    Version: 1.0
    Requires administrative privileges.

#>

#Log folder
$logfolder = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"

# Create log file name
$logFile = Join-Path $logfolder "Remediate-Lenovo-BIOS-Settings.log"

# Function to write logs
# This function logs messages to a specified log file with a timestamp.
Function Write-Log {
    param (
        $message
    )

    $TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Add-Content $LogFile  "$TimeStamp - $message"
}

# Start remediation process
Write-Output "Start remediating Lenovo BIOS Settings"
Write-Log -message "Start remediating Lenovo BIOS Settings"

# BIOS Passwords
$biosPasswords = @() #example: $biosPasswords = @("password1","password2")

# BIOS WMI Objects
$setBios = (Get-CimInstance -ClassName Lenovo_SetBiosSetting -Namespace root\wmi)
$commitBios = (Get-CimInstance -ClassName Lenovo_SaveBiosSettings -Namespace root\wmi)
$opcodeInterface = (Get-CimInstance -ClassName Lenovo_WmiOpcodeInterface -Namespace root\wmi)

# Initialize counter for failed password attempts
$count = 0

# Initialize flag for successful password
$passwordWorked = $false

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
    Write-Output "Bios password is set: $returnMessage"
    Write-Log -message "Bios password is set: $returnMessage"
}
catch {
    $isPasswordState = $false
    $returnMessage = 'Unable to determine password state'
    Write-Output $returnMessage
    Write-Log -message $returnMessage
}

# BIOS Password is not set on the system, try to activate secureboot without it
if ($isPasswordState -notin (2, 3, 6, 7, 66)) {
    try {
        $setBios.SetBiosSetting("SecureBoot,Enable")
        $commitBios.SaveBiosSettings()
        Write-Output "Secureboot enabled without bios password"
        Write-Log -message "Secureboot enabled without bios password"
        Exit 0
    }
    catch {
        Write-Output $_.Exception.Message
        Write-Log -message $_.Exception.Message
        Exit 1
    }
}

# BIOS is password protected, but no passwords configured
if (($isPasswordState -in (2, 3, 6, 7, 66)) -and ($biosPasswords.count -eq 0)) {
    Write-Output "Bios is password protected, but no passwords configured, cannot enable secureboot"
    Write-Log -message "Bios is password protected, but no passwords configured, cannot enable secureboot"
    Exit 1
}

# BIOS is password protected, and passwords are configured
if ($isPasswordState -in (2, 3, 6, 7, 66) -and $biosPasswords.count -gt 0) {
    Write-Output "Bios is password protected, attempting to enable secureboot with configured passwords"
    Write-Log -message "Bios is password protected, attempting to enable secureboot with configured passwords"

    # Try each configured BIOS password
    foreach ($biosPassword in $biosPasswords) {
        $count++
        # Exit after 2 failed attempts
        if ($count -gt 2) {
            Write-Output "Tried $count passwords, none worked, cannot enable secureboot and will not continue to avoid locking the device"
            write-Log -message "Tried $count passwords, none worked, cannot enable secureboot and will not continue to avoid locking the device"
            Exit 1
        }
        # Try to enable secureboot with the current password
        try {
            $setBios.SetBiosSetting("SecureBoot,Enable,$biosPassword,ascii,gr")
            Write-Output "Secureboot enabled with bios password"
            Write-Log -message "Secureboot enabled with bios password"

            try {
                $opcodeInterface.WmiOpcodeInterface("WmiOpcodePasswordAdmin:$biosPassword")
            }
            catch {
            }

            $commitBios.SaveBiosSettings("$biosPassword,ascii,gr")
            $passwordWorked = $true
            Write-Output "Bios settings committed with password"
            Write-Log -message "Bios settings committed with password"
            break
        }
        catch {
            Write-Output $_.Exception.Message
            Write-Log -message $_.Exception.Message
        }
    }
}

if ($passwordWorked -eq $false) {
    Write-Output "None of the configured bios passwords worked, cannot enable secureboot"
    Write-Log -message "None of the configured bios passwords worked, cannot enable secureboot"
    Exit 1
}

Exit 0