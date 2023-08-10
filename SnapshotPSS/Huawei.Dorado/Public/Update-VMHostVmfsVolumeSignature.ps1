#Requires -Version 3
function Update-VMHostVmfsVolumeSignature {
  <#
      .SYNOPSIS
      Updates the signature of the unresolved VMFS volumes matching a specific Lun WWN on a VMHost

      .DESCRIPTION
      The Update-VMHostVmfsVolumeSignature cmdlet will update the signature of an unresolved VMFS volume from its WWN and VMhost and return the new datastore.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      Update-VMHostVmfsVolumeSignature -VMHost $VMHost -WWN '644227c100307d9c0046d6e30000003a'

      This will update the unresolved VMFS volumes matching the Lun WWN on host $VMHost and return the new datastore.
  #>

    [CmdletBinding()]
    Param(
        # vSphere VMHost to browse datastores on
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$VMHost,
        # LUN WWN that has to match for update
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WWN
    )

    Begin 
    {
        # Check the authentication globals
        Test-VIServerConnection
    }

    Process 
    {
        try
        {
            Write-Verbose -Message "Retrieving VMFS label matching Lun WWN $WWN from host $VMhost"
            
            

            $timer = [Diagnostics.Stopwatch]::StartNew()
            $res = $false
            Do
            {
                #Execute this loop every 1sec if it's not the first time
                if($timer.elapsed.totalseconds -gt 1)
                {
                    Start-Sleep 1
                }

                $esxcli = Get-EsxCli -VMHost $VMhost -V2
                $hostView = $VMHost | get-view
                $dsView = get-view $hostView.ConfigManager.DatastoreSystem
                $mappedLUNs = $dsView.QueryUnresolvedVmfsVolumes()

                Foreach($LUN in $mappedLUNs)
                {
                    if($LUN.Extent.DevicePath -is [array])
                    {
                        $foundMultipleExtents = $false
                        $foundLabel = $false
                        Foreach($disk in $LUN.Extent.DevicePath.GetEnumerator())
                        {
                            if($disk -match $WWN)
                            {
                                $VmfsLabel = $Lun.VmfsLabel
                                $foundMultipleExtents = $true
                                $foundLabel = $true
                            }
                        }
                        if($foundLabel)
                        {
                            break
                        }
                    }
                    else
                    {
                        if($Lun.Extent.DevicePath -match $WWN)
                        {
                            $res = New-Object VMware.Vim.HostUnresolvedVmfsResignatureSpec
                            $res.ExtentDevicePath = $Lun.Extent.DevicePath
                            $VmfsLabel = $Lun.VmfsLabel
                            break
                        }
                    }
                }
            }until($res -or ($timer.elapsed.totalseconds -gt 30 -and $foundMultipleExtents))

            $timer.Stop()

            if($foundMultipleExtents)
            {
                write-warning -Message "An error occured while trying to update Vmfs volumes matching WWN $WWN"
                throw "Cannot Resignature the VMFS volume as there are already multiple unresolved extents bound to the same Vmfs label. Check your currently mapped snapshots from WWN $WWN and hosting datastore $VmfsLabel."
            }
            elseif($res)
            {
                Write-Verbose -Message "Starting resignature of vmfs volume from label $VmfsLabel"
                $null = $dsview.ResignatureUnresolvedVmfsVolume($res)

                #Find Datastore after resignature
                Write-Verbose -Message "Retrieving newly created datastore from its $WWN"
                [VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl]$NewDatastore = Get-Datastore -VmHost $VMhost | Where{ $_.ExtensionData.Info.Vmfs -and $_.ExtensionData.Info.Vmfs.Extent[0].DiskName -match "$WWN" }
            }
            else
            {
                write-warning -Message "An error occured while trying to update Vmfs volumes matching WWN $WWN"
                throw "No Vmfs Lun matching WWN $WWN"
            }
        }
        catch
        {
            write-warning -Message "An error occured while trying to update Vmfs volumes matching WWN $WWN"
            throw $_.Exception
        }

        if(-not $NewDatastore)
        {
            write-warning -Message "Could not retrieve newly created Datastore from its WWN $WWN"
            throw "No datastore found for lun WWN $WWN"
        }

        return $NewDatastore
    }
}