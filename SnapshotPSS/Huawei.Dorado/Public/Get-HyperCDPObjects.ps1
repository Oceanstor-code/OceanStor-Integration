#Requires -Version 3
function Get-HyperCDPObjects {
  <#
      .SYNOPSIS
      Retrieves the HyperCDP objects of a Lun from its ID

      .DESCRIPTION
      The Get-HyperCDPObjects cmdlet will retrieve all the HyperCDP objects of a Lun from its ID.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      Get-HyperCDPObjects -LunID '50'

      This will retrieve the Dorado HyperCDP objects of the Lun with ID 50.
  #>

    [CmdletBinding()]
    Param(
        # ID of the Dorado Lun
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$LunID
    )

    Begin 
    {
        # Check the authentication globals
        Test-DoradoConnection
    }

    Process 
    {
        try
        {
            Write-Verbose -Message "Retrieving HyperCDP objects for lun id $LunID"

            $uri = "https://$($global:Doradoconnection.server)`:$($global:Doradoconnection.Port)/deviceManager/rest/$($global:Doradoconnection.deviceID)/cdp?filter=PARENTID:$LunID"
            $HyperCDPObjects = Invoke-RestMethod -Uri $uri -Method Get -Headers $global:Doradoconnection.Headers -WebSession $global:Doradoconnection.session
        }
        catch
        {
            write-warning -Message "Could not retrieve any HyperCDP Objects"
            throw $_.Exception
        }

        if(-not $HyperCDPObjects.data -or $HyperCDPObjects.error.code -ne 0)
        {
            write-warning -Message "Could not retrieve any HyperCDP Object"
            throw "Empty HyperCDP Object result while querying for $uri"
        }

        return $HyperCDPObjects.data
    }
}