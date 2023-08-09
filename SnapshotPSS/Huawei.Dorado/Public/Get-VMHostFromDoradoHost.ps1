#Requires -Version 3
function Get-VMHostFromDoradoHost {
  <#
      .SYNOPSIS
      Retrieves the correct vSphere VMHost from the Dorado Host Name or its IP

      .DESCRIPTION
      The Get-VMHostFromDoradoHost cmdlet will check which Dorado Host Name or IP corresponds to a VMHost and returns the VMHost.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      Get-VMHostFromDoradoHost -Name 'myHostName'

      This will return the VMware VMHost object.
  #>

    [CmdletBinding()]
    Param(
        # ID of the CDP Object
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$Name
    )

    Begin 
    {
        # Check the authentication globals
        Test-DoradoConnection
        Test-VIServerConnection
    }

    Process 
    {
        try
        {
            Write-Verbose -Message "Checking if host $Name is known by the vCenter server"
            $VMHost = Get-VMHost -Name $Name -ErrorAction SilentlyContinue

            if(-not $VMHost)
            {
                #Then check for IP address
                $uri = "https://$($global:Doradoconnection.server)`:$($global:Doradoconnection.Port)/deviceManager/rest/$($global:Doradoconnection.deviceID)/host?filter=NAME:$Name"                $DoradoHost=Invoke-RestMethod -Uri $uri -Method Get -Headers $global:Doradoconnection.Headers -WebSession $global:Doradoconnection.session

                if($DoradoHost.data.IP)
                {
                    $VMHost = Get-VMHost -Name $DoradoHost.data.IP
                }
                else
                {
                    write-warning -Message "Could not map the Dorado host $Name to any vSphere Host"
                    throw "No vSphere host found for Name or IP of Dorado host $Name"
                }
            }
        }
        catch
        {
            write-warning -Message "Could not find host from its name $Name"
            throw $_.Exception
        }

        return $VMhost
    }
}