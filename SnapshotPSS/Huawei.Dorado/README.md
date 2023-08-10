# Huawei Dorado Powershell Module

This Microsoft Powershell module can be used to manage Huawei Dorado storage arrays through its RESTful APIs. It has a focus on managing HyperCDP snapshots, LUNs and its VMware counterpart.

# Installation

Load the module by using:

```powershell
Import-Module Huawei.Dorado
```

To install the Module, copy the Huawei.Dorado folder to one your Powershell Path. You can get your Path by using:

```powershell
$env:PSModulePath
```

# Connection

The Huawei Dorado Powershell Module provides multiple mechanisms for supplying credentials to the Connect-Dorado function. You'll find below 2 different methods:
1. Using a credential object.
   Using a powershell Credentials object
   ```powershell
      $Credential = Get-Credential
      Connect-Dorado -Server 192.168.0.1 -Credential $Credential
   ```
   This prompts for a username and password to create a credential object and connects to the storage array.
2. Using a Username and Password.
   Example:
   ```powershell
      Connect-Dorado -Server 192.168.0.1 -Username "MyUser"
   ```
   This prompts for a password an connects to the storage array.