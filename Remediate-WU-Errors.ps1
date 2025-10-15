<#

.SYNOPSIS
    This script remediates Windows Update errors on Windows devices.

.DESCRIPTION
    This script performs various actions to remediate Windows Update errors, including stopping services, removing files, and resetting components.

.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    .\Remediate-WU-Errors.ps1
    Runs the script to remediate Windows Update errors on Windows devices.

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
Write-Output "Start remediating Windows Upgrade errors"
Write-Log -message "Start remediating Windows Upgrade errors"

# Set error action preference
$ErrorActionPreference = 'Stop'


# Quellen: WUReset (Option 2) + Microsoft Reset-Anleitung. 
# https://github.com/wureset-tools/script-wureset/blob/main/wureset.bat
# https://learn.microsoft.com/troubleshoot/windows-client/installing-updates-features-roles/additional-resources-for-windows-update
# - Scan-Source/WSUS Policy: https://learn.microsoft.com/windows/deployment/update/wufb-wsus

# Remediation options
param(
    # Aktiv lassen, wenn ausschließlich WUfB/WU genutzt wird (WSUS-Reste entfernen)
    [switch]$RemoveLegacyWSUS = $true,

    # Bekannter Stolperstein für 0xC190012E: SetupConfig.ini proaktiv löschen
    [switch]$AlsoRemoveSetupConfig = $true,

    # Sonderfall: Wenn echte WSUS-Policy noch absichtlich gesetzt ist -> nur loggen
    [switch]$RespectExplicitWSUSPolicy = $false
)

# Helper: Registry-Pfad sichern (reg export)
function Backup-RegistryPath {
    param([Parameter(Mandatory)][string]$RegPath)
    try {
        $export = Join-Path $logRoot ("Backup_{0:yyyyMMdd_HHmmss}.reg" -f (Get-Date))
        $regPathNative = $RegPath -replace 'HKLM:', 'HKEY_LOCAL_MACHINE'
        & reg.exe export "$regPathNative" "$export" /y | Out-Null
        Write-Log "Registry backup for $RegPath exported to $export"
    } catch { Write-Log "Registry backup warning for $RegPath $_" }
}

# Helper: Wait for service status change stopped
function Wait-ServiceStopped {
    param([System.ServiceProcess.ServiceController]$Service, [int]$Seconds = 25)
    try {
        $Service.WaitForStatus(
            [System.ServiceProcess.ServiceControllerStatus]::Stopped,
            (New-TimeSpan -Seconds $Seconds)
        ) | Out-Null
    } catch { }
}

# Helper: Wait for service status change running
function Wait-ServiceRunning {
    param([System.ServiceProcess.ServiceController]$Service, [int]$Seconds = 25)
    try {
        $Service.WaitForStatus(
            [System.ServiceProcess.ServiceControllerStatus]::Running,
            (New-TimeSpan -Seconds $Seconds)
        ) | Out-Null
    } catch { }
}

