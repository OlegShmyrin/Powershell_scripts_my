[xml]$config = Get-Content -Path C:\Intel\standalone.xml

$Subsystems = $config.server.profile.subsystem.logger.level


foreach($log_level in $Subsystems)
{
    if($log_level.name -eq "debug"){
        #Пишем письмо или создаем Событие для генерации варнинга и заявки в сервис деске!!!
    }
}
