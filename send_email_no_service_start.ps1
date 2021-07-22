 Function SendReport
{
#Пишем в консоль
    #От кого отправляем
    $EmailFrom = "ServerStausReports@metinvestholding.com"
    #Кому. Через запятую можно несколько
    $EmailTo = "oleg.shmyrin@metinvestholding.com"
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
 
 Start-Sleep -seconds 90

#Получаем имя сервера
$Server = Hostname
#Задаем имя отслеживаемой службы
#$Service = "FirebirdServerDefaultInstance"
$SearchServiceName = "Themes"

  #Получаем сулжбу по имени и ее первоначальный статус
    $Service =  Get-Service -ComputerName $Server -Include $SearchServiceName 

    #Выдергиваем из сущности службы Имя
    $ServiceName = $Service.Name.ToString()
    $ServiceName
    #Выдергиваем из сущности службы Статус службы
    $ServiceStatus = $Service.Status.ToString()
    $ServiceStatus
    $bodyText = "$Server загрузился. Service $ServiceName is in state $ServiceStatus"

    SendReport



