#Requires -Version 3
function New-HyperCDPDuplicate {
  <#
      .SYNOPSIS
      Duplicates an HyperCDP object from its ID

      .DESCRIPTION
      The New-HyperCDPDuplicate cmdlet will duplicate an HyperCDP object from its ID.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      New-HyperCDPDuplicate -ID '20' -Name 'NewSnapshotCopyName' 

      This will duplicate the HyperCDP object with ID 20 to a new snapshot named 'NewSnapshotCopyName'.
  #>

    [CmdletBinding()]
    Param(
        # ID of the CDP Object
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$ID,
        # Name of the new snapshot copy
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$Name
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
            Write-Verbose -Message "Creating duplicate of CDP object $ID"

            $body = @{
                "NAME" = $Name
                "CDPID" = $ID
            } | ConvertTo-Json

            $uri = "https://$($global:Doradoconnection.server)`:$($global:Doradoconnection.Port)/deviceManager/rest/$($global:Doradoconnection.deviceID)/snapshot/createcopy"

            $DuplicateSnapshot = Invoke-RestMethod -Uri $uri -Method Post -Headers $global:Doradoconnection.Headers -WebSession $global:Doradoconnection.session -Body $body
        }
        catch
        {
            write-warning -Message "Could not duplicate CDP id $ID"
            throw $_.Exception
        }

        if(-not $DuplicateSnapshot.data -or $DuplicateSnapshot.error.code -ne 0)
        {
            write-warning -Message "Could not retrieve any info on CDP duplicate"
            throw "Empty Duplicate CDP Info while querying for $uri"
        }

        return $DuplicateSnapshot.data
    }
}