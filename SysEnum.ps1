$ErrorActionPreference = "SilentlyContinue"

function Show-Section {
    param ( [string]$Title, [scriptblock]$Command, [string]$Description )

    Write-Host "`n"
    Write-Host "================================================================" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan -NoNewline
    if ($Description) { Write-Host " | $Description" -ForegroundColor DarkGray }
    Write-Host "================================================================" -ForegroundColor DarkCyan
    
    # Print the exact command used
    $CommandText = $Command.ToString().Trim()
    Write-Host "Cmd > $CommandText" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray

    try {
        $Output = & $Command
        if ($Output) {
            # Special handling for Strings
            if ($Output -is [string] -or $Output -is [System.Array]) {
                 $Output | Out-String | Write-Host -ForegroundColor Green
            } 
            # Handling for Objects
            else {
                $Output | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Gray
            }
        } else { Write-Host "[-] No data." -ForegroundColor DarkGray }
    } catch { Write-Host "[!] Error." -ForegroundColor Red }
}

Write-Host "`n    SYSTEM IDENTITY ENUMERATOR" -ForegroundColor Magenta
Write-Host "    --------------------------" -ForegroundColor White

Show-Section -Title "DOMAIN MEMBERSHIP (PowerShell)" -Description "Instant check for Domain vs Workgroup" -Command {
    Get-CimInstance Win32_ComputerSystem | Select-Object Name, Domain, PartOfDomain, Manufacturer, Model
}

# We use Select-String to grab ONLY the lines we care about, making it readable.
Show-Section -Title "SYSTEMINFO (Classic)" -Description "Parsing the legacy command for OS & Domain" -Command {
    systeminfo | Select-String "OS Name","OS Version","System Manufacturer","Domain","Logon Server"
}

# Environment Variables Check
Show-Section -Title "USER CONTEXT" -Description "Who are we and where is our Logon Server?" -Command {
    Get-ItemProperty "HKCU:\Volatile Environment" | Select-Object LOGONSERVER, USERDOMAIN, USERNAME, USERDNSDOMAIN
}

Write-Host "`nEnumeration Complete." -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor DarkCyan
