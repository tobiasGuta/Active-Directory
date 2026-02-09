$ErrorActionPreference = "SilentlyContinue"

function Show-Section {
    param (
        [string]$Title,
        [scriptblock]$Command,
        [string]$Description
    )

    Write-Host "`n"
    Write-Host "================================================================" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan -NoNewline
    if ($Description) {
        Write-Host " | $Description" -ForegroundColor DarkGray
    }
    Write-Host "================================================================" -ForegroundColor DarkCyan
    
    # Visualizing the Command
    $CommandText = $Command.ToString().Trim()
    Write-Host "Cmd > $CommandText" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray

    try {
        $Output = & $Command
        
        if ($Output) {
            # Format output based on type
            if ($Output -is [string] -or $Output -is [System.Array]) {
                 $Output | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Green
            } else {
                $Output | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Gray
            }
        } else {
            Write-Host "[-] No data returned / Not Applicable." -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "[!] Error: Access Denied or Module Missing." -ForegroundColor Red
    }
}

Write-Host "`n    AD ENUMERATION SUITE v2.1" -ForegroundColor Magenta
Write-Host "    -------------------------" -ForegroundColor White

if (-not (Get-Module -ListAvailable ActiveDirectory)) {
    Write-Host "[!] CRITICAL: ActiveDirectory Module is missing." -ForegroundColor Red
    Write-Host "    This script requires RSAT tools." -ForegroundColor Yellow
    break
}

Show-Section -Title "CURRENT USER IDENTITY" -Description "Who am I in the Domain?" -Command {
    $CurrentUser = $env:USERNAME
    Get-ADUser -Identity $CurrentUser -Properties MemberOf | Select-Object Name, SamAccountName, MemberOf
}

# PRIVILEGED GROUPS
Show-Section -Title "DOMAIN ADMINS HUNT" -Description "Identifying High-Value Targets (w/ UPN)" -Command {
    Get-ADGroupMember -Identity "Domain Admins" -Recursive | 
    Get-ADUser -Properties UserPrincipalName | 
    Select-Object Name, SamAccountName, UserPrincipalName, DistinguishedName
}

Show-Section -Title "ENTERPRISE ADMINS HUNT" -Description "Forest-Level Access" -Command {
    Get-ADGroupMember -Identity "Enterprise Admins" -Recursive | Select-Object Name, SamAccountName
}

# SERVICE ACCOUNTS
Show-Section -Title "KERBEROASTING TARGETS" -Description "Service Accounts (SPN set)" -Command {
    Get-ADUser -Filter {ServicePrincipalName -like "*"} -Properties ServicePrincipalName | 
    Select-Object Name, ServicePrincipalName
}

# OU STRUCTURE
Show-Section -Title "OU STRUCTURE" -Description "Listing Top-Level OUs" -Command {
    $DomainDN = (Get-ADDomain).DistinguishedName
    Get-ADOrganizationalUnit -Filter * -SearchBase $DomainDN -SearchScope OneLevel | 
    Select-Object Name, DistinguishedName
}

# USERS BY OU
Show-Section -Title "USERS INSIDE SPECIFIC OUs" -Description "Mapping Users to their OUs" -Command {
    Get-ADUser -Filter * -Properties CanonicalName | 
    Select-Object Name, SamAccountName, @{Name="OU Location";Expression={$_.CanonicalName.Split('/')[0..($_.CanonicalName.Split('/').Count-2)] -join '/'}} |
    Sort-Object "OU Location"
}

Write-Host "`nEnumeration Complete." -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor DarkCyan
