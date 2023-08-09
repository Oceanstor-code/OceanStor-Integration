# VMWare-Storage-Snapshot-Restore

This interactive Microsoft Powershell script can be used to restore VMWare VMs from Huawei Dorado HyperCDP snapshots, or to cleanup the datastores / snaphsots and host mapping after a successful restore. 

# Requirements

This script requires 2 modules : 
- Huawei.Dorado (which is included in this github folder)
- PowerCLI from VMWare

# Using the script

To start a restore or a cleanup, you can use parameters while starting the script or an XML configuration file. 

1. Start a restore using parameters.
```powershell
    ./Start-DoradoCDPRestore -DoradoStorage '192.168.0.1' -vCenter '192.168.0.2' -VMName 'myVM' -RecoverHost 'esx-01.my-domain.com'
```

This command will restore the VM named "myVM' with a timestamped suffix, on the vCenter and Dorado storage specified. 

The recovered datastore will be mapped on the RecoverHost, which name should exist on the Dorado storage. 

The VM will be restored to the original VM folder and resource pool. 

You'll be asked for your Dorado storage and vCenter credentials during the script execution, as well as which HyperCDP object you want to restore from.

2. Start a cleanup using parameters.

```powershell
    ./Start-DoradoCDPRestore -DoradoStorage '192.168.0.1' -vCenter '192.168.0.2' -RecoverHost 'esx-01.my-domain.com' -VMName 'myVM' -DatastoreName 'snap-65268-myDS' -Mode Cleanup -iSStoragevMotionVM
```

This command will cleanup the environment of a restored VM named 'myVM'. 

The 'iSStoragevMotionVM' specifies that this VM has been moved through storage vMotion and should not be removed. 

Which is why 'DatastoreName' should be specified so that we can still remove the temporary restore Datastore as well as its associated objects on the dorado storage array. 

3. Start the script using a configuration file

```powershell
    ./Start-DoradoCDPRestore -ConfigFilePath 'C:\myFolders\myConfigFile.xml'
```

This command will start the script using the parameters specified in an XML configuration file.

You'll find configuration file examples in the 'cleanup_config.xml' and 'restore_config.xml'.

All parameters can be specified in the configuration file.

# Creating a configuration file

To start using a configuration file, look at the 'cleanup_config.xml' and 'restore_config.xml'. 

These two files include all the current parameters that can be used and how to declare them. 

The only specificities are how to declare 'switch' parameters like -iSStoragevMotionVM. 

To do so, the value of the parameter should be 'true'. It will be set to false if you enter anything else as the value. 

# Parameters

This is the list of the current parameters that can be set through the command line or in a configuration file. 

| Parameter | Mode | Mandatory | Description |
|-----------|------|-----------|-------------|
| DoradoStorage | Restore & Cleanup | yes | Dorado management IP or FQDN |
| vCenter       | Restore & Cleanup | yes | vCenter server management IP or FQDN |
| VMName        | Restore & Cleanup | yes | Name of the VM to restore / cleanup |
| RecoverHost   | Restore & Cleanup | yes | Name of the Host in the Dorado storage array |
| ConfigFilePath | Restore & Cleanup | no | Path to the XML config file |
| Mode          | Restore & Cleanup | no | Mode to start the script - defaults to Restore |
| DoradoCred    | Restore & Cleanup | no | Credentials to authenticate to the Dorado storage array - will be prompted for if null, should be a PSCredential object
| viServerCred  | Restore & Cleanup | no | Credentials to authenticate to the vCenter server - will be prompted for if null, should be a PSCredential object
| HyperCDPDuplicateName | Restore | no | Name of the Duplicate of the HyperCDP snapshot that will be created
| RestoredVMName | Restore | no | Name of the restored VM if specified - else, it'll be based on the origin VM with a timestamp suffix
| RestoredVMFolderName | Restore | no | Name of the Folder to register the VM into - defaults to the origin VM folder
| RestoredResourcePoolName | Restore | no | Name of the Resource Pool to register the VM into - defaults to the origin VM ResourcePool
| KeepRestoredVMNetwork | Restore | no | Keep the Network cards of the restored VM connected
| StartRestoredVM | Restore | no | Switch to start the Restored VM
| iSStoragevMotionVM | Cleanup | no | Switch to specify that a VM has been moved through storage vMotion to another datastore and shouldn't be removed
| DatastoreName | Cleanup | yes if iSStoragevMotionVM is enabled | Datastore Name to cleanup  - used when the iSStoragevMotionVM switch is enabled
| LogPath | Restore and Cleanup | no | Path to the log file - defaults to a Logs folder in the script directory
| LogName | Restore and Cleanup | no | Name of the log file - defaults to a timestamp prefix file named after your script file