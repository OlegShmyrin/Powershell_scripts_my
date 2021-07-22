$GroupNames = Import-Csv "C:\tmp\Grp.csv" -Encoding Default -Delimiter ";"

Foreach ($Group in $GroupNames) {
$Name = $Group.Name
$Description = $Group.description
$Manager = $Group.extensionAttribute10

Write-Host $Name
#New-ADGroup -Name $Name -SamAccountName $Name -GroupCategory Security -GroupScope Global -DisplayName $Name -Path "OU=PRN,OU=Application Groups,OU=AKZ,DC=metinvest,DC=ua" -Description $Description -ManagedBy $Manager -WhatIf

}

Import-Csv "C:\tmp\Grp.csv" -Encoding Default -Delimiter ";"