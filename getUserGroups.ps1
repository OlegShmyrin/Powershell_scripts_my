

[string]$username = "Oleg.shmyrin"

[string]$PathToFile = "C:\Intel\Grops.csv"


Get-ADPrincipalGroupMembership $username | Get-ADGroup -Properties * | select name, description | Export-Csv -Path $PathToFile -Encoding Default
