Param (
    [Parameter(Mandatory = $false)]
    [int] $DaysToWarn = 14,

    [Parameter(Mandatory = $false)]
    [switch] $ListExpiringAccounts,

    [Parameter(Mandatory = $false)]
    [string] $UserName
)

## Updating the file from github....should see this in the runbook.

function Get-ADUserPasswordExpirationDate {
    Param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "User's domain username")]
        [Object] $UserName,
        [int] $DaysToWarn
    )

    # initialize local variables
    $maxPasswordAgeTimeSpan = $null   
    $UserRow = $null # purge previous user data

    # Collect User data
    try {
        Write-Verbose "Retrieving $UserName details"
        $UserDetails = Get-ADUser $UserName -properties PasswordExpired, PasswordNeverExpires, PasswordLastSet, name, mail

        # Check to see if password never expires
        if ((!($UserDetails.PasswordExpired)) -and (!($UserDetails.PasswordNeverExpires))) {
            $PasswordSetDate = $UserDetails.PasswordLastSet
            if ($passwordSetDate -ne $null) {
                
                # check for user resultant password policy
                $UserRSOP = Get-ADUserResultantPasswordPolicy $UserName
                if ($UserRSOP -ne $null) {
                    $maxPasswordAgeTimeSpan = $UserRSOP.MaxPasswordAge
                }
                else {
                    $maxPasswordAgeTimeSpan = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge
                }

                Write-Verbose "Password Last Set: $PasswordSetDate"
                Write-Verbose "Max Password Age: $maxPasswordAgeTimeSpan"

                # Calculate the days until expiration & date of expiration 
                if ($maxPasswordAgeTimeSpan -eq $null -or $maxPasswordAgeTimeSpan.TotalMilliseconds -ne 0) {
                    $DaysTillExpire = [math]::round(((New-TimeSpan -Start (Get-Date) -End ($passwordSetDate + $maxPasswordAgeTimeSpan)).TotalDays), 0)
                    $PolicyDays = [math]::round((($maxPasswordAgeTimeSpan).TotalDays), 0)
                    $DateofExpiration = (Get-Date).AddDays($DaysTillExpire)     
                                                  
                    # Write-Verbose "Date of Expiration: $DateofExpiration"
                    # Write-Verbose "Policy Days: $PolicyDays"
                    # Write-Verbose "Days Until Expiration: $DaysTillExpire"
                    # Write-Verbose "Days To Warn: $DaysToWarn"

                    #if ($preview) {$DaysTillExpire = 1}

                    if (($DaysTillExpire -le $DaysToWarn) -or ($PreviewUser)) {
                        # Add user to expiring accounts table
                        $UserRow = New-Object PSObject -Property @{
                            UserName             = $UserDetails.samAccountName
                            EmailAddress         = $UserDetails.mail
                            DisplayName          = $UserDetails.Name
                            PasswordExpired      = $UserDetails.PasswordExpired
                            PasswordLastSet      = $UserDetails.PasswordLastSet
                            PasswordNeverExpires = $UserDetails.PasswordNeverExpires
                            DaysUntilExpire      = $DaysTillExpire
                            DateofExpiration     = $DateofExpiration
                            MaxPasswordAge       = $PolicyDays                            
                        } 
                        
                        Write-Verbose "UserRow Data:"
                        Write-Verbose $UserRow
                    }                    
                }
            }
            else {
                Write-OutPut "Password set date is null. Skipping"
            }
        }
        else {
            Write-Output "Password set to never expires. Skipping"   
        }
        return $UserRow
    }
    catch {
	write-output $error[0]
    }
} # end function Get-ADUserPasswordExpirationDate

$UserData = Get-ADUserPasswordExpirationDate -UserName $UserName -DaysToWarn $DaysToWarn

#$UserData | Out-File -FilePath 'c:\scripts\adinfo.txt'

Write-Output $UserData

Write-Output "Script Complete"
