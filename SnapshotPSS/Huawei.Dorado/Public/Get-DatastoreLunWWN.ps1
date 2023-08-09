#Requires -Version 3
function Get-DatastoreLunWWN {
  <#
      .SYNOPSIS
      Retrieves a LUN WWN from its vSphere Datastore

      .DESCRIPTION
      The Get-vSphereLunWWN cmdlet will get the LUN WWN from its vSphere Datastore.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      Get-DatastoreLunWWN -Datastore $Datastore

      This will retrieve the Lun WWN from the vSphere datastore object.
  #>

    [CmdletBinding()]
    Param(
        # vSphere Datastore to retrieve the LUN WWN on
        [Parameter(Mandatory = $true)]
        [VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl]$Datastore
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
            Write-Verbose -Message "Retrieving Lun WWN from datastore $Datastore.Name"
            [string]$LunWWN = $datastore.ExtensionData.Info.Vmfs.Extent[0].DiskName.Split(".")[1]
        }
        catch
        {
            write-warning -Message "Could not retrieve any Lun WWN from datastore $Datastore.Name"
            throw $_.Exception
        }

        if([string]::IsNullOrEmpty($LunWWN))
        {
            write-warning -Message "Could not retrieve any Lun WWN from datastore $Datastore.Name"
            throw "No Lun WWN found from datastore $Datastore.Name"
        }

        return $LunWWN
    }
}