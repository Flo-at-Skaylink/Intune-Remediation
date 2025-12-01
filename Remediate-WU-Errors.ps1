
<#
.SYNOPSIS
    This script remediates Windows Update errors on Windows devices.

.DESCRIPTION
    This script performs various actions to remediate Windows Update errors, including stopping services,
    removing files, resetting components, re-registering DLLs, resetting service SDDL, and cleaning WSUS remnants.

.EXAMPLE
    .\Remediate-WU-Errors.ps1
    Runs the script to remediate Windows Update errors on Windows devices.

.NOTES
    Author: Florian Aschbichler
    Date: 01.12.2025
    Version: 1.3 (logging-preserving refactor)
    Requires administrative privileges.
#>

# Log folder
$logfolder = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"

# Ensure log folder exists
try {
    if (!(Test-Path $logfolder)) { New-Item -Path $logfolder -ItemType Directory -Force | Out-Null }
}
catch { }

# Create log file name
$logFile = Join-Path $logfolder "Remediate-WU-Errors.log"

# Function to write logs
Function Write-Log {
    param ([string]$Message)
    $TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Add-Content -Path $logFile -Value "$TimeStamp - $Message"
}

# Start remediation process
Write-Output "Start remediating Windows Upgrade errors"
Write-Log -Message "Start remediating Windows Upgrade errors"

# Set error action preference
$ErrorActionPreference = 'Stop'

# Helper: Registry-Pfad sichern (reg export)  -- FIX: nutzt $logfolder statt $logRoot
function Backup-RegistryPath {
    param([Parameter(Mandatory)][string]$RegPath)
    try {
        $export = Join-Path $logfolder ("Backup_{0:yyyyMMdd_HHmmss}.reg" -f (Get-Date))
        $regPathNative = $RegPath -replace 'HKLM:', 'HKEY_LOCAL_MACHINE'
        & reg.exe export "$regPathNative" "$export" /y | Out-Null
        Write-Log "Registry backup for $RegPath exported to $export"
    }
    catch { Write-Log "Registry backup warning for $RegPath $_" }
}

# Helper: Wait for service status change stopped
function Wait-ServiceStopped {
    param([System.ServiceProcess.ServiceController]$Service, [int]$Seconds = 25)
    try {
        $Service.WaitForStatus(
            [System.ServiceProcess.ServiceControllerStatus]::Stopped,
            (New-TimeSpan -Seconds $Seconds)
        ) | Out-Null
    }
    catch { Write-Log "Wait stopped warning for $($Service.Name): $_" }
}

# Helper: Wait for service status change running
function Wait-ServiceRunning {
    param([System.ServiceProcess.ServiceController]$Service, [int]$Seconds = 25)
    try {
        $Service.WaitForStatus(
            [System.ServiceProcess.ServiceControllerStatus]::Running,
            (New-TimeSpan -Seconds $Seconds)
        ) | Out-Null
    }
    catch { Write-Log "Wait running warning for $($Service.Name): $_" }
}

