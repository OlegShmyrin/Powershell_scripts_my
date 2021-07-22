

#Write-Host "Введите логин и пароль для авторизации на сервере." -ForegroundColor Green


#Тестовые данные для проверки работы скрипта
$User = "metinvest\adm.o.shmyrin.app"
$PWord = ConvertTo-SecureString -String "Alexandra+Grigory2030" -AsPlainText -Force
$Cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord

#Ввод УЗ которая имеет право на авторизацию на сервере
#$Cred = Get-Credential



#Write-Host "Введите номер HotFix для Server 2012:" -ForegroundColor Green
#$PatchID2012=read-host

$PatchID2012 = "KB5004298"

#Write-Host "Введите номер HotFix для Server 2016:" -ForegroundColor Green
#$PatchID2016=read-host

$PatchID2016 = "KB5004238"

#Считываем список серверов из файла

$Servers = Get-Content D:\Scripts\Servers.txt



foreach($Server in $Servers) 
{
  
  if (Test-Connection -computername $Server -Quiet -Count 1) {


        $OSVersion = Get-ADComputer $Server -Properties OperatingSystem | select OperatingSystem
        #write-host $OSVersion

  


  if($OSVersion -like "*Server 2012 R2*")
  {
    
    Try{
        
        
        If (Get-HotFix -Id "$PatchID2012"  -ComputerName $Server -ErrorAction Stop -Credential $Cred)
        {
            Write-Host "$PatchID2012 Установлен на сервере $Server. Версия ОС 2012" -ForegroundColor Green
        }
        }Catch [Exception]
  
        {
    
   $ErrorMsg = $_.Exception
    Write-Warning ("$ErrorMsg" + "на сервере $Server")
  }

    
    
    
    
    ################# 
       
  }Elseif($OSVersion -like "*Server 2016*")
    {

        
        Try{
        If (Get-HotFix -Id "$PatchID2016"  -ComputerName $Server -ErrorAction Stop -Credential $Cred)
        {
            Write-Host "$PatchID2016 Установлен на сервере $Server. Версия ОС 2016" -ForegroundColor Green
        }
    }Catch [Exception]
  
  {
    
   $ErrorMsg = $_.Exception
    Write-Warning ("$ErrorMsg" + "на сервере $Server")
  }

    }
    
   } else {
        Write-Warning "Не удалось установить подключение с сервером: $Server"
    }
      
 }

