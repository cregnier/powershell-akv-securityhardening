<#
.SYNOPSIS
    Generates a self-signed root certificate for testing.

.DESCRIPTION
    Creates a self-signed root certificate with appropriate settings for
    Azure testing scenarios (e.g., VPN configurations).
    
.NOTES
    Author: Azure Policy Testing Framework
    Version: 1.0.0
    Date: 2026-01-06
    Purpose: Certificate generation for testing
#>

$params = @{
    Type = 'Custom'
    Subject = 'CN=AzureRoot'
    KeySpec = 'Signature'
    KeyExportPolicy = 'Exportable'
    KeyUsage = 'CertSign'
    KeyUsageProperty = 'Sign'
    KeyLength = 2048
    HashAlgorithm = 'sha256'
    NotAfter = (Get-Date).AddMonths(24)
    CertStoreLocation = 'Cert:\CurrentUser\My' 
}

$cert = New-SelfSignedCertificate @params