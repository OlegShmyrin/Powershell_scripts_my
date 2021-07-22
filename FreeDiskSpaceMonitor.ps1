# Запустите этот скрипт с привилегированными правами, $ExecutionContext.SessionState.LanguageMode должен быть FullLanguage, а не ConstrainedLanguage
# Version 3.0

$Host.UI.RawUI.WindowTitle="Монитор свободного места на дисках"

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

$EventSource = "FreeDiskSpace"
$EventIdWarning = "61510"
$EventIdNormal = "62510"

$RegKeyServers = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers"
$RegKeyStatus = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers\CurrentStatusofFreeDiskSpace"
$RegKeyServiceMode = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers\ServiceMode"
$RegKeyStatusParameter = "Status"
$RegKeyEndTimeParameter = "EndTime"
$RegKeyThreshold = "MinimumValueOfFreeDiskSpaceMB"

$WarningStatus = "Warning"
$NormalStatus = "Normal"
$ServiceModeOn = "On"
$ServiceModeOff = "Off"

$EventSourceExist = Get-WmiObject -Class Win32_NTEventLOgFile | Where-Object {$_.Sources -like $EventSource}
if (!$EventSourceExist) 
{
    Write-Host "Регистрация источника событий $EventSource..."
    New-EventLog –LogName Application –Source $EventSource  # Регистрация источника событий в случае его отсутствия
} 
else 
{
	Write-Host "Источник событий $EventSource существует"
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

$MeasureArray = (Get-ItemProperty -Path $RegKeyServers).$RegKeyThreshold -split ',' # Формирование массива элементов из параметра реестра
if (!$MeasureArray -or $MeasureArray.count%2 -gt 0)
{
    Write-Host "Отсутствует либо не верно задан строковый параметр $RegKeyThreshold в $RegKeyServers" -ForegroundColor Red
    Exit # Выход при отсутствии параметра реестра, отсутствии значений в нем либо их нечетном количестве
}

# Проверка каждого элемента массива на соответствие условиям

for ($i=0;$i -lt $MeasureArray.count;$i+=2) 
{
    $CheckValueDisk = $MeasureArray[$i] -match '^[a-zA-Z]{1}$'
    if ($CheckValueDisk -eq $false)
    {
        Write-Host "Не верно задан строковый параметр $RegKeyThreshold в $RegKeyServers" -ForegroundColor Red
        Exit # Выход при несоответствии условию хотя бы одного элемента массива
    }     
  
    $CheckValueMin = $MeasureArray[$i+1] -match '^[\d\.\,]+$'
    if ($CheckValueMin -eq $false)
    {
        Write-Host "Не верно задан строковый параметр $RegKeyThreshold в $RegKeyServers" -ForegroundColor Red
        Exit # Выход при несоответствии условию хотя бы одного элемента массива
    }

    $DiskLetters += $MeasureArray[$i] -split '`n' # Формирование массива значений дисков для проверки наличия дубликатов
}

# Поиск дубликатов в массиве значений дисков

$DiskDuplicates = $DiskLetters | Group | ? {$_.Count -gt 1}
if ($DiskDuplicates) 
{
    Write-Host "Дубликаты! Не верно задан строковый параметр $RegKeyThreshold в $RegKeyServers" -ForegroundColor Red; $DiskLetters=$null
    Exit # Выход в случае обнаружения дубликатов среди букв дисков
}
$DiskLetters=$null

################################################### Проверка состояния режима обслуживания ######################################################################

$ServiceModeStatus = (Get-ItemProperty -Path $RegKeyServiceMode).$RegKeyStatusParameter
$EndOfServiceModeString = (Get-ItemProperty -Path $RegKeyServiceMode).$RegKeyEndTimeParameter
$AnyWarningStatus = (Get-ItemProperty -Path $RegKeyStatus | Where-Object {$_ -match $WarningStatus})
if ($EndOfServiceModeString) # Если значение времени отключения режима обслужиания в реестре присутствует
{
    $EndOfServiceModeTime=[datetime]::parseexact($EndOfServiceModeString, 'MM.dd.yyyy HH:mm:ss', $null) # переводим строку в дату в соответствии с маской
    $CurrentTime = Get-Date
    if ($ServiceModeStatus -eq $ServiceModeOn -and $CurrentTime -lt $EndOfServiceModeTime -and !$AnyWarningStatus) # Если сервер в режиме обслуживания, время его окончания менее текущего и статус в реестре в норме
    {
        Write-Host "Сервер находится в режиме обслуживания. Мониторинг не производится" -ForegroundColor Red
        Exit # Выход, т.к. мониторинг не производится в режиме обслуживания    
    } elseif ($ServiceModeStatus -eq $ServiceModeOn -and $CurrentTime -lt $EndOfServiceModeTime -and $AnyWarningStatus) # Если сервер в режиме обслуживания, время его окончания менее текущего, но статус в реестре в ошибке
    {
        Write-Host "Сервер будет в режиме мониторинга до тех пор, пока на всех дисках не будет достаточно места" -ForegroundColor Yellow
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

for ($i=0;$i -lt $MeasureArray.count;$i+=2) 
{
    $DiskLetter = $MeasureArray[$i]
    $MinValue = $MeasureArray[$i+1]
    $Status = (Get-ItemProperty -Path $RegKeyStatus).$DiskLetter
    $DeviceID = ($DiskLetter+':').ToUpper()
    $Disk = Get-WMIObject Win32_LogicalDisk —filter "DeviceID='$DeviceID'"

	    if ($Disk -and $Disk.DriveType -eq '3') # Если диск есть в системе и соответствует типу 3
		{
		    $FreeDiskSpace = ([decimal]::round($Disk.FreeSpace / 1MB)).tostring()
		    Write-Host "На диске $DeviceID свободно $FreeDiskSpace МБ"
                                                                                                                
			if ([int]$FreeDiskSpace -lt [int]$MinValue) # Если свободного места не достаточно
			{
			    if (!$Status -or $Status -eq $NormalStatus) # И статус диска в реестре отсутствует либо в стостоянии Normal
				{
				    Write-Host "Записываем событие в журнал! $WarningStatus! На диске $DeviceID сервера $env:COMPUTERNAME осталось менее $MinValue МБ свободного места ($FreeDiskSpace МБ)" -ForegroundColor Red
				    Write-EventLog –LogName Application –Source $EventSource –EntryType Warning –EventID $EventIdWarning –Message "$WarningStatus! На диске $DeviceID сервера $env:COMPUTERNAME осталось менее $MinValue МБ свободного места ($FreeDiskSpace МБ)" # Запись в журнал
				    New-ItemProperty -Path $RegKeyStatus -Name $DiskLetter -PropertyType 'String' -Value $WarningStatus -Force | Out-Null # Изменение статуса в реестре с Normal на Warning
				} else
				{
				    Write-Host "Не записываем событие в журнал! $WarningStatus! На диске $DeviceID сервера $env:COMPUTERNAME осталось менее $MinValue МБ свободного места ($FreeDiskSpace МБ)" -ForegroundColor Red
				}

			} else # Если свободного места достаточно
			{
				if ($Status -eq $WarningStatus) # И статус диска в реестре в стостоянии Warning
				{
                    New-ItemProperty -Path $RegKeyStatus -Name $DiskLetter -PropertyType 'String' -Value $NormalStatus -Force | Out-Null # Изменение статуса в реестре с Warning на Normal
					$AnyWarningStatus = Get-ItemProperty -Path $RegKeyStatus | Where-Object {$_ -match $WarningStatus}
                    if (!$AnyWarningStatus)
                    {
                        Write-Host "Записываем событие в журнал! $NormalStatus. На диске $DeviceID сервера $env:COMPUTERNAME достаточно свободного места ($FreeDiskSpace МБ)" -ForegroundColor Green
					    Write-EventLog –LogName Application –Source $EventSource –EntryType Information –EventID $EventIdNormal –Message "$NormalStatus. На диске $DeviceID сервера $env:COMPUTERNAME достаточно свободного места ($FreeDiskSpace МБ)" # Запись в журнал
					} else
                    {
                        Write-Host "Не записываем событие в журнал! Есть другие диски с недостатком места" 
                    }
				} else 
				{
					Write-Host "Не записываем событие в журнал! $NormalStatus. На диске $DeviceID сервера $env:COMPUTERNAME достаточно свободного места ($FreeDiskSpace МБ)" -ForegroundColor Green
				}
			}
		} else 
		{
			Write-Host "Диск $DeviceID отсутствует в системе" -ForegroundColor DarkRed
		}
}