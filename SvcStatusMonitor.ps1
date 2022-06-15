# Запустите этот скрипт с привилегированными правами, $ExecutionContext.SessionState.LanguageMode должен быть FullLanguage, а не ConstrainedLanguage
# Version 3.0

$Host.UI.RawUI.WindowTitle="Монитор состояния работы служб"

$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$testadmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if ($testadmin -eq $false) 
{
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    exit $LASTEXITCODE
}

if ($ExecutionContext.SessionState.LanguageMode -eq 'ConstrainedLanguage')
{
    Write-Host "Запустите этот скрипт с привилегированными правами, $ExecutionContext.SessionState.LanguageMode должен быть FullLanguage, а не ConstrainedLanguage" -ForegroundColor Yellow
    Write-Host "Выход через 30 сек..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    Exit
}

Clear-Host

$EventSource = "ServiceStatus"
$EventIdError = "61513"
$EventIdNormal = "62513"

$RegKeyServers = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers"
$RegKeyStatus = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers\CurrentStatusofService"
$RegKeyServiceMode = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers\ServiceMode"
$RegKeyStatusParameter = "Status"
$RegKeyEndTimeParameter = "EndTime"
$RegKeySvcNames = "ServicesNamesList"

$ErrorStatus = "Stopped"
$NormalStatus = "Running"
$ServiceModeOn = "On"
$ServiceModeOff = "Off"

$EventSourceExist = Get-WmiObject -Class Win32_NTEventLOgFile | Where-Object {$_.Sources -like $EventSource}
if (!$EventSourceExist) 
{
	Write-Host "Регистрация источника событий $EventSource..."
	New-EventLog –LogName Application –Source $EventSource
} 
else 
{
	Write-Host "EventSource $EventSource существует"
}

if (-not (Test-Path $RegKeyServers))
{
    Write-Host "$RegKeyServers не существует" -ForegroundColor Red
    Exit # Выход при отсутствии ключа реестра
}

if (-not (Test-Path $RegKeyStatus))
{
    New-Item -Path $RegKeyStatus -Force | Out-Null
    Write-Host "Создание ключа $RegKeyStatus" # Создание ключа реестра при его отсутствии
}

if (-not (Test-Path $RegKeyServiceMode))
{
    New-Item -Path $RegKeyServiceMode -Force | Out-Null
    Write-Host "Создание ключа $RegKeyServiceMode" # Создание ключа реестра при его отсутствии
}

$ServicesList = (Get-ItemProperty -Path $RegKeyServers).$RegKeySvcNames -split ','
if (!$ServicesList)
{
    Write-Host "Отсутствует либо не задан строковый параметр $RegKeySvcNames в $RegKeyServers" -ForegroundColor Red
    Exit # Выход при отсутствии параметра реестра или его значений
}

# Поиск дубликатов в массиве имен служб

$SvcDuplicates = $ServicesList | Group | ? {$_.Count -gt 1}
if ($SvcDuplicates) 
{
    Write-Host "Дубликаты! Не верно задан строковый параметр $RegKeySvcNames в $RegKeyServers" -ForegroundColor Red; $ServicesList=$null
    Exit # Выход в случае обнаружения дубликатов среди имен служб
}

################################################### Проверка состояния режима обслуживания ######################################################################

$ServiceModeStatus = (Get-ItemProperty -Path $RegKeyServiceMode).$RegKeyStatusParameter
$EndOfServiceModeString = (Get-ItemProperty -Path $RegKeyServiceMode).$RegKeyEndTimeParameter
$AnyErrorStatus = (Get-ItemProperty -Path $RegKeyStatus | Where-Object {$_ -match $ErrorStatus})
if ($EndOfServiceModeString) # Если значение времени отключения режима обслужиания в реестре присутствует
{
    $EndOfServiceModeTime=[datetime]::parseexact($EndOfServiceModeString, 'MM.dd.yyyy HH:mm:ss', $null) # переводим строку в дату в соответствии с маской
    $CurrentTime = Get-Date
    if ($ServiceModeStatus -eq $ServiceModeOn -and $CurrentTime -lt $EndOfServiceModeTime -and !$AnyErrorStatus) # Если сервер в режиме обслуживания, время его окончания менее текущего и статус в реестре в норме
    {
        Write-Host "Сервер находится в режиме обслуживания. Мониторинг не производится" -ForegroundColor Red
        Exit # Выход, т.к. мониторинг не производится в режиме обслуживания    
    } elseif ($ServiceModeStatus -eq $ServiceModeOn -and $CurrentTime -lt $EndOfServiceModeTime -and $AnyErrorStatus) # Если сервер в режиме обслуживания, время его окончания менее текущего, но статус в реестре в ошибке
    {
        Write-Host "Сервер будет в режиме мониторинга до тех пор, пока все нужные службы не будут запущены" -ForegroundColor Yellow
    } else
    {
        Write-Host "Сервер находится в режиме мониторинга или переводится в режим мониторинга в данный момент." -ForegroundColor Yellow
        New-ItemProperty -Path $RegKeyServiceMode -Name $RegKeyStatusParameter -PropertyType 'String' -Value $ServiceModeOff -Force | Out-Null
    }
} else
{
    Write-Host "Сервер находится в режиме мониторинга" -ForegroundColor Yellow
}
#################################################################################################################################################################