# Main remediation logic
try {
    Write-Log "=== Start Remediation: WUReset Option 2 + WSUS cleanup ==="

    # 0) SetupConfig.ini optional entfernen
    if ($AlsoRemoveSetupConfig) {
        $setupCfg = 'C:\Users\Default\AppData\Local\Microsoft\Windows\WSUS\SetupConfig.ini'
        if (Test-Path $setupCfg) {
            Write-Log "Removing lingering SetupConfig.ini at $setupCfg"
            Remove-Item -Path $setupCfg -Force -ErrorAction SilentlyContinue
        }
    }

    # A) wuauclt.exe beenden
    Write-Log "Killing wuauclt.exe if present"
    Get-Process -Name 'wuauclt' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    # B) Dienste stoppen (BITS, WUAUSERV, APPIDSVC, CRYPTSVC)
    foreach ($s in 'bits','wuauserv','appidsvc','cryptsvc') {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -ne 'Stopped') {
                Write-Log "Stopping service: $s"
                Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
                Wait-ServiceStopped -Service $svc -Seconds 25
            }
        } else {
            Write-Log "Service $s not present (OK)"
        }
    }

    # C) qmgr*.dat löschen (beide bekannten Speicherorte)
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

    # D) Ordner/Dateien sichern/umbenennen
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

    # E) SDDL der Dienste auf Default setzen (wie WUReset)
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
        } catch { Write-Log "SDDL reset warning for $name $_" }
    }

    # F) Re-Registrierung der DLLs (nur wenn vorhanden)
    Write-Log "Re-registering BITS/Windows Update related DLLs (if present)"
    $dlls = @(
        'atl.dll','urlmon.dll','mshtml.dll','shdocvw.dll','browseui.dll','jscript.dll','vbscript.dll','scrrun.dll',
        'msxml.dll','msxml3.dll','msxml6.dll','actxprxy.dll','softpub.dll','wintrust.dll','dssenh.dll','rsaenh.dll',
        'gpkcsp.dll','sccbase.dll','slbcsp.dll','cryptdlg.dll','oleaut32.dll','ole32.dll','shell32.dll','initpki.dll',
        'wuapi.dll','wuaueng.dll','wuaueng1.dll','wucltui.dll','wups.dll','wups2.dll','wuweb.dll','qmgr.dll',
        'qmgrprxy.dll','wucltux.dll','muweb.dll','wuwebv.dll'
    )
    $sys32 = Join-Path $env:windir 'System32'
    foreach ($d in $dlls) {
        $path = Join-Path $sys32 $d
        if (Test-Path $path) {
            try {
                Start-Process -FilePath "$sys32\regsvr32.exe" -ArgumentList "/s `"$path`"" -WindowStyle Hidden -Wait
            } catch { Write-Log "regsvr32 failed for $d $_" }
        } else {
            Write-Log "DLL not found (skipped): $d"
        }
    }

    # G) Winsock/WinHTTP Reset
    Write-Log "Resetting Winsock and WinHTTP proxy"
    & netsh winsock reset           | Out-Null
    & netsh winhttp reset proxy     | Out-Null

    # H) Starttypen setzen (wie WUReset)
    Write-Log "Setting service start types"
    & sc.exe config wuauserv        start= auto         | Out-Null
    & sc.exe config bits            start= delayed-auto | Out-Null
    & sc.exe config cryptsvc        start= auto         | Out-Null
    & sc.exe config TrustedInstaller start= demand      | Out-Null
    # DcomLaunch ist i. d. R. bereits Auto/Running; Konfig-Fehler hier sind unkritisch
    & sc.exe config DcomLaunch      start= auto         | Out-Null

    # I) WSUS-Altlasten entfernen (nur wenn gewünscht)
    if ($RemoveLegacyWSUS) {
        $wuPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        $auPol = Join-Path $wuPol 'AU'
        if ($RespectExplicitWSUSPolicy -and (Get-ItemProperty -Path $wuPol -Name WUServer -ErrorAction SilentlyContinue)) {
            Write-Log "WSUS policy detected and 'RespectExplicitWSUSPolicy' is set -> skipping WSUS cleanup."
        } else {
            if (Test-Path $wuPol) { Backup-RegistryPath -RegPath $wuPol }
            foreach ($val in 'WUServer','WUStatusServer','DoNotConnectToWindowsUpdateInternetLocations','TargetGroup','TargetGroupEnabled') {
                if (Get-ItemProperty -Path $wuPol -Name $val -ErrorAction SilentlyContinue) {
                    Write-Log "Removing policy value: $wuPol\$val"
                    Remove-ItemProperty -Path $wuPol -Name $val -ErrorAction SilentlyContinue
                }
            }
            if (Test-Path $auPol) {
                if (Get-ItemProperty -Path $auPol -Name 'UseWUServer' -ErrorAction SilentlyContinue) {
                    Write-Log "Removing policy value: $auPol\UseWUServer"
                    Remove-ItemProperty -Path $auPol -Name 'UseWUServer' -ErrorAction SilentlyContinue
                }
            }
            foreach ($k in @(
                'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache\CacheSet001\WindowsUpdate',
                'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache\CacheSet002\WindowsUpdate'
            )) {
                if (Test-Path $k) {
                    Write-Log "Removing legacy GPO cache: $k"
                    Remove-Item -Path $k -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        # Hinweis: Die moderne "Specify scan source policy" steuert WSUS vs. Windows Update. cite: learn link oben
    }

    # J) Dienste starten (wie WUReset)
    Write-Log "Starting Windows Update services"
    foreach ($s in @('bits','wuauserv','appidsvc','cryptsvc','DcomLaunch')) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Running') {
            try {
                Start-Service -Name $s -ErrorAction SilentlyContinue
                Wait-ServiceRunning -Service $svc -Seconds 25
            } catch { Write-Log "Start warning for $s $_" }
        }
    }

    # K) Scan anstoßen (best effort)
    $uso = Join-Path $env:SystemRoot 'System32\UsoClient.exe'
    if (Test-Path $uso) {
        Write-Log "Triggering Windows Update scan via UsoClient StartInteractiveScan"
        Start-Process -FilePath $uso -ArgumentList 'StartInteractiveScan' -WindowStyle Hidden
    } else {
        Write-Log "UsoClient not found; triggering WU COM API search (best effort)"
        try {
            $session  = New-Object -ComObject Microsoft.Update.Session
            $searcher = $session.CreateUpdateSearcher()
            $null = $searcher.Search("IsInstalled=0 and Type='Software'")
        } catch { Write-Log "COM scan trigger failed: $_" }
    }

    Write-Log "=== Remediation completed successfully ==="
    exit 0
}
catch {
    Write-Log "Remediation failed: $_"
    exit 1
}