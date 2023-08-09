#Requires -Version 3
<#
      .SYNOPSIS
      This script enables end-user to restore VMware VMs from a storage CDP snapshot by automating the restore and clean-up process.

      .DESCRIPTION
      The following script will authenticate to a Dorado storage array as well as a vCenter. 

      It'll then follow two processes depending on the Mode you selected (Restore or Cleanup).

      - Restore : will identify the Lun your VM to restore is currently on, duplicate the CDP object you want to restore from, map it to a VMHost and create a new datastore from it.
      It'll then look for the vmx file of your VM and register it to the vCenter.

      - Cleanup : will identify the Lun, CDP snapshot and datastore your Restored VM is currently on. 
      It'll then remove the VM, Datastore, Snapshot mapping, CDP Snapshot and Lun used by this VM.

      .PARAMETER DoradoStorage

      IP address or FQDN of your Dorado storage array to access the management interface

      .PARAMETER DoradoPort

      Port used by the management interface of your Dorado storage array (defaults to 8088)

      .PARAMETER vCenter

      IP address or FQDN of your vCenter server

      .PARAMETER VMName

      Name of the VM you want to restore, or cleanup.

      .PARAMETER RecoverHost

      Name of the Host declared on the Dorado storage array. Its name or IP should match a vSphere VMHost.

      .PARAMETER Mode

      Defines the actions that'll be executed in the script - defaults to Restore

      .PARAMETER DoradoCred

      [Optional] Credentials to connect on the Dorado storage array - you will be prompted for credentials if this parameter is null

      .PARAMETER viServerCred

      [Optional] Credentials to connect on the vCenter server - you will be prompted for credentials if this parameter is null

      .PARAMETER HyperCDPDuplicateName

      [Optional] Name of the duplicate of the HyperCDP snapshot - if not specified, it'll be based on the origin volume with a timestamp suffix

      .PARAMETER RestoredVMName

      [Optional] Name of the new VM if specified (Restore Mode only) - else, it'll be based on the origin VM with a timestamp suffix

      .PARAMETER RestoredVMFolder

      [Optional] Folder to register the VM into (Restore Mode only) - defaults to the origin VM folder

      .PARAMETER RestoredVMResourcePool

      [Optional] Resource Pool to register the VM into (Restore Mode only) - defaults to the origin VM ResourcePool

      .PARAMETER iSStoragevMotionVM

      [Optional] Switch to specify that a VM has been storage vMotion'd to another datastore and shouldn't be removed 

      .PARAMETER DatastoreName

      [Optional] Datastore Name to cleanup  - used when the iSStoragevMotionVM switch is enabled

      .PARAMETER StartRestoredVM

      [Optional] Boot the restored VM if set to true - defaults to false

      .PARAMETER KeepRestoredVMNetwork

      [Optional] Does not disconnect the restored VM Network Adapters if set to true - defaults to false

      .PARAMETER LogPath

      [Optional] Folder in which the log file will be created - defaults to the script's '\Logs' directory

      .PARAMETER LogName

      [Optional] File name created to store the logs - defaults to the script's name with a timestamp prefix

      .INPUTS

      None

      .OUTPUTS

      A log file will be created in the same directory as this script.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      ./Start-DoradoCDPRestore -DoradoStorage '192.168.0.1' -vCenter '192.168.0.2' -VMName 'myVM' -RecoverHost 'esx-01.my-domain.com'

      This will restore the VM named 'myVM' on the ESX 'esx-01.my-domain.com' by connecting to the Dorado storage Array and vCenter.

      .EXAMPLE
      ./Start-DoradoCDPRestore -ConfigFilePath 'C:\myFolders\myConfigFile.xml'

      This will start the script based on the values set in the XML configuration file.
  #>
    [CmdletBinding()]
    Param(
        # Dorado management IP or FQDN
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$DoradoStorage,
        # Port to use for the connection to the API, defaults to 8088
        [string]$Port,
        # vCenter server management IP or FQDN
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$vCenter,
        # Name of the VM to restore / cleanup
        [Parameter(Mandatory=$true)]
        [String]$VMName,
        # Name of the Host in the Dorado storage array
        [Parameter(Mandatory=$true)]
        [String]$RecoverHost,
        # Name of the Host in the Dorado storage array
        [Parameter(ParameterSetName='ConfigFile')]
        [String]$ConfigFilePath,
        # Mode to start the script - defaults to Restore
        [ValidateSet('Restore','Cleanup','Stop')]
        [string]$Mode = 'Restore',
        # Credentials to authenticate to the Dorado storage array - will be prompted for if null
        [System.Management.Automation.CredentialAttribute()]$DoradoCred,
        # Credentials to authenticate to the vCenter server - will be prompted for if null
        [System.Management.Automation.CredentialAttribute()]$viServerCred,
        # Name of the Duplicate of the HyperCDP snapshot
        [string]$HyperCDPDuplicateName,
        # Name of the new VM if specified (Restore Mode only) - else, it'll be based on the origin VM with a timestamp suffix
        [string]$RestoredVMName,
        # Name of the Folder to register the VM into (Restore Mode only) - defaults to the origin VM folder
        [string]$RestoredVMFolderName,
        # Name of the Resource Pool to register the VM into (Restore Mode only) - defaults to the origin VM ResourcePool
        [string]$RestoredResourcePoolName,
        # Switch to specify that a VM has been storage vMotion'd to another datastore and shouldn't be removed
        [switch]$iSStoragevMotionVM,
        # Datastore Name to cleanup  - used when the iSStoragevMotionVM switch is enabled
        [string]$DatastoreName,
        # Keep the Network cards of the restored VM connected
        [switch]$KeepRestoredVMNetwork,
        # Start the Restored VM
        [switch]$StartRestoredVM,
        # Path to the log file 
        [string]$LogPath,
        # Name of the log file
        [string]$LogName
    )



