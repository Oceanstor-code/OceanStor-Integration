#Requires -Version 3
function Remove-DoradoLunSnapshot {
  <#
      .SYNOPSIS
      Removes a Lun Snapshot

      .DESCRIPTION
      The Remove-DoradoLunSnapshot cmdlet will remove snapshot present on a Lun by its ID.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      Remove-DoradoLunSnapshot -ID '20' 

      This will remove the snapshot with ID '20'.
  #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(
        # ID of the snapshot to remove
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$ID
    )

    Begin 
    {
        # Check the authentication globals
        Test-DoradoConnection
    }

    Process 
    {
        if($PSCmdlet.ShouldProcess(
                        ("Snapshot ID $ID"),
                        "Remove Dorado Snapshot"
                    )
        ){
            try
            {
                Write-Verbose -Message "Removing snapshot"
                $uri = "https://$($global:Doradoconnection.server)`:$($global:Doradoconnection.Port)/deviceManager/rest/$($global:Doradoconnection.deviceID)/snapshot/$ID"

                $Result = Invoke-RestMethod -Uri $uri -Method Delete -Headers $global:Doradoconnection.Headers -WebSession $global:Doradoconnection.session
            }
            catch
            {
                write-warning -Message "Could not remove snapshot with ID $ID"
                throw $_.Exception
            }

            if($Result.error.code -ne 0)
            {
                write-warning -Message "An error occured while trying to remove lun snapshot with uri $uri"
                throw "error : $($Result.error.description)"
            }
        }
    }
}