function Enable-SelfSignedCert
{
  <#
    .SYNOPSIS
    Enables self signed certificates usage

    .DESCRIPTION
    The Enable-SelfSignedCert allows the usage of self signed certificates for the target systems APIs.
  #>

  [CmdletBinding()]
  param()

    Write-Verbose -Message 'Allowing self-signed certificates'

    if ([System.Net.ServicePointManager]::CertificatePolicy -notlike 'TrustAllCertsPolicy') 
    {
        $ErrorActionPreference = 'Stop'
        try
        {
            Add-Type -TypeDefinition  @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : ICertificatePolicy
            {
                 public bool CheckValidationResult(
                 ServicePoint srvPoint, X509Certificate certificate,
                 WebRequest request, int certificateProblem)
                 {
                     return true;
                }
            }
"@

            [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        }
        catch
        {
            Write-Warning -Message 'An error occured while trying to add Self-signed certificates support'
            throw $_.Exception
        }
    }
}