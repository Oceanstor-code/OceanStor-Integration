#Requires -Version 3
function Get-DoradoDateFromTimestamp {
  <#
      .SYNOPSIS
      Converts a Dorado timestamp into a Datetime in the same timezone as the Dorado storage array configuration

      .DESCRIPTION
      The Get-DoradoDateTimeFromTimestamp cmdlet will convert a Dorado timestamp into a Datetime in the same timezone as the Dorado storage array.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      Get-DoradoDateTimeFromTimestamp -Timestamp '1690796119'

      This will query the Dorado storage Array for its timezone offset and convert the timestamp into a default date format.

      .EXAMPLE
      Get-DoradoDateTimeFromTimestamp -Timestamp '1690796119' -Hours '-1' -Minutes '30' -UFormat '%d/%m/%Y %H:%m:%S'

      This will convert the timestamp into a corresponding date format with the specified offset.
  #>

    [CmdletBinding()]
    Param(
        # Value of the Timestamp to convert
        [Parameter(Mandatory=$true)]
        [String]$Timestamp,
        # Number of hours to offset the timestamp
        [ValidateNotNullOrEmpty()]
        [String]$Hours,
        # Number of minutes to offset the timestamp
        [ValidateNotNullOrEmpty()]
        [String]$Minutes,
        # Specific format to apply to the DateTime object
        [ValidateNotNullOrEmpty()]
        [String]$UFormat
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
            Write-Verbose -Message "Converting timestamp to correct Date"

            $EpochDate = (Get-Date 01.01.1970)
            
            if($Hours)
            {
                $EpochDate = $EpochDate.AddHours($Hours)
            }

            if($Minutes)
            {
                $EpochDate = $EpochDate.AddMinutes($Minutes)
            }

            if(-not $Hours -and -not $Minutes)
            {
                $TimezoneOffset = Get-DoradoTimezoneOffset

                $EpochDate = $EpochDate.AddHours($TimezoneOffset.hours).AddMinutes($TimezoneOffset.minutes)
            }
            
            $FinalDate = $EpochDate + ([System.TimeSpan]::fromseconds($Timestamp))

            if($Uformat)
            {
                $FinalDate = Get-Date $FinalDate -UFormat $Format
            }
            else
            {
                
                $FinalDate = Get-Date $FinalDate -UFormat '%Y/%m/%d %H:%M:%S'
            }
        }
        catch
        {
            write-warning -Message "Could not timestamp to date format"
            throw $_.Exception
        }

        if(-not $FinalDate)
        {
            write-warning -Message "Could not convert timestamp to date format"
            throw "Empty date result when trying to convert timestamp $Timestamp"
        }

        return $FinalDate
    }
}