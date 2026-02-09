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
        } else { Write-Host "[-] None Found / Safe." -ForegroundColor DarkGray }
    } catch { Write-Host "[!] Error or Access Denied." -ForegroundColor Red }
}

Write-Host "`n    EDR & LOG HUNTER" -ForegroundColor Magenta
Write-Host "    ----------------" -ForegroundColor White

# 1. EVENT LOG ENUMERATION (Role Identification)
Show-Section -Title "EVENT LOG DISCOVERY" -Description "Inferring Roles from Log Names" -Command {
    Get-EventLog -List | 
    Where-Object { $_.Log -match "Directory Service|DNS Server|Hyper-V|Exchange" } |
    Select-Object Log, Entries, OverflowAction
}

# 2. EDR PROCESS & SERVICE HUNT
# look for the "Big Players" in EDR
Show-Section -Title "EDR SERVICE HUNT" -Description "Checking for known EDR vendors" -Command {
    $EDR_Keywords = "*Carbon*", "*CrowdStrike*", "*Cylance*", "*Sentinel*", "*Symantec*", "*Elastic*", "*FireEye*", "*Tanium*", "*Qualys*"
    
    Get-Service | Where-Object { 
        $Name = $_.DisplayName
        ($EDR_Keywords | Where-Object { $Name -like $_ })
    } | Select-Object DisplayName, Name, Status, StartType
}

# 3. DRIVER ENUMERATION (The Kernel Level)
# EDRs must load a Kernel Driver to be effective. They can hide processes, but rarely hide drivers.
Show-Section -Title "SECURITY DRIVERS" -Description "Kernel Drivers matching EDR keywords" -Command {
    $EDR_Keywords = "*Carbon*", "*CrowdStrike*", "*Cylance*", "*Sentinel*", "*Symantec*", "*Elastic*", "*Sysmon*"
    
    Get-CimInstance Win32_SystemDriver | Where-Object { 
        $Name = $_.DisplayName
        $Desc = $_.Description
        ($EDR_Keywords | Where-Object { $Name -like $_ -or $Desc -like $_ })
    } | Select-Object Name, State, DisplayName, PathName
}

# 4. INTROSPECTIVE DLL CHECK
# If an EDR is watching us, we will see their DLL loaded into our memory.
Show-Section -Title "LOADED DLLs (HOOKS)" -Description "Checking current process for foreign DLLs" -Command {
    $MyPID = $PID
    $EDR_Keywords = "*Carbon*", "*CrowdStrike*", "*Cylance*", "*Sentinel*", "*Symantec*", "*Elastic*", "*Bitdefender*", "*Sophos*"
    
    Get-Process -Id $MyPID -Module | Where-Object { 
        $Path = $_.FileName
        ($EDR_Keywords | Where-Object { $Path -like $_ })
    } | Select-Object ModuleName, FileName, Description
}

# 5. DIRECTORY HUNT
# Sometimes the process is hidden, but the folder in "Program Files" exists.
Show-Section -Title "INSTALLATION FOLDERS" -Description "Checking Program Files for EDR Artifacts" -Command {
    $Paths = @("C:\Program Files", "C:\Program Files (x86)", "C:\ProgramData")
    $EDR_Keywords = "*Carbon*", "*CrowdStrike*", "*Cylance*", "*Sentinel*", "*Symantec*", "*Tanium*"
    
    foreach ($Path in $Paths) {
        Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue | Where-Object {
            $Name = $_.Name
            ($EDR_Keywords | Where-Object { $Name -like $_ })
        } | Select-Object Name, FullName, LastWriteTime
    }
}

Write-Host "`nEnumeration Complete." -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor DarkCyan
