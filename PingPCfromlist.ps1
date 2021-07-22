Import-Module ActiveDirectory
  
  $ServerName = Get-Content "C:\tmp\PingPC.csv"  

  
foreach ($Server in $ServerName) {  
  
        if (test-Connection -ComputerName $Server -Count 2 -Quiet) {   
          
            Write-Host "$Server is Pinging "  -ForegroundColor Green;
            
          
                    } else  
                      
                    {
                     Write-Host "$Server not pinging" -ForegroundColor Red
                     
                     #   $LPC=Get-ADComputer $Server -Properties lastLogon
                      #  $time =$LPC.lastLogon
                       # $dt = [DateTime]::FromFileTime($time)
                       # Write-Host "ПК $Server not pinging, и логинился $dt" -ForegroundColor Red
                          
                            
                    }      
          
} 


