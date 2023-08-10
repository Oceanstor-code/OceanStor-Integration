#Requires -Version 3
function Get-DoradoLun {
  <#
      .SYNOPSIS
      Retrieves a Dorado LUN from its Name or WWN

      .DESCRIPTION
      The Get-DoradoLun cmdlet will retrieve a Lun info from its Name or WWN.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      Get-DoradoLun -WWN '644227c642587d9c0046d6e30000003a'

      This will retrieve the Dorado Lun info from its WWN.

      .EXAMPLE
      Get-DoradoLun -Name 'myLun'

      This will retrieve the Dorado Lun info from its Name.
  #>

    [CmdletBinding()]
    Param(
        # Name of the Dorado Lun
        [Parameter(ParameterSetName='Name',Mandatory=$true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,
        # WWN of the Dorado Lun
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
            
            $uri = "https://$($global:Doradoconnection.server)`:$($global:Doradoconnection.Port)/deviceManager/rest/$($global:Doradoconnection.deviceID)/lun?filter="

            if($Name)
            {
                Write-Verbose -Message "Retrieving Lun info from its name $Name"
                $uri = $uri + "NAME:$Name"
            }
            elseif($WWN)
            {
                Write-Verbose -Message "Retrieving Lun info from its WWN $WWN"
                $uri = $uri + "WWN:$WWN"
            }

            $LunInfo = Invoke-RestMethod -Uri $uri -Method Get -Headers $global:Doradoconnection.Headers -WebSession $global:Doradoconnection.session
        }
        catch
        {
            write-warning -Message "Could not retrieve any Lun info"
            throw $_.Exception
        }

        if(-not $LunInfo.data -or $LunInfo.error.code -ne 0)
        {
            write-warning -Message "Could not retrieve any Lun info"
            throw "Empty Lun Info while querying for $uri"
        }

        return $LunInfo.data
    }
}