###############################
# ----- Initialisations ----- #
###############################

# Set Error Action to stop
$ErrorActionPreference = 'Stop'

# Import needed modules
write-output "[$([DateTime]::Now)]  Importing powerCLI and Huawei.Dorado modules"
import-module VMware.VimAutomation.Core
import-module Huawei.Dorado
write-output "[$([DateTime]::Now)]  Modules correctly imported"

############################
# ----- Declarations ----- #
############################

# Set the script version for log outputs
$ScriptVersion = 'v1.0'

# Check if a ConfigFilePath exists - Retrieves the parameters from the XML File if it does
if($ConfigFilePath -and -not (Test-Path -path "$ConfigFilePath"))
{
	write-warning "No Config file present in the path : $ConfigFilePath"
	throw "No Config file in the specified location $ConfigFilePath"
}
elseif($ConfigFilePath)
{
    write-output "[$([DateTime]::Now)]  Reading variables from ConfigFile"

    # Retrieve all properties set in the XML file, and declare their variable in the Script if they are not empty
	[xml]$configuration = Get-Content $ConfigFilePath
	$Properties = $configuration.Configuration | Get-Member -MemberType Property | ?{$_.name -ne '#comment'} | Select Name

    if($Properties -and $Properties.count -gt 0)
    {
        foreach($Property in $Properties)
        {
            if(-not [string]::IsNullOrEmpty($configuration.Configuration."$($Property.name)"))
            {
                Set-Variable -Name $Property.name -Value $configuration.Configuration."$($Property.name)"
            }
        }
    }

        # Change Switch params retrieved through config file to true bools
    if($iSStoragevMotionVM -like 'true')
    {
        $iSStoragevMotionVM = $true
    }
    else
    {
        $iSStoragevMotionVM = $false
    }

    if($StartRestoredVM -like 'true')
    {
        $StartRestoredVM = $true
    }
    else
    {
        $StartRestoredVM = $false
    }
    
    if($KeepRestoredVMNetwork -like 'true')
    {
        $KeepRestoredVMNetwork = $true
    }
    else
    {
        $KeepRestoredVMNetwork = $false
    }

    # Ask for mandatory values until they are set
    if([string]::IsNullOrEmpty($DoradoStorage))
    {
        write-host "No Dorado Storage found in the ConfigFile, please set the Dorado storage array IP or FQDN"
        Do
        {
            [string]$DoradoStorage = Read-Host -Prompt "Dorado Storage"
        }while([string]::IsNullOrEmpty($DoradoStorage))
    }

    if([string]::IsNullOrEmpty($vCenter))
    {
        write-host "No vCenter found in the ConfigFile, please set the vCenter IP or FQDN"
        Do
        {
            [string]$vCenter = Read-Host -Prompt "vCenter"
        }while([string]::IsNullOrEmpty($vCenter))
    }

    if([string]::IsNullOrEmpty($RecoverHost))
    {
        write-host "No Recover Host found in the ConfigFile, please set the Recover Host"
        Do
        {
            [string]$RecoverHost = Read-Host -Prompt "Recover Host Name for $Mode"
        }while([string]::IsNullOrEmpty($RecoverHost))
    }

    if($iSStoragevMotionVM -and [string]::IsNullOrEmpty($DatastoreName) -and $Mode -like 'Cleanup')
    {
        write-host "No Datastore Name found in the ConfigFile, please set the Datastore Name to $Mode"
        Do
        {
            [string]$DatastoreName = Read-Host -Prompt 'Datastore Name to $Mode'
        }while([string]::IsNullOrEmpty($DatastoreName))
    }
    elseif([string]::IsNullOrEmpty($VMName))
    {
        write-host "VMName was not found in the ConfigFile, please set the VM Name to $Mode"
        Do
        {
            [string]$VMName = Read-Host -Prompt "VM Name to $Mode"
        }while([string]::IsNullOrEmpty($VMName))
    }
    write-output "[$([DateTime]::Now)]  Config file variables correctly set"
}


