$PSGroups = Get-ADGroup -Filter {name -like "grpAKZ-ps*"}

  foreach($PSGroup in $PSGroups) {
            
            Write-host "Ищем откл пользователей в группе $PSGroup" -ForegroundColor Green

            $grpusers = Get-ADGroupMember -Identity $PSGroup | ? {$_.objectclass -eq "user"}




            foreach($user in $grpusers){

    
                $DisUser = Get-ADUser $user -Properties Name,Enabled | ? {$_.Enabled -eq $false} | Select-Object Name,Enabled   

                $DisUser
                #Remove-ADGroupMember -Identity $PSGroup -Members $DisUser -Verbose
            }

}