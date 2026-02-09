$ErrorActionPreference = "SilentlyContinue"

function Show-Header {
    param ([string]$Title)
    Write-Host "`n================================================================" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor DarkCyan
}

Show-Header "INTERNAL NETWORK RECON"

# 1. GET CURRENT SUBNET
$IPInfo = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } | Select-Object -First 1
$MyIP = $IPInfo.IPAddress
# Logic: Take "192.168.1.50" -> become "192.168.1."
$Subnet = $MyIP.Substring(0, $MyIP.LastIndexOf('.') + 1)

Write-Host "[*] Current IP: $MyIP" -ForegroundColor Yellow
Write-Host "[*] Target Subnet: $Subnet`0/24" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray

# 2. PING SWEEP 
# We loop from 1 to 254
$AliveHosts = @()
1..254 | ForEach-Object {
    $Target = "$Subnet$_"
    # Write-Progress helps you see it's working
    Write-Progress -Activity "Ping Sweep" -Status "Scanning $Target" -PercentComplete (($_ / 254) * 100)
    
    # Test-Connection is the PowerShell "Ping"
    if (Test-Connection -ComputerName $Target -Count 1 -Quiet) {
        Write-Host "[+] Host Found: $Target" -ForegroundColor Green
        $AliveHosts += $Target
    }
}
Write-Progress -Activity "Ping Sweep" -Completed

# 3. PORT SCAN
# We only scan the hosts that replied to Ping
if ($AliveHosts.Count -gt 0) {
    Show-Header "PORT SCANNING ACTIVE HOSTS"
    
    $Ports = @(21, 22, 80, 443, 445, 3389) # FTP, SSH, HTTP, HTTPS, SMB, RDP
    
    foreach ($HostIP in $AliveHosts) {
        Write-Host "`nScanning $HostIP ..." -ForegroundColor White
        
        foreach ($Port in $Ports) {
            # We use System.Net.Sockets.TcpClient for a fast connection test
            try {
                $Socket = New-Object System.Net.Sockets.TcpClient
                $Connect = $Socket.BeginConnect($HostIP, $Port, $null, $null)
                # Timeout of 100ms to make it fast
                $Wait = $Connect.AsyncWaitHandle.WaitOne(100, $false)
                
                if ($Socket.Connected) {
                    Write-Host "    [OPEN] Port $Port" -ForegroundColor Green
                    $Socket.Close()
                }
            } catch {
                # Port closed, do nothing
            }
        }
    }
} else {
    Write-Host "`n[-] No other neighbors found." -ForegroundColor Red
}

Write-Host "`nScan Complete." -ForegroundColor Magenta