# Set log file and log path for all the future logs
if([string]::IsNullOrEmpty($LogPath))
{
    $LogPath = $(split-path -parent $MyInvocation.MyCommand.Definition) + '\Logs'
    if(-not (Test-Path -Path $LogPath))
    {
        $null = New-item -ItemType Directory -Path $LogPath
    }
}

if([string]::IsNullOrEmpty($LogName))
{
    $LogName = "$(Get-Date -UFormat '%Y%m%d_%H%M%S')_" + $MyInvocation.MyCommand.Name.split('.')[0] + '.log'
}

$LogFile = Join-Path -Path $LogPath -ChildPath $LogName

# Retrieve the credentials if they were not passed by the user
if(-not $DoradoCred)
{
    $DoradoCred = Get-Credential -Message 'Enter your Dorado storage array credentials'
}

if(-not $viServerCred)
{
    $viServerCred = Get-Credential -Message 'Enter your vCenter credentials'
}


#########################
# ----- Functions ----- #
#########################


Function Start-Log {

  [CmdletBinding()]
  Param (
    #Full path and file name to the log file
    [Parameter(Mandatory=$true)][string]$LogFile,
    [Parameter(Mandatory=$true)][string]$ScriptVersion,
    [switch]$ScreenOutput
  )

  Process {

    #Start logging to file
    Add-Content -Path $LogFile -Value "###################################################################################################"
    Add-Content -Path $LogFile -Value "Script started at [$([DateTime]::Now)]"
    Add-Content -Path $LogFile -Value "###################################################################################################"
    Add-Content -Path $LogFile -Value ""
    Add-Content -Path $LogFile -Value "Running script version [$ScriptVersion]."
    Add-Content -Path $LogFile -Value ""
    Add-Content -Path $LogFile -Value "###################################################################################################"
    Add-Content -Path $LogFile -Value ""

    #Write output to screen if specified
    If ( $ScreenOutput ) {
      Write-Output "###################################################################################################"
      Write-Output "Script started at [$([DateTime]::Now)]"
      Write-Output "###################################################################################################"
      Write-Output ""
      Write-Output "Running script version [$ScriptVersion]."
      Write-Output ""
      Write-Output "###################################################################################################"
      Write-Output ""
    }
  }
}


