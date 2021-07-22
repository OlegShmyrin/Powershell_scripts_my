$user = get-Aduser mis.il-sinegub -Properties pwdLastSet 

$date = [datetime]::FromFileTime($user.pwdLastSet);

write-host $date.addDays(90)