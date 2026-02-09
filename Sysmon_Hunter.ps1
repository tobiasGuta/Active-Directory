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
            $Output | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Green
        } else { Write-Host "[-] Access Denied or Not Found." -ForegroundColor DarkGray }
    } catch { Write-Host "[!] Error / Access Denied." -ForegroundColor Red }
}

Write-Host "`n    SYSMON INTELLIGENCE HUNTER" -ForegroundColor Magenta
Write-Host "    --------------------------" -ForegroundColor White

# 1. FIND SYSMON LOCATION
# Knowing where it lives helps us find the config file (often stored next to it).
Show-Section -Title "SYSMON INSTALL PATH" -Command {
    Get-CimInstance win32_service -Filter "Name = 'Sysmon'" | 
    Select-Object Name, PathName, StartMode, State
}

# 2. HUNT FOR CONFIG FILES (XML)
# Admins often leave the config file (e.g., sysmon.xml) in the installation folder or C:\
Show-Section -Title "CONFIG FILE HUNT" -Command {
    # 1. Check the install directory if we found it
    $SysmonPath = (Get-CimInstance win32_service -Filter "Name = 'Sysmon'").PathName
    if ($SysmonPath) {
        $Folder = Split-Path $SysmonPath.Replace('"','') -Parent
        Write-Host "Searching in: $Folder" -ForegroundColor Yellow
        Get-ChildItem -Path $Folder -Filter "*.xml" -ErrorAction SilentlyContinue | Select-Object Name, FullName, LastWriteTime
    }
    
    # 2. Check the root C:\ directory (Common lazy practice)
    Write-Host "Searching in: C:\" -ForegroundColor Yellow
    Get-ChildItem -Path "C:\" -Filter "*sysmon*.xml" -File -ErrorAction SilentlyContinue | Select-Object Name, FullName
}

# 3. READ SYSMON EVENT LOGS 
# We look for Event ID 1 (Process Create) to see if they are logging command lines.
Show-Section -Title "READING RECENT LOGS (Event ID 1)" -Command {
    Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 5 | 
    Where-Object {$_.Id -eq 1} | 
    Select-Object TimeCreated, Id, @{N="Command";E={$_.Properties[10].Value}}
}

# 4. REGISTRY CONFIG CHECK (Advanced)
# Sometimes the config is stored in the registry
Show-Section -Title "REGISTRY PARAMETERS" -Command {
    Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\SysmonDrvh\Parameters"
    Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Sysmon\Parameters"
}

Write-Host "`nEnumeration Complete." -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor DarkCyan
