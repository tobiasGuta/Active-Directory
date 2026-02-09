$ErrorActionPreference = "SilentlyContinue"

function Show-Section {
    param ([string]$Title, [scriptblock]$Command, [string]$Description)
    Write-Host "`n"
    Write-Host "================================================================" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan -NoNewline
    if ($Description) { Write-Host " | $Description" -ForegroundColor DarkGray }
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
        } else { Write-Host "[-] No data / Not Applicable." -ForegroundColor DarkGray }
    } catch { Write-Host "[!] Error: Access Denied or Feature Missing." -ForegroundColor Red }
}

Write-Host "`n    SECURITY DEFENSE ENUMERATOR" -ForegroundColor Magenta
Write-Host "    ---------------------------" -ForegroundColor White

# THIRD-PARTY ANTIVIRUS (Workstations Only)
Show-Section -Title "3RD PARTY ANTIVIRUS" -Description "Querying WMI SecurityCenter2" -Command {
    try {
        Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct | 
        Select-Object displayName, productState, pathToSignedProductExe
    } catch {
        Write-Host "[-] ROOT\SecurityCenter2 namespace not found (Likely Windows Server)." -ForegroundColor Yellow
    }
}

# 2. WINDOWS DEFENDER STATUS
# Checks if Real-Time Protection is actually ON.
Show-Section -Title "DEFENDER STATUS" -Description "Real-Time Protection & Tamper Checks" -Command {
    Get-MpComputerStatus | 
    Select-Object AMServiceEnabled, RealTimeProtectionEnabled, AntispywareEnabled, IsTamperProtected, AntivirusEnabled
}

# 3. FIREWALL PROFILES
# Which walls are up? (Domain, Private, or Public)
Show-Section -Title "FIREWALL PROFILES" -Description "Active Blocking Profiles" -Command {
    Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
}

# 4. FIREWALL RULES 
# We can't list all 1000 rules, so we check for common blocks or allows.
Show-Section -Title "FIREWALL RULES (Sample)" -Description "Checking HTTP/SMB rules" -Command {
    Get-NetFirewallRule | 
    Where-Object {$_.DisplayName -like "*Web*" -or $_.DisplayName -like "*SMB*"} | 
    Select-Object DisplayName, Direction, Action, Enabled -First 10
}

# 5. CONNECTIVITY CHECK
# Can we reach the outside world?
Show-Section -Title "EGRESS CHECK" -Description "Testing Outbound Connection (Port 80)" -Command {
    # We test connection to a safe external IP (Google DNS) or internal Gateway
    Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Detailed
}

Write-Host "`nEnumeration Complete." -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor DarkCyan