Function Write-LogInfo {

  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)]
    [string]$LogFile,
    [Parameter(Mandatory=$true)]
    [string]$Message,
    [switch]$TimeStamp,
    [switch]$ScreenOutput
  )

  Process {
    #Add TimeStamp to message if specified
    If ( $TimeStamp -eq $True ) {
      $Message = "[$([DateTime]::Now)]  $Message"
    }

    #Write Content to Log
    Add-Content -Path $LogFile -Value "INFO: $Message"

    #Write Output to screen if specified
    If ( $ScreenOutput ) {
      Write-Output "INFO: $Message"
    }
  }
}


Function Stop-Log {

  [CmdletBinding()]
  Param (
    #Full path and file name to the log file
    [Parameter(Mandatory=$true)][string]$LogFile,
    [Parameter(Mandatory=$true)][string]$ScriptVersion,
    [switch]$ScreenOutput
  )

  Process {

    #Write to file
    Add-Content -Path $LogFile -Value ""
    Add-Content -Path $LogFile -Value "###################################################################################################"
    Add-Content -Path $LogFile -Value "Script ended at [$([DateTime]::Now)]"
    Add-Content -Path $LogFile -Value "###################################################################################################"
    Add-Content -Path $LogFile -Value ""

    #Write output to screen if specified
    If ($ScreenOutput) 
    {
        Write-Output ""
        Write-Output "###################################################################################################"
        Write-Output "Script ended at [$([DateTime]::Now)]"
        Write-Output "###################################################################################################"
    }
  }
}


function Request-UserConfirmation {
    [CmdletBinding()]
    Param(
        # Message to prompt the user for confirmation
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )

    $title    = 'Confirm'
    $question = $Message
    $choices  = '&Yes', '&No'

    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
    if ($decision -eq 0) {
        return $true
    } else {
        return $false
    }
}

