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
    # Converting scriptblock to string for display usually captures the braces, 
    # so we just print a clean message or the content if simple.
    Write-Host "Cmd > Executing Trust/User Recon..." -ForegroundColor Yellow 
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray

    try {
        # Execute the command block
        $Output = & $Command
        
        if ($Output) {
            # Check if output is a collection or single object and format
            $Output | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Green
        } else {
            Write-Host "[-] No data returned / Not Applicable." -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "[!] Error: Access Denied or Module Missing." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

Write-Host "`n    AD ENUMERATION SUITE v2.1 (RED TEAM EDITION)" -ForegroundColor Magenta
Write-Host "    --------------------------------------------" -ForegroundColor White

if (-not (Get-Module -ListAvailable ActiveDirectory)) {
    Write-Host "[!] CRITICAL: ActiveDirectory Module is missing." -ForegroundColor Red
    Write-Host "    This script requires RSAT tools." -ForegroundColor Yellow
    break
}

Show-Section -Title "CURRENT USER IDENTITY" -Description "Who am I in the Domain?" -Command {
    $CurrentUser = $env:USERNAME
    # Added error handling for non-domain contexts
    try { Get-ADUser -Identity $CurrentUser -Properties MemberOf | Select-Object Name, SamAccountName, MemberOf } catch { "Current user not found in AD" }
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

# --- [ NEW SECTION ADDED HERE ] ---
Show-Section -Title "DOMAIN TRUSTS & ATTACK VECTORS" -Description "Checking for SID History & Trust Vulnerabilities" -Command {
    Get-ADTrust -Filter * | Select-Object Name, Direction, IntraForest, SIDFilteringQuarantined, TGTDelegation
}
# ----------------------------------

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
