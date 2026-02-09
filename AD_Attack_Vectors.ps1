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
            $Output | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Green
        } else {
            Write-Host "[-] None found (Safe)." -ForegroundColor DarkGray
        }
    } catch { Write-Host "[!] Error." -ForegroundColor Red }
}

Write-Host "`n    AD VULNERABILITY HUNTER" -ForegroundColor Magenta
Write-Host "    -----------------------" -ForegroundColor White

# 1. AS-REP ROASTING (The alternative to Kerberoasting)
# If PreAuth is disabled, we can request a ticket (and crack it) without a password.
Show-Section -Title "AS-REP ROASTING CHECK" -Description "Users with 'No Pre-Auth' enabled" -Command {
    Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} -Properties DoesNotRequirePreAuth | 
    Select-Object Name, SamAccountName, DoesNotRequirePreAuth
}

# 2. PASSWORD MINING 
# Looking for lazy admins who wrote passwords in the comments.
Show-Section -Title "DESCRIPTION ANALYSIS" -Description "Checking for stored credentials in text" -Command {
    Get-ADUser -Filter * -Properties Description | 
    Where-Object { $_.Description -ne $null -and $_.Description -ne "" } |
    Select-Object Name, SamAccountName, Description
}

# 3. WEAK SECURITY FLAGS
# Accounts that don't need passwords or have passwords that never expire.
Show-Section -Title "WEAK ACCOUNT FLAGS" -Description "PasswordNotRequired or NeverExpires" -Command {
    Get-ADUser -Filter {PasswordNotRequired -eq $true -or PasswordNeverExpires -eq $true} -Properties PasswordNotRequired, PasswordNeverExpires | 
    Select-Object Name, SamAccountName, PasswordNotRequired, PasswordNeverExpires
}

# 4. GHOST USERS
# Users who haven't logged in for a long time (Potential takeover targets)
Show-Section -Title "STALE ACCOUNTS" -Description "No login in 90+ days" -Command {
    $DateCutoff = (Get-Date).AddDays(-90)
    Get-ADUser -Filter {LastLogonDate -lt $DateCutoff -and Enabled -eq $true} -Properties LastLogonDate | 
    Select-Object Name, LastLogonDate
}

Write-Host "`nEnumeration Complete." -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor DarkCyan
