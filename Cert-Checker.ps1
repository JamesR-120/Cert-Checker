Clear-Host

Write-Host @("

    TITLE:    Cert-Checker.ps1
    DATE:     01/05/2020
    AUTHOR:   JR
    VERSION:  0.1 - Script created.
              0.2 - Formatting.

    SYNOPSIS: Queries ADCS CA for expired certificates that have not been renewed.
    
    DEPENDANCIES: Certutil.exe, CA Administrator privileges (Dom Admin)

") -ForegroundColor Cyan

# Initialise arrays

$Certs = [System.Collections.ArrayList]@()    
$ExpiredCerts = [System.Collections.ArrayList]@()
$InvalidCerts = [System.Collections.ArrayList]@()
$ExpiringCerts = [System.Collections.ArrayList]@()

# Fetch all issued certs

Write-Host "Retieving list of issued certficates from Certificate Authority..." -ForegroundColor Cyan

[String]$CA = certutil.exe | Select-String "Config"
$CA = (($CA.Split('`')[1]).TrimEnd("'")).Trim()
certutil.exe -config $CA -view -out "Issued Common Name,Certificate Expiration Date" csv > $env:TEMP\Cert-Checker_certs.csv
$Certs = Import-Csv -Header cn,expiry -Path $env:TEMP\Cert-Checker_certs.csv
$Certs = $Certs | ? { $_.cn -ne "Issued Common Name" }
#$Certs | Sort CN | Out-GridView -Title "$CA - Issued Certificates"
$TotalCerts = $Certs.Count

Write-Host "Found" ($Certs).count "issued certificate(s).`n" -ForegroundColor White

# Check for expired certs, output them, add them to expired certs list and remove them from the main certs list.

Write-Host "Checking validity of issued certificates..." -ForegroundColor Cyan

ForEach ($Cert in $Certs) {
    $ExpiryParsed =[datetime]::ParseExact(($Cert.expiry),'dd/MM/yyyy HH:mm',$null)
    If ([datetime]$ExpiryParsed -le ((Get-Date)))
    #If ([datetime]$ExpiryParsed -le ((Get-Date).AddDays(360)))# Time travel for testing

    {$Certs = $Certs | ? { $_ -notlike $Cert }

    if (!($ExpiredCerts)) 
    { $ExpiredCerts += $Cert}

    if ((!($ExpiredCerts.cn).Contains($cert.cn)))
    {$ExpiredCerts += $Cert}}
}

Write-Host "Found" ($ExpiredCerts).Count "expired certificate(s)." -ForegroundColor White

# Checking for certs that have expired and not renewed

Write-Host "`nChecking for certs that have expired and not been renewed..." -ForegroundColor Cyan

ForEach ($Cert in $ExpiredCerts) {
    if ((!($Certs.cn).Contains($Cert.cn)))
    {$InvalidCerts += $Cert.cn}
}

Write-Host "Found" ($InvalidCerts).Count "certificate(s) that have expired and not been renewed.`n" -ForegroundColor White


# Check for expiring certs

Write-Host "Checking for certificates that will expire in less than 30 days..." -ForegroundColor Cyan

ForEach ($Cert in $Certs) {
    $ExpiryParsed =[datetime]::ParseExact(($Cert.expiry),'dd/MM/yyyy HH:mm',$null)
    
    If ([datetime]$ExpiryParsed -le (Get-Date).AddDays(30))
    {$ExpiringCerts += $Cert}}

    If ($ExpiringCerts)
    {Write-Host "Found" ($ExpiringCerts).Count "certificates about to expire." -ForegroundColor White}

    If (!$ExpiringCerts)
    {Write-Host "No certficates about to expire." -ForegroundColor White}

# Summary

# Stats

Write-Host "`nSummary of certificates on"$CA":" -ForegroundColor Cyan
Write-Host "Certificates checked:" $TotalCerts -ForegroundColor White
Write-Host "Unique expired certificates:" $ExpiredCerts.Count -ForegroundColor White
Write-Host "Valid certificates:" $Certs.Count -ForegroundColor White
Write-Host "`nCertificates expiring in the next 30 days:" $ExpiringCerts.Count -ForegroundColor Yellow
Write-Host "`nExpired certificates not superseded:" $InvalidCerts.Count -ForegroundColor Red

# Log Output
Write-Host "`nOutput Files:" -ForegroundColor Cyan

# Expired Certs
Write-Host "Expired certificates (not superseded) written to $env:temp\Cert-Checker_ExpiredCerts.log" -ForegroundColor White
#$InvalidCerts | Sort CN | Out-GridView -Title "$CA - Expired Certificates"
$InvalidCerts | Out-File $env:TEMP\Cert-Checker_ExpiredCerts.log

# Expiring Certs
Write-Host "Expiring certificates written to $env:temp\Cert-Checker_ExpiringCerts.log" -ForegroundColor White
#$ExpiringCerts | Sort CN | Out-GridView -Title "$CA - Time Expiring Certificates"
$ExpiringCerts | Sort Expiry | Out-File $env:TEMP\Cert-Checker_ExpiringCerts.log

# Valid Certs
Write-Host "Valid certificates written to $env:temp\Cert-Checker_ValidCerts.log`n" -ForegroundColor White
#$Certs | Sort CN | Out-GridView -Title "$CA - Valid Certificates"
$Certs | Sort Expiry | Out-File $env:TEMP\Cert-Checker_ValidCerts.log