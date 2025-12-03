<#
.SYNOPSIS
    Detect low disk space on the C: drive.

.DESCRIPTION
    Checks the free disk space on the C: drive.
    If free space is below 30 GB, it calculates the combined size of files in the user's Downloads folder
    and items in the Recycle Bin.
    If the combined size is at least 500 MB, it exits with code 1 to trigger remediation.

.NOTES
    Author: Florian Aschbichler
    Date: 01.12.2025
    Version: 1.3
    Requires administrative privileges.
#>

# Init & Logging
$logFolder = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$logFile = Join-Path $logFolder "Detect-DiskCleanUp.log"

if (-not (Test-Path -Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

Function Write-Log {
    param ([string]$Message)
    $TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Add-Content -Path $logFile -Value "$TimeStamp - $Message"
}

# Thresholds
$MinGBFree = 30
$MinReclaimMB = 500

Write-Output "=== Disk Space Detection Started ==="
Write-Log     "Detection started"

try {
    $freeBytes = (Get-PSDrive -Name C -ErrorAction Stop).Free
    $freeGB = [math]::Round($freeBytes / 1GB, 2)
    Write-Output "Free space on C: = $freeGB GB"
    Write-Log    "Free space on C: = $freeGB GB"
}
catch {
    Write-Output "Error reading disk space. Assuming compliant."
    Write-Log    "Error reading disk space. Exit 0."
    exit 0
}

if ($freeBytes -ge ($MinGBFree * 1GB)) {
    Write-Output "OK: Free space is above $MinGBFree GB."
    Write-Log    "Compliant: $freeGB GB free"
    exit 0
}
elseif ($freeBytes -lt ($MinGBFree * 1GB)) {
    Write-Output "Low disk space detected (< $MinGBFree GB)."
    Write-Log    "Low disk space detected: $freeGB GB free"
    Write-Output "Non-compliant. Trigger remediation."
    Write-Log    "Non-compliant. Trigger remediation."
    exit 1
}

# Calculate Downloads size
$downloadsPath = Join-Path $env:USERPROFILE "Downloads"
$dlBytes = 0
if (Test-Path -LiteralPath $downloadsPath) {
    $dlBytes = (Get-ChildItem -LiteralPath $downloadsPath -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Sum Length).Sum
}
$dlMB = [math]::Round($dlBytes / 1MB, 0)
Write-Output "Downloads folder size: $dlMB MB"
Write-Log    "Downloads folder size: $dlMB MB"

# Calculate Recycle Bin size
$rbBytes = 0
try {
    $shell = New-Object -ComObject Shell.Application
    $rb = $shell.Namespace('shell:RecycleBinFolder')
    if ($rb) {
        foreach ($item in $rb.Items()) {
            try { $rbBytes += [int64]$item.Size } catch {}
        }
    }
}
catch {}
$rbMB = [math]::Round($rbBytes / 1MB, 0)
Write-Output "Recycle Bin size: $rbMB MB"
Write-Log    "Recycle Bin size: $rbMB MB"

# Combined size
$combinedBytes = [int64]$dlBytes + [int64]$rbBytes
$combinedMB = [math]::Round($combinedBytes / 1MB, 0)
Write-Output "Combined Downloads + Recycle Bin = $combinedMB MB"
Write-Log    "Combined size = $combinedMB MB"

if ($combinedBytes -ge ($MinReclaimMB * 1MB)) {
    Write-Output "Trigger remediation: Combined size >= $MinReclaimMB MB"
    Write-Log    "Non-compliant. Trigger remediation."
    exit 1
}

Write-Output "No remediation needed: Combined size < $MinReclaimMB MB"
Write-Log    "Compliant after check."
exit 0