# Обработка массива корректных значений
	
foreach ($ServiceName in $ServicesList) 
{
	$Service = get-service -Name $ServiceName -ErrorAction SilentlyContinue
    if (!$Service)
	{
		Write-Host "Отсутствует или не верно задан строковый параметр $RegKeySvcNames, служба $ServiceName не найдена"
        continue # Выход при отсутствии параметра либо не верном имени службы
	}
	$ServiceDisplayName = $Service.DisplayName.ToString()
	$ServiceStatus = $Service.Status.ToString()
	$Status = (Get-ItemProperty -Path $RegKeyStatus).$ServiceName
	
	if ($ServiceStatus -eq $ErrorStatus) # Если служба остановлена
	{
		Write-Host "Трижды пытаемся запустить службу $ServiceDisplayName"
		#TODO: Остановка службы перед запуском, kill по PID
		
		$n = 1 # Номер попытки запуска
		do 
		{
			Write-Host "Попытка старта службы $n"
			$Service.Start()
			$Service.WaitForStatus($NormalStatus,'00:00:20') # Ожидание статуса "Running", таймаут 20 сек
			$ServiceStatus = (get-service -Name $ServiceName -ErrorAction SilentlyContinue).Status.ToString() # Проверка статуса после попытки запуска
			Write-Host "$ServiceDisplayName в состоянии $ServiceStatus" -ForegroundColor Yellow
			$n++
		} 
		until ( $n -eq 4 -or $ServiceStatus -eq $NormalStatus)
		
		if (!$Status -or $Status -eq $NormalStatus) # И статус в реестре отсутствует или в состоянии Running
		{			
			if ($ServiceStatus -ne $NormalStatus) # Если службу трижды не удалось запустить 
			{
				Write-Host "Записываем событие в журнал! На сервере $env:COMPUTERNAME служба $ServiceDisplayName ($ServiceName) в состоянии $ServiceStatus" -ForegroundColor Red
				Write-EventLog –LogName Application –Source $EventSource –EntryType Error –EventID $EventIdError –Message "На сервере $env:COMPUTERNAME служба $ServiceDisplayName ($ServiceName) в состоянии $ServiceStatus" # Запись в журнал
				New-ItemProperty -Path $RegKeyStatus -Name $ServiceName -PropertyType 'String' -Value $ErrorStatus -Force | Out-Null # Изменение статуса в реестре с Running на Stopped
			} else # Служба принудительно запущена
			{ 
				Write-Host "Не записываем событие в журнал! Служба $ServiceDisplayName ($ServiceName) принудительно успешно запущена и в состоянии $ServiceStatus" -ForegroundColor Green
			}
		}	
		else # Статус в состоянии Stopped
		{
			Write-Host "Не записываем событие в журнал! На сервере $env:COMPUTERNAME служба $ServiceDisplayName ($ServiceName) в состоянии $ServiceStatus" -ForegroundColor Red
		}
	} 	
	
	if ($ServiceStatus -eq $NormalStatus)# Если служба запущена		
	{
		if ($Status -eq $ErrorStatus) # И статус в реестре в состоянии Stopped
		{
            New-ItemProperty -Path $RegKeyStatus -Name $ServiceName -PropertyType 'String' -Value $NormalStatus -Force | Out-Null # Изменение статуса в реестре с Stopped на Running
            $AnyErrorStatus = Get-ItemProperty -Path $RegKeyStatus | Where-Object {$_ -match $ErrorStatus}
			if (!$AnyErrorStatus)
            {
                Write-Host "Записываем событие в журнал! На сервере $env:COMPUTERNAME служба $ServiceDisplayName ($ServiceName) в состоянии $ServiceStatus" -ForegroundColor Green
				Write-EventLog –LogName Application –Source $EventSource –EntryType Information –EventID $EventIdNormal –Message "На сервере $env:COMPUTERNAME служба $ServiceDisplayName ($ServiceName) в состоянии $ServiceStatus" # Запись в журнал
			} else
            {
                Write-Host "Не записываем событие в журнал! Есть другие не запущенные службы" 
            }
		} 
		else # Статус в состоянии Running
		{
			Write-Host "Не записываем событие в журнал! На сервере $env:COMPUTERNAME служба $ServiceDisplayName ($ServiceName) в состоянии $ServiceStatus" -ForegroundColor Green
		}
    }
}