function Test-VIServerConnection {
  <#
    .SYNOPSIS
    Tests for an active connection on a vCenter Server

    .DESCRIPTION
    The Test-VIServerConnection function tests to see if a session has been opened on a vCenter Server.
    If the VIServer is not currently connected, this will throw an error and halt the script
  #>

    [CmdletBinding()]
    param()
        Write-Verbose -Message 'Validate the vCenter connection exist'
        if (-not $global:DefaultVIServer.IsConnected) 
        {
            Write-Warning -Message 'Please connect to one vCenter server before running this command.'
            throw 'A connection with Connect-VIServer is required.'
        }
        Write-Verbose -Message 'Found a VI server active connection'
}

