function Test-DoradoConnection {
  <#
    .SYNOPSIS
    Tests for an active connection on a Dorado Storage Array

    .DESCRIPTION
    The Test-DoradoConnection function tests to see if a session has been opened on a Dorado storage Array.
    If no session or token is found, this will throw an error and halt the script.

  #>
  [CmdletBinding()]
  param()
    Write-Verbose -Message 'Validate the Dorado session and token exist'
    if (-not $global:Doradoconnection.headers -or -not $global:Doradoconnection.session) 
    {
        Write-Warning -Message 'Please connect to one Dorado Storage Array before running this command.'
        throw 'A connection with Connect-Dorado is required.'
    }
    Write-Verbose -Message 'Found a Dorado session and token for authentication'
}

