#Requires -Version 3
function New-DoradoSnapshotMapping {
  <#
      .SYNOPSIS
      Maps a Lun to a Host

      .DESCRIPTION
      The New-DoradoSnapshotMapping cmdlet will map a Lun to a Host from either their IDs or their Names.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      New-DoradoSnapshotMapping -LunID '20' -HostID '1' 

      This will maps the Lun with ID 20 to the host with ID 1.

      .EXAMPLE
      New-DoradoSnapshotMapping -LunName 'myLun' -HostName 'myHost' 

      This will maps the Lun named 'myLun' to the host named 'myHost'.
  #>

    [CmdletBinding()]
    Param(
        # ID of the Lun to map
        [Parameter(ParameterSetName='ID',Mandatory=$true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$LunID,
        # Name of the Lun to map
        [Parameter(ParameterSetName='Name',Mandatory=$true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$LunName,
        # ID of the host to map
        [Parameter(ParameterSetName='ID',Mandatory=$true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [String]$HostID,
        # Name of the host to map
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
        try
        {
            
            $uri = "https://$($global:Doradoconnection.server)`:$($global:Doradoconnection.Port)/api/v2/mapping"

            if($LunID -and $HostID)
            {
                $body = @{
                    "lunId" = $LunID
                    "hostId" = $HostID
                    "vstoreId" = "0"
                } | ConvertTo-Json

                Write-Verbose -Message "Creating mapping between lunId $LunID and hostID $HostID"
            }
            elseif($LunName -and $HostName)
            {
                $body = @{
                    "lunName" = $LunName
                    "hostName" = $HostName
                    "vstoreId" = "0"
                } | ConvertTo-Json

                Write-Verbose -Message "Creating mapping between lunName $LunName and hostName $HostName"
            }

            $MappingInfo = Invoke-RestMethod -Uri $uri -Method Post -Headers $global:Doradoconnection.Headers -WebSession $global:Doradoconnection.session -Body $body
        }
        catch
        {
            write-warning -Message "Could not create Mapping from info"
            throw $_.Exception
        }

        if(-not $MappingInfo.data -or $MappingInfo.error.code -ne 0)
        {
            write-warning -Message "Could not retrieve any info on the created mapping"
            throw "Empty mapping Info while querying for $uri"
        }

        return $MappingInfo.data
    }
}