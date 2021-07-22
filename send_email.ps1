
if(-not (Test-Path -Path C:\windows\Temp\logfiles\logs.txt)) {
New-Item -Path "C:\windows\Temp" -Name "logfiles" -ItemType "directory"
New-Item -Path "C:\windows\Temp\logfiles" -Name "logs.txt" -ItemType "file" -Value "Logs at startup server"
}
$report = "C:\windows\Temp\logfiles\logs.txt"

$report = "C:\windows\Temp\logfiles\logs.txt"
Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Start" -Append


#################################################
#################################################
Function SendReport
{
#Пишем в консоль
    Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Функция отправки почты" -Append
    #От кого отправляем
    $EmailFrom = "svcAKZ.scan@metinvestholding.com"
    #Кому. Через запятую можно несколько
    $EmailTo = "oleg.shmyrin@metinvestholding.com;Andrey.Zavina@metinvest.digital"
    #Тема письма
    $Subject = "$Server Staus report" 
    #Формируем тело для C# методов
    $body = New-Object System.Net.Mail.MailMessage $EmailFrom, $EmailTo, $Subject, $bodyText  
    $body.isBodyhtml = $true #??
    #Почтовый сервер
    $SMTPServer = "mail.metinvestholding.com"
    #Вызываем C# функцию отправки писем
    $smtp = new-object Net.Mail.SmtpClient($SMTPServer, 2525) 
    #Включаем шифрование
    $smtp.EnableSsl = $true
    #УЗ для авторизации/отправки писем
    $smtp.Credentials = New-Object System.Net.NetworkCredential("svcAKZ.scan@metinvestholding.com", "P@ssw0rd2017")
    #Не проверяем на сертификаты сервера
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }
    #отправляем письмо
    $smtp.Send($body) 

}

Function ServiceCheck 
{
    param($SearchServiceName) 

    #Получаем сулжбу по имени и ее первоначальный статус
    Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Функция поиска службы по имени" -Append
    $Service =  Get-Service -ComputerName $Server -Include $SearchServiceName

    #Выдергиваем из сущности службы Имя
    $ServiceName = $Service.Name.ToString()
    $ServiceName

    Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Имя службы $ServiceName" -Append
    #Выдергиваем из сущности службы Статус службы
    $ServiceStatus = $Service.Status.ToString()
    $ServiceStatus
    Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Сосотояние службы $ServiceStatus" -Append

    Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Выход из функции поиска службы по имени" -Append

    Return $Service
}

########################################
#######################################

#Получаем имя сервера
$Server = Hostname
#Задаем имя отслеживаемой службы
#$Service = "FirebirdServerDefaultInstance"
$SearchServiceName = "FirebirdServerFIB2_5_MD"
Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Ищем службу $SearchServiceName" -Append 

try {
#Будем проверять статус службы 3 раза, каждый раз увеличивая тамймер ожидания
for($i=[int]1;$i -le 3;$i++) { 
    
  Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Итерация № $i" -Append

  $Srv = ServiceCheck($SearchServiceName)
  $ServiceName = $Srv[0]
  #Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Нашли службу с именем $ServiceName" -Append
  $ServiceStatus = $Srv[1]
  #Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Статус службы $ServiceName - $ServiceStatus" -Append
  $Service =$Srv[2]

  #Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") А вот исама служба $Service" -Append

    #Проверка на запущенность службы
    if ($ServiceStatus -eq "Running") {
            #пишем в консоль
            Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") On $Server Service $ServiceName is in state $ServiceStatus" -Append
            #Формируем тело письма
            $bodyText = "On $Server Service $ServiceName is in state $ServiceStatus"
            #Запускаем функцию отправки письма
            Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Отправляем письмо с текстом $bodyText" -Append

            SendReport
            #Останавливаем цикл
            break

        }else{
            #Ждем 60c - вдруг еще стартует
            Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Ждем!" -Append
            Start-Sleep -seconds 20
            if ($i -ge 2){
                # На второй и последующихитерациях пробуем стартовать службу
                
                $Srv = ServiceCheck($SearchServiceName)
                $ServiceName = $Srv[0]
                #Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Нашли службу с именем $ServiceName" -Append
                $ServiceStatus = $Srv[1]
                #Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Статус службы $ServiceName - $ServiceStatus" -Append
                $Service =$Srv[2]
                Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Пытаемся запустить службу с именем $ServiceName" -Append
                Start-Service  $ServiceName -ErrorAction Stop
            }
            if ($i -eq 3){
            
                #На 3ей итерации проверяем еще разок состоянии службы

                    $Srv=ServiceCheck($SearchServiceName)
                    $ServiceName = $Srv[0]
                    $ServiceStatus = $Srv[1]
                    $Service =$Srv[2]
                    
                    #пишем в консоль
                    Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") On $Server Service $ServiceName is in state $ServiceStatus" -Append
                    #Формируем тело письма
                    $bodyText = "On $Server Service $ServiceName is in state $ServiceStatus"
                    #Отправляем окончательное состояние службы
                    Out-File $report -InputObject "$(get-date -UFormat "%d.%m.%Y %H:%M:%S") Отправляем окончательное состояние службы" -Append
                    SendReport

            }
            
        }
}

}catch [System.Exception] {
    Out-File $report -InputObject "Error: $_" -Append
}