# Main remediation logic
try {
    Write-Log "=== Start Remediation: WUReset Option 2 + WSUS cleanup ==="


    # A) Remove WSUS setupconfig.ini
    $WSUSConfigPath = 'C:\Users\Default\AppData\Local\Microsoft\Windows\WSUS'
    $ConfigPath = Join-Path $WSUSConfigPath 'setupconfig.ini'
    if (Test-Path $ConfigPath) {
        Write-Log "Removing setupconfig.ini at $ConfigPath"
        Remove-Item -Path $ConfigPath -Force -ErrorAction SilentlyContinue
    }


    # B) wuauclt.exe beenden
    Write-Log "Killing wuauclt.exe if present"
    Get-Process -Name 'wuauclt' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    # C) Dienste stoppen (BITS, WUAUSERV, APPIDSVC, CRYPTSVC)
    foreach ($s in 'bits', 'wuauserv', 'appidsvc', 'cryptsvc') {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -ne 'Stopped') {
                Write-Log "Stopping service: $s"
                Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
                Wait-ServiceStopped -Service $svc -Seconds 25
            }
        }
        else {
            Write-Log "Service $s not present (OK)"
        }
    }

    # D) qmgr*.dat löschen (beide bekannten Speicherorte)
    Write-Log "Deleting qmgr*.dat files"
    $qmgrPaths = @(
        Join-Path $env:ALLUSERSPROFILE 'Application Data\Microsoft\Network\Downloader',
        Join-Path $env:ALLUSERSPROFILE 'Microsoft\Network\Downloader'
    ) | Where-Object { Test-Path $_ }
    foreach ($p in $qmgrPaths) {
        Get-ChildItem -Path $p -Filter 'qmgr*.dat' -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Log "Deleting $($_.FullName)"
            Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    # E) Ordner/Dateien sichern/umbenennen
    $sd = Join-Path $env:windir 'SoftwareDistribution'
    if (Test-Path $sd) {
        $sdBak = "$sd.bak"
        if (Test-Path $sdBak) {
            Write-Log "Removing old $sdBak"
            Remove-Item -Path $sdBak -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Log "Renaming $sd -> $sdBak"
        Rename-Item -Path $sd -NewName (Split-Path $sdBak -Leaf) -ErrorAction SilentlyContinue
    }

    $cr = Join-Path $env:windir 'System32\Catroot2'
    if (Test-Path $cr) {
        $crBak = "$cr.bak"
        if (Test-Path $crBak) {
            Write-Log "Removing old $crBak"
            Remove-Item -Path $crBak -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Log "Renaming $cr -> $crBak"
        Rename-Item -Path $cr -NewName (Split-Path $crBak -Leaf) -ErrorAction SilentlyContinue
    }

    $pending = Join-Path $env:windir 'winsxs\pending.xml'
    if (Test-Path $pending) {
        $pendingBak = "$pending.bak"
        if (Test-Path $pendingBak) { Remove-Item -Path $pendingBak -Force -ErrorAction SilentlyContinue }
        Write-Log "Renaming $pending -> $pendingBak"
        Rename-Item -Path $pending -NewName (Split-Path $pendingBak -Leaf) -ErrorAction SilentlyContinue
    }

    $wulog = Join-Path $env:windir 'WindowsUpdate.log'
    if (Test-Path $wulog) {
        $wulogBak = "$wulog.bak"
        if (Test-Path $wulogBak) { Remove-Item -Path $wulogBak -Force -ErrorAction SilentlyContinue }
        Write-Log "Renaming $wulog -> $wulogBak"
        Rename-Item -Path $wulog -NewName (Split-Path $wulogBak -Leaf) -ErrorAction SilentlyContinue
    }

    # F) SDDL der Dienste auf Default setzen (wie WUReset)
    Write-Log "Resetting service security descriptors (SDDL)"
    $sddl = @{
        'wuauserv'         = 'D:(A;CI;CCLCSWRPLORC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)S:(AU;FA;CCDCLCSWRPWPDTLOSDRCWDWO;;;WD)';
        'bits'             = 'D:(A;CI;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)S:(AU;SAFA;WDWO;;;BA)';
        'cryptsvc'         = 'D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)(A;;CCLCSWRPWPDTLOCRRC;;;SO)(A;;CCLCSWLORC;;;AC)(A;;CCLCSWLORC;;;S-1-15-3-1024-3203351429-2120443784-2872670797-1918958302-2829055647-4275794519-765664414-2751773334)';
        'trustedinstaller' = 'D:(A;CI;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRRC;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)S:(AU;SAFA;WDWO;;;BA)';
    }
    foreach ($name in $sddl.Keys) {
        try {
            Write-Log "sc.exe sdset $name ..."
            & sc.exe sdset $name "$($sddl[$name])" | Out-Null
        }
        catch { Write-Log "SDDL reset warning for $name $_" }
    }

    # G) Re-Registrierung der DLLs (nur wenn vorhanden)
    Write-Log "Re-registering BITS/Windows Update related DLLs (if present)"
    $dlls = @(
        'atl.dll', 'urlmon.dll', 'mshtml.dll', 'shdocvw.dll', 'browseui.dll', 'jscript.dll', 'vbscript.dll', 'scrrun.dll',
        'msxml.dll', 'msxml3.dll', 'msxml6.dll', 'actxprxy.dll', 'softpub.dll', 'wintrust.dll', 'dssenh.dll', 'rsaenh.dll',
        'gpkcsp.dll', 'sccbase.dll', 'slbcsp.dll', 'cryptdlg.dll', 'oleaut32.dll', 'ole32.dll', 'shell32.dll', 'initpki.dll',
        'wuapi.dll', 'wuaueng.dll', 'wuaueng1.dll', 'wucltui.dll', 'wups.dll', 'wups2.dll', 'wuweb.dll', 'qmgr.dll',
        'qmgrprxy.dll', 'wucltux.dll', 'muweb.dll', 'wuwebv.dll'
    )
    $sys32 = Join-Path $env:windir 'System32'
    foreach ($d in $dlls) {
        $path = Join-Path $sys32 $d
        if (Test-Path $path) {
            try {
                Start-Process -FilePath "$sys32\regsvr32.exe" -ArgumentList "/s `"$path`"" -WindowStyle Hidden -Wait
            }
            catch { Write-Log "regsvr32 failed for $d $_" }
        }
        else {
            Write-Log "DLL not found (skipped): $d"
        }
    }

    # H) Winsock/WinHTTP Reset
    Write-Log "Resetting Winsock and WinHTTP proxy"
    & netsh winsock reset           | Out-Null
    & netsh winhttp reset proxy     | Out-Null

    # I) Starttypen setzen (wie WUReset)
    Write-Log "Setting service start types"
    & sc.exe config wuauserv        start= auto         | Out-Null
    & sc.exe config bits            start= delayed-auto | Out-Null
    & sc.exe config cryptsvc        start= auto         | Out-Null
    & sc.exe config TrustedInstaller start= demand      | Out-Null
    # DcomLaunch ist i. d. R. bereits Auto/Running; Konfig-Fehler hier sind unkritisch
    & sc.exe config DcomLaunch      start= auto         | Out-Null

    # J) WSUS und GPO altlasten entfernen
    # Registry Path checks
    $regChecksPath = @(
        @{Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators" },
        @{Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache\CacheSet001\WindowsUpdate" },
        @{Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache\CacheSet002\WindowsUpdate" }
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
        @{ Name = "WUStatusServer"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" },
        @{ Name = "UpdateServiceUrlAlternate"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" }
    )

    # Remove regkey presence
    foreach ($setting in $regChecksKeys) {
        if (Test-Path $setting.Path) {
            $prop = Get-ItemProperty -Path $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue
            if ($null -ne $prop) {
                Write-Output "Issue detected: Registry key '$($setting.Name)' present."
                Write-Log     "Issue detected: Registry key '$($setting.Name)' present."
                Remove-ItemProperty -Path $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue
            }
        }
    }

    # Set regkey values if needed
    foreach ($setting in $regChecksKeyValue) {
        if (Test-Path $setting.Path) {
            $prop = Get-ItemProperty -Path $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue
            if ($null -ne $prop) {
                if ($prop.$($setting.Name) -ne $setting.Value) {
                    Write-Output "Issue detected: Set Registry key value to $($setting.Value) for $($setting.Name) at $($setting.Path)"
                    Write-Log     "Issue detected: Set Registry key value to $($setting.Value) for $($setting.Name) at $($setting.Path)"
                    Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # Delete registry paths
    foreach ($regPath in $regChecksPath) {
        if (Test-Path $regPath.Path) {
            Write-Log "Issue detected: Removing Registry path: $($regPath.Path)"
            Remove-Item -Path $regPath.Path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # K) Dienste starten (wie WUReset)
    Write-Log "Starting Windows Update services"
    foreach ($s in @('bits', 'wuauserv', 'appidsvc', 'cryptsvc', 'DcomLaunch')) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Running') {
            try {
                Start-Service -Name $s -ErrorAction SilentlyContinue
                Wait-ServiceRunning -Service $svc -Seconds 25
            }
            catch { Write-Log "Start warning for $s $_" }
        }
    }

    # M) Scan anstoßen (best effort)
    # Trigger Telemetry appraiser run
    Write-Log "Triggering CompatTelRunner appraiser run"
    Start-Process -FilePath "C:\Windows\System32\CompatTelRunner.exe" -ArgumentList "-m:appraiser.dll -f:DoScheduledTelemetryRun" -NoNewWindow -Wait
    
    # Trigger WU scan
    $uso = Join-Path $env:SystemRoot 'System32\UsoClient.exe'
    if (Test-Path $uso) {
        Write-Log "Triggering Windows Update scan via UsoClient StartInteractiveScan"
        Start-Process -FilePath $uso -ArgumentList 'StartInteractiveScan' -WindowStyle Hidden
    }
    else {
        Write-Log "UsoClient not found; triggering WU COM API search (best effort)"
        try {
            $session = New-Object -ComObject Microsoft.Update.Session
            $searcher = $session.CreateUpdateSearcher()
            $null = $searcher.Search("IsInstalled=0 and Type='Software'")
        }
        catch { Write-Log "COM scan trigger failed: $_" }
    }

    Write-Log "=== Remediation completed successfully ==="
    exit 0
}
catch {
    Write-Log "Remediation failed: $_"
    exit 1
}
