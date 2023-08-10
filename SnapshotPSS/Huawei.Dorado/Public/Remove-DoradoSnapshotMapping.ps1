#Requires -Version 3
function Remove-DoradoSnapshotMapping {
  <#
      .SYNOPSIS
      Removes a mapping between a lun and its host

      .DESCRIPTION
      The Remove-DoradoSnapshotMapping cmdlet will remove a lun to host mapping from either their IDs or their Names.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      Remove-DoradoSnapshotMapping -LunID '20' -HostID '1' 

      This will remove the mapping between lun with ID 20 to the host with ID 1.

      .EXAMPLE
      Remove-DoradoSnapshotMapping -LunName 'myLun' -HostName 'myHost' 

      This will remove the mapping between the Lun named 'myLun' to the host named 'myHost'.
  #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(
        # ID of the lun to remove the mapping from
        [Parameter(ParameterSetName='ID',Mandatory=$true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$LunID,
        # Name of the lun to remove the mapping from
        [Parameter(ParameterSetName='Name',Mandatory=$true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$LunName,
        # ID of the host to remove the mapping from
        [Parameter(ParameterSetName='ID',Mandatory=$true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [String]$HostID,
        # Name of the host to remove the mapping from
        [Parameter(ParameterSetName='Name',Mandatory=$true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [String]$HostName
    )

    Begin 
    {
        # Check the authentication globals
        Test-DoradoConnection
    }

    Process 
    {
        if($PSCmdlet.ShouldProcess(
                        ("Lun $LunID$LunName, Host $HostID$HostName"),
                        "Remove Dorado Snapshot Mapping"
                    )
        ){
            try
            {
            
                $uri = "https://$($global:Doradoconnection.server)`:$($global:Doradoconnection.Port)/api/v2/mapping"

                if($LunID -and $HostID)
                {
                    $uri = $uri + "?hostId=$HostId&lunId=$lunId"

                    Write-Verbose -Message "Removing mapping between lunId $LunID and hostID $HostID"
                }
                elseif($LunName -and $HostName)
                {
                    $uri = $uri + "?hostName=$HostName&lunName=$lunName"

                    Write-Verbose -Message "Removing mapping between lunName $LunName and hostName $HostName"
                }

                $Result = Invoke-RestMethod -Uri $uri -Method Delete -Headers $global:Doradoconnection.Headers -WebSession $global:Doradoconnection.session
            }
            catch
            {
                write-warning -Message "Could not remove Mapping between lun and host"
                throw $_.Exception
            }
            if($Result.error.code -ne 0)
            {
                write-warning -Message "An error occured while trying to remove mapping between lun and host with uri $uri"
                throw "error : $($Result.error.description)"
            }
        }
    }
}