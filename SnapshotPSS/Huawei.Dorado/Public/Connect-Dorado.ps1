#Requires -Version 3
function Connect-Dorado {
  <#
      .SYNOPSIS
      Connects to a Dorado storage Array

      .DESCRIPTION
      The Connect-Dorado cmdlet will authenticate to the storage array Rest API, set a global session and return the authentication result.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      Connect-Dorado -Server '192.168.0.1' -Port '8088' -username 'user' -password 'password'

      This will authenticate to the Dorado storage array through a specific port thanks to a plain text password for a local user.

      .EXAMPLE
      Connect-Dorado -Server '192.168.0.1' -Credential (Get-Credential) -Scope LDAP

      This will authenticate to the Dorado storage array by prompting for the credentials of an LDAP user.
  #>

    [CmdletBinding()]
    Param(
        # Dorado management IP or FQDN
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$Server,
        # Username with permissions to connect to the Dorado storage array
        # Optionally, use the Credential parameter    
        [Parameter(ParameterSetName='UserPassword',Mandatory=$true, Position = 1)]
        [String]$Username,
        # Password for the Username provided
        # Optionally, use the Credential parameter
        [Parameter(ParameterSetName='UserPassword',Mandatory=$true, Position = 2)]
        [String]$Password,
        # Credentials with permission to connect to the Rubrik cluster
        # Optionally, use the Username and Password parameters
        [Parameter(ParameterSetName='Credential',Mandatory=$true, Position = 1)]
        [System.Management.Automation.CredentialAttribute()]$Credential,
        # Port to use for the connection to the API, defaults to 8088
        [string]$Port = '8088',
        # User type for authenticating
        [ValidateSet('local','LDAP','RADIUS')] 
        [string]$Scope = 'local'
    )

    Begin 
    {
        if (-not ($PSVersionTable.PSVersion.Major -ge 6)) 
        {
            Enable-SelfSignedCert

            #Force TLS 1.2
            try 
            {
                if ([Net.ServicePointManager]::SecurityProtocol -notlike '*Tls12*') 
                {
                    Write-Verbose -Message 'Adding TLS 1.2'
                    [Net.ServicePointManager]::SecurityProtocol = ([Net.ServicePointManager]::SecurityProtocol).tostring() + ', Tls12'
                }
            }
            catch 
            {
                Write-Verbose -Message $_
                Write-Verbose -Message $_.Exception.InnerException.Message
            }
        }

        $ScopeMapping = @{
            'local' = 0
            'LDAP' = 1
            'RADIUS' = 8
        }
    }

    Process 
    {

        # Test Dorado credentials and prepare them for the authentication
        if($Credential)
        {
            $Username = $Credential.Username
            $Password = $Credential.GetNetworkCredential().Password
        }
        elseif($Username -eq $null -or $Password -eq $null)
        {
            Write-Warning -Message 'You did not enter any username, password or credentials.'
            $Credential = Get-Credential -Message 'Please enter your Dorado credentials.'

            $Username = $Credential.Username
            $Password = $Credential.GetNetworkCredential().Password
        } 

        # Prepare the api call
        $body = @{
            username = $Username
            password = $Password
            scope = $ScopeMapping[$Scope]
            loginMode = 3
            timeConversion = 1
        } | ConvertTo-Json

        $uri = "https://${Server}:${Port}/deviceManager/rest/xxxxx/sessions"

        try
        {
            Write-Verbose -Message 'Submitting the web request to authenticate to the Dorado rest API'
            $Result = Invoke-RestMethod -Uri $uri -Method Post -Body $body -SessionVariable session        }        catch        {            write-warning -Message 'Could not log in to the Dorado rest API'            throw $_.Exception        }        Write-Verbose -Message 'Storing session details into $global:DoradoSession'        $global:Doradoconnection = @{
            deviceID = $Result.data.deviceid
            Server = $Server
            Port = $Port
            Headers = @{
                iBaseToken = $Result.data.iBaseToken
            }
            session = $session
        }

        return $true
    }
}