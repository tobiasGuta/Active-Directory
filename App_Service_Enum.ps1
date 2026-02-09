$ErrorActionPreference = "SilentlyContinue"

function Show-Section {
    param ([string]$Title, [scriptblock]$Command, [string]$Description)
    Write-Host "`n"
    Write-Host "================================================================" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan -NoNewline
    if ($Description) { Write-Host " | $Description" -ForegroundColor DarkGray }
    Write-Host "================================================================" -ForegroundColor DarkCyan
    
    # Visualizing the Command 
    if ($Title -notmatch "RUNNING SERVICES") {
        $CommandText = $Command.ToString().Trim()
        Write-Host "Cmd > $CommandText" -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    }

    try {
        $Output = & $Command
        if ($Output) {
            if ($Output -is [string] -or $Output -is [System.Array]) {
                 $Output | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Green
            } else {
                $Output | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Gray
            }
        } else { Write-Host "[-] None found." -ForegroundColor DarkGray }
    } catch { Write-Host "[!] Access Denied." -ForegroundColor Red }
}

Write-Host "`n    APP & SERVICE ENUMERATOR v5.0" -ForegroundColor Magenta
Write-Host "    -----------------------------" -ForegroundColor White
Write-Host "    [*] Mode: 'net start' Scraper + Registry Mapping" -ForegroundColor Yellow

# 1. INSTALLED APPLICATIONS
Show-Section -Title "INSTALLED APPS (3rd Party)" -Description "Scanning Registry" -Command {
    $Paths = @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", 
               "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
    
    Get-ItemProperty $Paths | 
    Where-Object { $_.DisplayName -ne $null -and $_.DisplayName -notlike "*Update*" } |
    Select-Object DisplayName, DisplayVersion, Publisher | Sort-Object DisplayName
}

# 2. RUNNING SERVICES
Show-Section -Title "RUNNING SERVICES (Net Start Matched)" -Description "Matches 'net start' output to File Paths" -Command {
    
    # A. Build a Map from the Registry (DisplayName -> ImagePath)
    Write-Progress -Activity "Mapping Registry" -Status "Reading Service Paths..."
    
    $ServiceMap = @{}
    $RegBase = "HKLM:\SYSTEM\CurrentControlSet\Services\*"
    $Services = Get-Item $RegBase
    
    foreach ($Key in $Services) {
        $Props = Get-ItemProperty $Key.PSPath
        $DispName = $Props.DisplayName
        $ImgPath  = $Props.ImagePath
        
        # If no DisplayName in registry, use the Key Name
        if (-not $DispName) { $DispName = $Key.PSChildName }
        
        if ($DispName -and $ImgPath) {
            $ServiceMap[$DispName] = $ImgPath
        }
    }
    Write-Progress -Activity "Mapping Registry" -Completed

    # B. Run 'net start' 
    $NetStartOutput = net start
    $Results = @()

    # C. Match them up
    foreach ($Line in $NetStartOutput) {
        $Line = $Line.Trim()
        
        # Skip headers/empty lines
        if ($Line -match "These Windows services" -or $Line -match "The command completed" -or $Line.Length -eq 0) {
            continue
        }

        # Look up the path
        $Path = $ServiceMap[$Line]
        
        # Fallback: Check WMI if registry map failed
        if (-not $Path) {
            $WmiFallback = Get-CimInstance Win32_Service -Filter "DisplayName='$Line'"
            if ($WmiFallback) { $Path = $WmiFallback.PathName }
        }

        # Create Object
        if ($Path) {
             [PSCustomObject]@{
                "Service Name" = $Line
                "Path"         = $Path
                "IsWindows"    = ($Path -like "C:\Windows\*" -or $Path -like "*\svchost.exe*")
            } | ForEach-Object { $Results += $_ }
        } else {
             # Path Not Found -> Highlight it 
             [PSCustomObject]@{
                "Service Name" = $Line
                "Path"         = "[!] PATH NOT FOUND (Check Manually)"
                "IsWindows"    = $false 
            } | ForEach-Object { $Results += $_ }
        }
    }
    
    # D. Sort (Custom/Unknown paths first)
    $Results | Sort-Object IsWindows, "Service Name" | Select-Object "Service Name", Path
}

# 3. LISTENING PORTS
Show-Section -Title "LISTENING PORTS" -Description "Services accepting connections" -Command {
    Get-NetTCPConnection -State Listen | 
    Select-Object LocalPort, LocalAddress, @{Name="Process";Expression={(Get-Process -Id $_.OwningProcess).ProcessName}} |
    Sort-Object LocalPort
}

# 4. INSTALLED PRINTERS
Show-Section -Title "INSTALLED PRINTERS" -Description "Drivers check" -Command {
    Get-WmiObject Win32_Printer | Select-Object Name, Shared, DriverName
}

# 5. SMB SHARES
Show-Section -Title "NETWORK SHARES" -Description "Exposed Folders" -Command {
    Get-SmbShare | Where-Object { $_.Name -notlike "*$" } | Select-Object Name, Path, Description
}

# 6. FILE HUNTER
Show-Section -Title "FILE HUNTER" -Description "Scanning User Profile for secrets" -Command {
    $Extensions = @("*.bak", "*.config", "*.kdbx", "*.txt", "*pass*", "*.vbox", "*.ovpn")
    $RootPath = $env:USERPROFILE
    
    Write-Host "Scanning: $RootPath (Desktop, Downloads, Documents...)" -ForegroundColor Yellow
    
    Get-ChildItem -Path $RootPath -Include $Extensions -Recurse -Depth 3 -ErrorAction SilentlyContinue | 
    Where-Object { $_.FullName -notlike "*AppData*" } | 
    Select-Object Name, Directory, Length, LastWriteTime
}

Write-Host "`nEnumeration Complete." -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor DarkCyan
