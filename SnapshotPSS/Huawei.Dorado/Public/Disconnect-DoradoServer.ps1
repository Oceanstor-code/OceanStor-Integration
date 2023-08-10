#Requires -Version 3
function Disconnect-DoradoServer {
  <#
      .SYNOPSIS
      Exits the current session opened on a Dorado storage array

      .DESCRIPTION
      The Disconnect-DoradoServer cmdlet will exit the current session opened on a Dorado storage array.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      Disconnect-DoradoServer

      This will exit the current session opened on the authenticated Dorado storage array
  #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param()

    if($PSCmdlet.ShouldProcess(
                    ("Server : $($global:Doradoconnection.server), deviceId : $($global:Doradoconnection.deviceID)"),
                    "Remove Dorado Snapshot Mapping"
                )
    ){

        Write-Verbose -Message 'Validate the Dorado session and token exist'
        if (-not $global:Doradoconnection.headers -or -not $global:Doradoconnection.session) 
        {
            Write-Verbose -Message 'No existing Dorado session. Nothing to do.'
        }
        else
        {
            try
            {
                Write-Verbose -Message 'Exiting the current Dorado session'
                $uri = "https://$($global:Doradoconnection.server)`:$($global:Doradoconnection.Port)/deviceManager/rest/$($global:Doradoconnection.deviceID)/sessions"

                $null = Invoke-RestMethod -Uri $uri -Method Delete -Headers $global:Doradoconnection.Headers -WebSession $global:Doradoconnection.session
                $global:Doradoconnection = $null
            }
            catch
            {
                Write-Warning -Message 'An error occured while trying to exit current Dorado session'
                throw $_.Exception
            }
        }
    }
}