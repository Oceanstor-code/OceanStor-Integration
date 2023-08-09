#Requires -Version 3
function Get-DoradoSnapshot {
  <#
      .SYNOPSIS
      Retrieves a Dorado Snapshot from its Name or WWN

      .DESCRIPTION
      The Get-DoradoSnapshot cmdlet will retrieve a Snapshot info from its Name or WWN.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      Get-DoradoSnapshot -WWN '644227c642587d9c0046d6e30000003a'

      This will retrieve the Dorado Snapshot info from its WWN.

      .EXAMPLE
      Get-DoradoLun -Name 'mySnapshot'

      This will retrieve the Dorado Snapshot info from its Name.
  #>

    [CmdletBinding()]
    Param(
        # Name of the Dorado Snapshot
        [Parameter(ParameterSetName='Name',Mandatory=$true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,
        # WWN of the Dorado Snapshot
        [Parameter(ParameterSetName='WWN',Mandatory=$true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$WWN
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
            

            $uri = "https://$($global:Doradoconnection.server)`:$($global:Doradoconnection.Port)/deviceManager/rest/$($global:Doradoconnection.deviceID)/snapshot?filter="

            if($Name)
            {
                Write-Verbose -Message "Retrieving Snapshot info from its name $Name"
                $uri = $uri + "NAME:$Name"
            }
            elseif($WWN)
            {
                Write-Verbose -Message "Retrieving Snapshot info from its WWN $WWN"
                $uri = $uri + "WWN:$WWN"
            }

            $SnapshotInfo = Invoke-RestMethod -Uri $uri -Method Get -Headers $global:Doradoconnection.Headers -WebSession $global:Doradoconnection.session
        }
        catch
        {
            write-warning -Message "Could not retrieve any snapshot info"
            throw $_.Exception
        }

        if(-not $SnapshotInfo.data -or $SnapshotInfo.error.code -ne 0)
        {
            write-warning -Message "Could not retrieve any snapshot info"
            throw "Empty Snapshot Info while querying for $uri"
        }

        return $SnapshotInfo.data
    }
}