function Request-UserChoiceSetMode {
    [CmdletBinding()]
    Param(
        # Switch to adapt the choices at the end of the Restore mode
        [switch]$Restore
    )

    $title = "Script execution"

    if($Restore)
    {
        
        $message = "Do you want to cleanup the restored VM ?"

        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
            "Removes the restored VM and its associated storage objects"

        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
            "Retains the restored VM and go to another VM or stop the script"

        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

        $result = $host.ui.PromptForChoice($title, $message, $options, 0)

        switch ($result)
        {
            0 {return 'Cleanup'}
            1 {return 'Stop'}
        }
    }
    else
    {
        $message = "Do you want to restore another VM / cleanup another VM or stop the script ?"

        $RestoreOption = New-Object System.Management.Automation.Host.ChoiceDescription "&Restore", `
            "Start a new restore for another VM - you'll be prompted for the needed values."

        $CleanupOption = New-Object System.Management.Automation.Host.ChoiceDescription "&Cleanup", `
            "Start a new cleanup for another VM - you'll be prompted for the needed values."

        $StopOption = New-Object System.Management.Automation.Host.ChoiceDescription "&Stop", `
            "Stop the script and disconnects from the Dorado and VMware APIs"

        $options = [System.Management.Automation.Host.ChoiceDescription[]]($RestoreOption, $CleanupOption, $StopOption)

        $result = $host.ui.PromptForChoice($title, $message, $options, 0)

        switch ($result)
        {
            0 {return 'Restore'}
            1 {return 'Cleanup'}
            2 {return 'Stop'}
        }
    }
}

function Select-HyperCDPObject {
    [CmdletBinding()]
    Param(
        # Array of HyperCDP objects or single object
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $HyperCDP
    )

    # Convert Timestamp info into DateTime
    $TimezoneOffset = Get-DoradoTimezoneOffset

    # Sort the HyperCDP objects by timestamp from most recent to oldest
    $SortedHyperCDP = $HyperCDP | Sort-Object -Property TIMESTAMP -Descending

    # Create an Hashmap that'll store all the Sorted snapshots 
    $HyperCDPHash = @{}

    # Loop on the HyperCDP objects to prepare the hashmap and the structure for efficient search by user input
    Foreach($snapshot in $SortedHyperCDP)
    {
        # Retrieve the HyperCDP and add it to the HashMap 
        [string]$DoradoTime = Get-DoradoDateFromTimestamp -Timestamp $snapshot.timestamp -Hours $TimezoneOffset.Hours -Minutes $TimezoneOffset.Minutes
        [string]$ShortDate = $DoradoTime.Substring(0,10)

        #Create a new Key entry in the Hashmap if it doesn't already exist to access snapshots by their short date
        if(-not $HyperCDPHash.ContainsKey($ShortDate))
        {
            $HyperCDPHash[$ShortDate] = New-Object -TypeName 'System.Collections.ArrayList'
        }

        # Add the HyperCDP object values to an Hashmap in the Arraylist 
        $null = $HyperCDPHash[$ShortDate].Add(@{
            'date' = $DoradoTime
            'id' = $snapshot.id
            'name' = $snapshot.name
        })
    }

    # Ask for the date
    Write-Host 'Select a date to browse the HyperCDP snapshots of the selected VM' -ForegroundColor DarkYellow

    [bool]$ValidResponse = $false
    Do {
        [string]$userInput = Read-Host -Prompt 'Date (yyyy/mm/dd)'

        # Check if userInput is correct
        if($userInput -match "\d{4}/\d{2}/\d{2}")
        {

            if($HyperCDPHash[$userInput].Count -gt 0)
            {
                [int]$Response = 0;   

                $ValidOption = $false
                while (-not $ValidOption) {            
                    [int]$OptionNo = 0

                    Write-Host 'Select the date you want to restore from' -ForegroundColor DarkYellow
                    Write-Host "[0]: Select a new Date"

                    foreach ($Option in $HyperCDPHash[$userInput])
                    {
                        $OptionNo += 1

                        Write-Host ("[$OptionNo]: {0} - {1}" -f $Option.date,$Option.name)
                    }

                    if ([Int]::TryParse((Read-Host), [ref]$Response)) 
                    {
                        if($Response -eq 0)
                        {
                            $ValidOption = $true
                        }
                        elseif($Response -le $OptionNo) 
                        {
                            $ValidOption = $true
                            $ValidResponse = $true
                        }
                    }
                }
            }
            else
            {
                Write-Host 'No valid HyperCDP snapshot exists at this date for this Lun'
            }
        }
    } until($validResponse)

    # Return the HyperCDP ID from the user choice
    return $HyperCDPHash[$userInput][$Response-1].id

}


##############################
# ----- Main Execution ----- #
##############################

Start-Log -LogFile $LogFile -ScriptVersion $ScriptVersion -ScreenOutput

#Connect to the Dorado storage array and the vCenter server
Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Connecting to Dorado storage array and vCenter'
$null = Connect-Dorado -Server $DoradoStorage -Credential $DoradoCred
$null = Connect-VIServer -Server $vCenter -Credential $viServerCred
Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Successfully connected'

# Check if the Folder from RestoredVMFolderName exists
if($RestoredVMFolderName)
{
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]$RestoredVMFolder = Get-Folder -Name $RestoredVMFolderName
}

# Check if the Resource Pool from RestoredResourcePoolName exists
if($RestoredResourcePoolName)
{
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ResourcePoolImpl]$RestoredVMResourcePool = Get-ResourcePool -Name $RestoredResourcePoolName
}

# Loop to allow multiple restores or cleanups until the user decides to stop the script
Do {

    #Start a Restore
    if($Mode -like 'Restore')
    {
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Starting Restore Mode'

        # Get datastore from VM Name to retrieve its Lun WWN
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Getting datastore values'
        $Datastore = Get-Datastore -VM $VMName
        [string]$LunWWN = Get-DatastoreLunWWN -Datastore $Datastore 
        

        # Reconnect after user interaction to avoid token expiration (if this is a new loop and user waited a long time to set his variables)
        $null = Connect-Dorado -Server $DoradoStorage -Credential $DoradoCred

        # Get Lun ID from its WWN
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Getting LUN values'
        $DoradoLun = Get-DoradoLun -WWN $LunWWN

        # Get all HyperCPD Objects
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Listing HyperCDP snapshots'
        $HyperCDP = Get-HyperCDPObjects -LunID $DoradoLun.ID

        # Prompt the user to select a date then an HyperCDP snapshot
        $SelectedHyperCDPId = Select-HyperCDPObject -HyperCDP $HyperCDP

        # Duplicate selected HyperCDP snapshot
        if([string]::IsNullOrEmpty($HyperCDPDuplicateName))
        {
            $HyperCDPDuplicateName = $DoradoLun.name + "_restore_$(Get-Date -UFormat '%Y%m%d_%H%M%S')"
        }

        # Reconnect after user interaction to avoid token expiration
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Creating HyperCDP Duplicate named $HyperCDPDuplicateName"
        $null = Connect-Dorado -Server $DoradoStorage -Credential $DoradoCred
        $SnapshotInfo = New-HyperCDPDuplicate -ID $SelectedHyperCDPId -Name $HyperCDPDuplicateName
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Successfully created HyperCDP Duplicate"

        # Map duplicate to Host
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Creating Host mapping between snapshot $($SnapshotInfo.name) and host $RecoverHost"
        $MappingInfo = New-DoradoSnapshotMapping -LunName $SnapshotInfo.name -HostName $RecoverHost
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Successfully created Host mapping"

        # Retrieve VMhost from the Dorado Host value
        $VMHost = Get-VMHostFromDoradoHost -Name $RecoverHost

        # Retrieve the new duplicate WWN and update the vmfs signature to create a new datastore
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Connecting restored snapshot as VMware datastore'
        $SnapshotLun = Get-DoradoLun -Name $SnapshotInfo.name
        $NewDatastore = Update-VMHostVmfsVolumeSignature -WWN $SnapshotLun.WWN -VMHost $VMHost
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "$NewDatastore successfully connected"

        # Register the new VM
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Registering restored VM"
        $RegisteredVM = Register-RestoredVM -VMHost $VMHost -Datastore $NewDatastore -VMName $VMName -RestoredVMName $RestoredVMName -Folder $RestoredVMFolder -ResourcePool $RestoredVMResourcePool
        $RegisteredVMName = $RegisteredVM.name
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "VM named $RegisteredVMName successfully registered"

        if(-not $KeepRestoredVMNetwork)
        {
            Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Disconnecting network adapters from restored VM $RegisteredVMName"
            try
            {
                $null = Get-NetworkAdapter -VM $RegisteredVM | where{$_.ConnectionState.StartConnected} | Set-NetworkAdapter -StartConnected:$false -Confirm:$false
            }
            catch
            {
                write-warning "An issue happened while trying to disconnect the Restored VM network adapters"
                throw $_.Exception
            }
            Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Successfully disconnected VM network adapters'
        }

        if($StartRestoredVM)
        {
            Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Starting restored VM $RegisteredVMName"
            $null = Start-VM -VM $RegisteredVM
            Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Successfully started VM'
        }

        # Prompt to ask if they want to continue to cleanup or stop the script
        $Mode = Request-UserChoiceSetMode -Restore

        #Remove VMName variable to be able to continue to a Cleanup with the current variables
        $VMName = $null

        #If the user wants to start a cleanup right away, ask if he moved the restored VM through storage vMotion to avoid removing it
        if($Mode -like 'Cleanup')
        {
            if(Request-UserConfirmation -Message "Did you storage vMotion the restored VM ? (if not, it'll be removed with the datastore)")
            {
                $iSStoragevMotionVM = $true
                [string]$DatastoreName = $NewDatastore.name 
            }
            else
            {
                $iSStoragevMotionVM = $false
            }
        }
    }

    

    #Start a Cleanup
    if($Mode -like 'Cleanup')
    {
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Starting Cleanup Mode'

        if($VMName)
        {
            $RegisteredVMName = $VMName
        }

        # Reconnect after user interaction to avoid token expiration
        $null = Connect-Dorado -Server $DoradoStorage -Credential $DoradoCred

        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Getting datastore values'
        if($iSStoragevMotionVM)
        {
            # Retrieve Datastore from Datastore Name
            $Datastore = Get-Datastore -Name $DatastoreName

            # Retrieve VMhost from the Dorado Host value
            $VMHost = Get-VMHostFromDoradoHost -Name $RecoverHost
        }
        else
        {
            # Retrieve current VMHost and Datastore of VM
            $VM = Get-VM -name $RegisteredVMName
            $VMHost = $VM.VMHost
            $Datastore = Get-Datastore -VM $VM
        }
        
        $LunWWN = $Datastore.ExtensionData.Info.Vmfs.Extent[0].DiskName.Split(".")[1]

        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Getting Lun and snapshot values'
        $SnapshotInfo = Get-DoradoSnapshot -WWN $LunWWN
        $LunInfo = Get-DoradoLun -WWN $LunWWN

        if(-not $iSStoragevMotionVM)
        {
            Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "VM $VM was not moved with storage vMotion - asking user for removal confirmation"
            
            # Poweroff VM if it's still up and ask for confirmation
            if($VM.PowerState -eq 'PoweredOn')
            {
                Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Stopping VM $VM by user request"
                $null = Stop-VM -VM $VM
                Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Successfully stopped VM $VM"
            }
            
            # Remove VM and ask for confirmation
            Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Removing VM $VM by user request"
            Remove-VM -VM $VM
            Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Successfully removed VM $VM"
        }

        # Remove Datastore from VMware Host
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Removing datastore $Datastore"
        Remove-Datastore -Datastore $Datastore -VMHost $VMHost -Confirm:$false
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Successfully removed datastore $Datastore"

        # Remove Snapshot Mapping from Dorado storage array
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Removing snapshot mapping between lun $($LunInfo.name) and host $RecoverHost"
        $null = Connect-Dorado -Server $DoradoStorage -Credential $DoradoCred
        Remove-DoradoSnapshotMapping -LunName $LunInfo.name -HostName $RecoverHost -Confirm:$false
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Successfully removed snapshot mapping'

        # Remove Lun snapshot and target Lun from Dorado storage array
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Deleting snapshot $($SnapshotInfo.name) (hyperCDP duplicate)"
        Remove-DoradoLunSnapshot -ID $SnapshotInfo.ID -Confirm:$false
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Successfully deleted snapshot (hyperCDP duplicate)'
    }

    # Remove shared variables
    $VMName = $null
    $RecoverHost = $null

    # Remove Restore variables
    $Datastore = $null
    $LunWWN = $null
    $DoradoLun = $null
    $HyperCDP = $null
    $SelectedHyperCDPId = $null
    $HyperCDPDuplicateName = $null
    $RestoredVMName = $null
    $RestoredVMFolderName = $null
    $RestoredResourcePoolName = $null
    $RestoredVMFolder = $null
    $RestoredVMResourcePool = $null
    $SnapshotInfo = $null
    $MappingInfo = $null
    $VMHost = $null
    $SnapshotLun = $null
    $NewDatastore = $null
    $RegisteredVM = $null
    $RegisteredVMName = $null
    $StartRestoredVM = $null
    $KeepRestoredVMNetwork = $null

    # Remove Cleanup variables
    $VM = $null
    $VMHost = $null
    $RegisteredVMName = $null
    $Datastore = $null
    $LunWWN = $null
    $SnapshotInfo = $null
    $LunInfo = $null
    $iSStoragevMotionVM = $false
    $DatastoreName = $null

    # Prompt to ask if they want to continue to restore on a new VM, Cleanup on a new VM or stop the script
    $Mode = Request-UserChoiceSetMode

    # Set the needed values before starting the next mode
    if($Mode -notlike 'Stop')
    {
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Prompting user for needed values'

        # Ask for mandatory values until they are set
        Do
        {
            [string]$RecoverHost = Read-Host -Prompt "Recover Host Name for $Mode"
        }while([string]::IsNullOrEmpty($RecoverHost))
        
        # Set the Restore mode optional values
        if($Mode -like 'Restore')
        {
            # Ask for mandatory values until they are set
            Do
            {
                [string]$VMName = Read-Host -Prompt "VM Name to $Mode"
            }while([string]::IsNullOrEmpty($VMName))

            [bool]$StartRestoredVM = Request-UserConfirmation -Message 'Do you want to start the VM once restored ?'
            [bool]$KeepRestoredVMNetwork = Request-UserConfirmation -Message 'Do you want to keep the restored VM network adapters connected ?'

            # Ask the user if they want to set the variable for each optional one
            if(Request-UserConfirmation -Message 'Do you want to set a specific name for the HyperCDP Duplicate ?')
            {
                Do
                {
                    [string]$HyperCDPDuplicateName = Read-Host -Prompt 'HyperCDP Duplicate name'
                }while([string]::IsNullOrEmpty($HyperCDPDuplicateName))
            }

            if(Request-UserConfirmation -Message 'Do you want to set a specific name for the Restored VM ?')
            {
                Do
                {
                    [string]$RestoredVMName = Read-Host -Prompt 'Restored VM name'
                }while([string]::IsNullOrEmpty($RestoredVMName))
            }

            # For specific PowerCLI objects - verify that the object exists before continuing
            if(Request-UserConfirmation -Message 'Do you want to restore the VM in a specific VM Folder ?')
            {
                $VMFolderFound = $false
                Do
                {
                    [string]$RestoredVMFolderName = Read-Host -Prompt 'VM Folder Name'


                    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]$RestoredVMFolder = Get-Folder -Name $RestoredVMFolderName -ErrorAction SilentlyContinue

                    if(-not $RestoredVMFolder)
                    {
                        write-host "No folder named $RestoredVMFolderName found in the vCenter $vCenter. Please enter a new folder name." -ForegroundColor DarkYellow
                    }
                    else
                    {
                        $VMFolderFound = $true
                    }

                } until($VMFolderFound)
            }
        
            if(Request-UserConfirmation -Message 'Do you want to restore the VM in a specific Resource Pool ?')
            {
                $VMResourcePoolFound = $false
                Do
                {
                    [string]$RestoredResourcePoolName = Read-Host -Prompt 'Resource Pool Name'


                    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ResourcePoolImpl]$RestoredVMResourcePool = Get-ResourcePool -Name $RestoredResourcePoolName -ErrorAction SilentlyContinue

                    if(-not $RestoredVMResourcePool)
                    {
                        write-host "No Resource Pool named $RestoredResourcePoolName found in the vCenter $vCenter. Please enter a new Resource Pool name." -ForegroundColor DarkYellow
                    }
                    else
                    {
                        $VMResourcePoolFound = $true
                    }

                } until($VMResourcePoolFound)
            }
        }
        elseif($Mode -like 'Cleanup')
        {
            # Ask the user if the Restored VM was moved through storage vMotion to avoid removing a production instance
            if(Request-UserConfirmation -Message "Did you storage vMotion the restored VM ? (if not, it'll be removed with the datastore)")
            {
                $iSStoragevMotionVM = $true
                [string]$DatastoreName = Read-Host -Prompt 'Enter the Datastore Name to cleanup'
            }
            else
            {
                $iSStoragevMotionVM = $false

                # Ask for mandatory values until they are set
                Do
                {
                    [string]$VMName = Read-Host -Prompt "VM Name to $Mode"
                }while([string]::IsNullOrEmpty($VMName))
            }
        }
        Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message "Finished setting all required values - starting new $Mode"
    }
} while ($Mode -notlike 'Stop')

# Disconnect from the Dorado storage array and the vCenter server
Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Disconnecting from the Dorado storage array and vCenter server'
Disconnect-DoradoServer -Confirm:$false
Disconnect-VIServer -Confirm:$false
Write-LogInfo -LogFile $LogFile -Timestamp -ScreenOutput -Message 'Successfully disconnected'

Stop-Log -LogFile $LogFile -ScriptVersion $ScriptVersion -ScreenOutput