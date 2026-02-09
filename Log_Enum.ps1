$ErrorActionPreference = "SilentlyContinue"

function Show-Section {
    param ([string]$Title, [scriptblock]$Command)
    Write-Host "`n"
    Write-Host "================================================================" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor DarkCyan
    $CommandText = $Command.ToString().Trim()
    Write-Host "Cmd > $CommandText" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    
    try {
        $Output = & $Command
        if ($Output) {
            if ($Output -is [string] -or $Output -is [System.Array]) {
                 $Output | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Green
            } else {
                $Output | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Gray
            }
        } else { Write-Host "[-] Not Found / Disabled." -ForegroundColor DarkGray }
    } catch { Write-Host "[!] Access Denied." -ForegroundColor Red }
}

Write-Host "`n    LOGGING & DETECTION HUNTER" -ForegroundColor Magenta
Write-Host "    --------------------------" -ForegroundColor White

# 1. SYSMON CHECK
Show-Section -Title "SYSMON STATUS" -Command {
    # Check running process
    $Proc = Get-Process | Where-Object {$_.ProcessName -like "*Sysmon*"}
    # Check Service
    $Serv = Get-Service | Where-Object {$_.DisplayName -like "*Sysmon*"}
    
    if ($Proc -or $Serv) {
        Write-Host "[!] WARNING: Sysmon is ACTIVE!" -ForegroundColor Red
        if ($Proc) { "Process: " + $Proc.ProcessName }
        if ($Serv) { "Service: " + $Serv.Status }
    } else {
        Write-Host "[-] Sysmon is NOT running." -ForegroundColor Green
    }
}

# 2. AUDIT POLICY
# We specifically look for "Logon/Logoff" and "Process Tracking"
Show-Section -Title "AUDIT POLICY (Key Areas)" -Command {
    # auditpol requires admin, but let's try.
    auditpol /get /category:"Logon/Logoff","Detailed Tracking"
}

# 3. POWERSHELL LOGGING (Script Block Logging)
Show-Section -Title "POWERSHELL LOGGING KEYS" -Command {
    Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -ErrorAction SilentlyContinue | 
    Select-Object EnableScriptBlockLogging, EnableScriptBlockInvocationLogging
}

Write-Host "`nEnumeration Complete." -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor DarkCyan
