$ErrorActionPreference = "SilentlyContinue"

function Show-Section {
    param (
        [string]$Title,
        [scriptblock]$Command,
        [string]$Description
    )

    # 1. Print the Header
    Write-Host "`n"
    Write-Host "================================================================" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan -NoNewline
    if ($Description) {
        Write-Host " | $Description" -ForegroundColor DarkGray
    }
    Write-Host "================================================================" -ForegroundColor DarkCyan
    
    # 2. Print the Command
    # We convert the scriptblock to a string and trim whitespace
    $CommandText = $Command.ToString().Trim()
    Write-Host "Cmd > $CommandText" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray

    # 3. Execute and Format Output
    try {
        $Output = & $Command
        
        if ($Output) {
            # Check if it's a rich object (PowerShell) or simple text (Legacy)
            if ($Output -is [System.Array] -or $Output -is [PSCustomObject]) {
                $Output | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Gray
            } 
            else {
                $Output | Out-String | Write-Host -ForegroundColor Green
            }
        } else {
            Write-Host "[-] No data returned." -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "[!] Error executing command." -ForegroundColor Red
    }
}

# MAIN EXECUTION

Write-Host "`n    NETWORK ENUMERATION (LEARNING MODE)" -ForegroundColor Magenta
Write-Host "    -----------------------------------" -ForegroundColor White

# 1. IP Configuration
Show-Section -Title "IP CONFIGURATION" -Description "Identify Internal vs DMZ IP" -Command {
    Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv6Address, DNSServer
}

# 2. Route Table
Show-Section -Title "ROUTE TABLE" -Description "Check Gateways & Subnets" -Command {
    Get-NetRoute -AddressFamily IPv4 | Where-Object { $_.DestinationPrefix -ne "255.255.255.255/32" } | Select-Object DestinationPrefix, NextHop, InterfaceAlias -First 10
}

# 3. ARP Table
Show-Section -Title "ARP NEIGHBORS" -Description "Discover adjacent devices" -Command {
    arp -a
}

# 4. Listening Ports
Show-Section -Title "LISTENING SERVICES" -Description "Open Ports (Attack Surface)" -Command {
    Get-NetTCPConnection -State Listen | Select-Object LocalAddress, LocalPort, OwningProcess, State | Sort-Object LocalPort
}

# 5. DNS Cache
Show-Section -Title "DNS CACHE" -Description "What has this machine visited?" -Command {
    Get-DnsClientCache | Select-Object Name, Type, Data -First 5
}

# 6. Firewall Status
Show-Section -Title "FIREWALL RULES" -Description "Active Profiles" -Command {
    Get-NetFirewallProfile | Select-Object Name, Enabled
}

Write-Host "`nEnumeration Complete." -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor DarkCyan
