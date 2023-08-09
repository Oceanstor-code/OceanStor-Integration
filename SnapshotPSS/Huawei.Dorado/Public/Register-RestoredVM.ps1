#Requires -Version 3
function Register-RestoredVM {
  <#
      .SYNOPSIS
      Registers a new VM in the vSphere inventory from its VMX file

      .DESCRIPTION
      The Register-RestoredVM cmdlet will register a new VM in the vSphere inventory from its VMX file by browsing a specified datastore.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      Register-RestoredVM -VMHost $VMHost -WWN '644227c100307d9c0046d6e30000003a'

      This will update the unresolved VMFS volumes matching the Lun WWN on host $VMHost and return the new datastore.
  #>

    [CmdletBinding()]
    Param(
        # vSphere VMHost to browse datastore on
        [Parameter(Mandatory = $true)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$VMHost,
        # Datastore to browse
        [Parameter(Mandatory = $true)]
        [VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl]$Datastore,
        # Origin VM - needed to retrieve its vmx file
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VMName,
        # Name of the new VM if specified - else, it'll be based on the origin VM with a timestamp suffix
        [string]$RestoredVMName,
        # Folder to register the VM into - defaults to the origin VM folder
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]$Folder,
        # Resource Pool to register the VM into - defaults to the origin VM ResourcePool
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ResourcePoolImpl]$ResourcePool
    )

    Begin 
    {
        # Check the authentication globals
        Test-VIServerConnection

        if(-not $Folder -and -not $ResourcePool)
        {
            #Retrieve Origin VM info to set defaults for restore
            Write-Verbose -Message "Retrieving origin VM Informations to set defaults"
            $VM = Get-VM -Name $VMName
        }

        if([string]::IsNullOrEmpty($RestoredVMName))
        {
            if($VMName.length -gt 35)
            {
                write-warning -Message "Generated VM Name is greater than known limit (80 chars). Please specify a New VM Name."
                throw "Generated VM Name is greater than known limit (80 chars)"
            }
            $RestoredVMName = $VMName + "_restored_$(Get-Date -UFormat '%Y%m%d_%H%M%S')"
        }

        if(-not $Folder)
        {
            $Folder = $VM.Folder
        }

        if(-not $ResourcePool)
        {
            $ResourcePool = $VM.ResourcePool
        }

    }

    Process 
    {
        try
        {
            Write-Verbose -Message "Mounting the datastore $($Datastore.name) to browse"
            
            $null = New-PSDrive -Name $VMName -Location $Datastore -PSProvider VimDatastore -Root '\' 

            Write-Verbose -Message "Looking for file $VMname.vmx"
            $VMXFile = @(Get-ChildItem -Path ${VMName}: -Filter "$VMname.vmx" -Recurse | where {$_.FolderPath -notmatch ".snapshot"})
            Remove-PSDrive -Name $VMName

            if($VMXFile)
            {
                $NewVM = New-VM -VMFilePath $VMXFile.DatastoreFullPath -Name $RestoredVMName -VMHost $VMHost -Location $Folder -ResourcePool $ResourcePool
            }
        }
        catch
        {
            write-warning -Message "An error occured while creating new VM $VMName"
            throw $_.Exception
        }

        if(-not $NewVM)
        {
            write-warning -Message "Could not retrieve newly created VM $RestoredVMName"
            throw "No VM info found for newly created VM $RestoredVMName"
        }

        return $NewVM
    }
}