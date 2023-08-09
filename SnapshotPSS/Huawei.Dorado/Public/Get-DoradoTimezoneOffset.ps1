#Requires -Version 3
function Get-DoradoTimezoneOffset {
  <#
      .SYNOPSIS
      Retrieves the timezone offsets from the dorado system configuration

      .DESCRIPTION
      The Get-DoradotimezoneOffset cmdlet will retrieve the timezone offset from the dorado system configuration.

      .NOTES
      Written by Huawei for community usage

      .EXAMPLE
      Get-DoradoTimezoneOffset

      This will retrieve the Dorado timezone offsets (Hours and Minutes).
  #>

    [CmdletBinding()]
    Param()

    Begin 
    {
        # Check the authentication globals
        Test-DoradoConnection
    }

    Process 
    {
        try
        {
            Write-Verbose -Message "Retrieving Dorado storage Array timezone offset"

            $uri = "https://$($global:Doradoconnection.server)`:$($global:Doradoconnection.Port)/deviceManager/rest/$($global:Doradoconnection.deviceID)/system_timezone"
            $Timezone = Invoke-RestMethod -Uri $uri -Method Get -Headers $($global:Doradoconnection.Headers) -WebSession $($global:Doradoconnection.session)
        
            $SplitTimezone = $Timezone.data[0].CMO_SYS_TIME_ZONE.split(':')
            [string]$Operator = $SplitTimezone[0][0]

            if($Timezone.data[0].CMO_SYS_TIME_ZONE_USE_DST -eq '1')
            {
                if($(Get-Date).IsDaylightSavingTime())
                {
                    [string]$SplitTimezone[0] = [int]$SplitTimezone[0] + 1
                }
            }

            [string]$TimezoneHours = $Operator + $SplitTimezone[0]            [string]$TimezoneMinutes = $Operator + $SplitTimezone[1]

            $TimezoneOffset = @{
                hours = $TimezoneHours
                minutes = $TimezoneMinutes
            }
        }
        catch
        {
            write-warning -Message "Could not retrieve any timezone info"
            throw $_.Exception
        }

        if(-not $Timezone.data -or $Timezone.error.code -ne 0)
        {
            write-warning -Message "Could not retrieve any timezone info"
            throw "Empty timezone result while querying for $uri"
        }

        return $TimezoneOffset
    }
}