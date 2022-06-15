# Запустите этот скрипт с привилегированными правами, $ExecutionContext.SessionState.LanguageMode должен быть FullLanguage, а не ConstrainedLanguage
# Version 3.0

$Host.UI.RawUI.WindowTitle="Монитор загрузки CPU"

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

Function Get-PerformanceCounterLocalName
{
  param
  (
    [UInt32]
    $ID,
 
    $ComputerName = $env:COMPUTERNAME
  )
 
  $code = '[DllImport("pdh.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern UInt32 PdhLookupPerfNameByIndex(string szMachineName, uint dwNameIndex, System.Text.StringBuilder szNameBuffer, ref uint pcchNameBufferSize);'
 
  $Buffer = New-Object System.Text.StringBuilder(1024)
  [UInt32]$BufferSize = $Buffer.Capacity
 
  $t = Add-Type -MemberDefinition $code -PassThru -Name PerfCounter -Namespace Utility
  $rv = $t::PdhLookupPerfNameByIndex($ComputerName, $id, $Buffer, [Ref]$BufferSize)
 
  if ($rv -eq 0)
  {
    $Buffer.ToString().Substring(0, $BufferSize-1)
  }
  else
  {
    Throw 'Get-PerformanceCounterLocalName : Unable to retrieve localized name. Check computer name and performance counter ID.'
  }
}

################################ Топ процессов, занимающих ресурсы #############################################

Function GetTopProcesses
(
    [Parameter(Mandatory=$true)]
    [ValidateSet('CPU (%)','Disk (B/s)','Memory (MB)')]
    [string[]]
    $SortBy
)

{
    $NumberOfLogicalProcessors = (Get-WmiObject Win32_Processor).NumberOfLogicalProcessors
    $properties=@(
        @{Name="Name"; Expression = {$_.name}},
        @{Name="PID"; Expression = {$_.IDProcess}},
        @{Name="CPU (%)"; Expression = {($_.PercentProcessorTime/$NumberOfLogicalProcessors)}},
        @{Name="Memory (MB)"; Expression = {[Math]::Round(($_.workingSetPrivate / 1mb),2)}}
        @{Name="Disk (B/s)"; Expression = {$_.IODataBytesPersec}}
        )

    $TopProcesses = Get-WmiObject -class Win32_PerfFormattedData_PerfProc_Process |
                    Select-Object $properties |
                    Where-Object {$_.Name -notmatch "^(idle|_total)$"} |
                    Sort-Object $SortBy -desc |
                    Select-Object -First 5

    $TopProcesses | select *,@{Name="Path";Expression = {(Get-Process -Id $_.PID).Path}} | Format-Table -AutoSize 
}
################################################################################################################

Clear-Host
$NumberOfSamples = 3 # количество сэмплов
$SleepInterval = 240 # 240 или 4 минуты
$SampleInterval = 60 # 60 или 1 минута

$EventSource = "CPULoad"
$EventIdWarning = "61511"
$EventIdNormal = "62511"

$RegKeyServers = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers"
$RegKeyStatus = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers\CurrentStatusofCpuLoad"
$RegKeyServiceMode = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers\ServiceMode"
$RegKeyStatusParameter = "Status"
$RegKeyEndTimeParameter = "EndTime"
$RegKeyThreshold = "MaximumCPULoadPercentage"

$WarningStatus = "Warning"
$NormalStatus = "Normal"
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

$Status = (Get-ItemProperty -Path $RegKeyStatus).$RegKeyStatusParameter
$MaxValue = (Get-ItemProperty -Path $RegKeyServers).$RegKeyThreshold
$CheckMaxValue = $MaxValue -match '^[\d]+$'                       
if (!$MaxValue -or !$CheckMaxValue) 
{
    Write-Host "Отсутствует либо не верно задан строковый параметр $RegKeyThreshold в $RegKeyServers" -ForegroundColor Red
    Exit # Выход при отсутствии параметра реестра или отсутствии его значения
}

$Processor = Get-PerformanceCounterLocalName 238            # Идентификатор счетчика в системном реестре 
$PercentProcessorTime = Get-PerformanceCounterLocalName 6   # Идентификатор счетчика в системном реестре 
$CpuCounter = "\$processor(_total)\$percentProcessorTime"
$CpuValues = @()
for($i = 0; $i -lt $NumberOfSamples; $i++)
{
    $CpuValue = ([decimal]::round(((Get-Counter $CpuCounter -SampleInterval $SampleInterval).CounterSamples).cookedvalue)).tostring() 
    $CpuValues += $CpuValue
    Write-Host "Загрузка ЦП составляет $CpuValue%"
    if ($i -lt ($NumberOfSamples-1)) 
    {
        Start-Sleep $SleepInterval
    }
}

$CpuValuegtMaxValue = ([int]($CpuValues[0]) -gt [int]$MaxValue)
if ($CpuValuegtMaxValue) 
{
    for($i = 1; $i -lt $CpuValues.Count; $i++)
    {
        if ([int]($CpuValues[$i]) -lt [int]$MaxValue)
        {
            $CpuValuegtMaxValue = $false  
            Break
        }
    }
}

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
        Write-Host "Сервер будет в режиме мониторинга до тех пор, пока не снизится загрузка ЦП" -ForegroundColor Yellow
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

if ($CpuValuegtMaxValue) 
{
    if (!$Status -or $Status -eq $NormalStatus)
    {
        $AverageCPULoad = ([decimal]::Round(($CpuValues | Measure-Object -Average).Average)).tostring()
        $Time = ($SampleInterval+$SleepInterval)*$NumberOfSamples/60
        Write-Host "Записываем событие в журнал! Превышен порог загрузки ЦП в $MaxValue% на сервере $env:COMPUTERNAME. Средняя загрузка процессора за последние $Time минут(ы) составила $AverageCPULoad%" -ForegroundColor Red
        $TopProcesses = GetTopProcesses -SortBy 'CPU (%)' | Out-String -Width 200
        Write-EventLog –LogName Application –Source $EventSource –EntryType Warning –EventID $EventIdWarning –Message "Превышен порог загрузки ЦП в $MaxValue% на сервере $env:COMPUTERNAME. Средняя загрузка процессора за последние $Time минут(ы) составила $AverageCPULoad%. $TopProcesses" # Запись в журнал
        New-ItemProperty -Path $RegKeyStatus -Name $RegKeyStatusParameter -PropertyType 'String' -Value $WarningStatus -Force | Out-Null # Изменение статуса в реестре с Normal на Warning
    } else 
    {
        Write-Host "Не записываем событие в журнал! Превышен порог загрузки ЦП в $MaxValue% на сервере $env:COMPUTERNAME. Средняя загрузка процессора за последние $Time минут(ы) составила $AverageCPULoad%" -ForegroundColor Red
    }
} else
{
    if ($Status -eq $WarningStatus)
        {
            Write-Host "Записываем событие в журнал! Загрузка ЦП в норме, менее $MaxValue%" -ForegroundColor Green
            Write-EventLog –LogName Application –Source $EventSource –EntryType Information –EventID $EventIdNormal –Message "Загрузка ЦП в норме, менее $MaxValue%" # Запись в журнал
            New-ItemProperty -Path $RegKeyStatus -Name $RegKeyStatusParameter -PropertyType 'String' -Value $NormalStatus -Force | Out-Null # Изменение статуса в реестре с Warning на Normal    
        } else
        {
            Write-Host "Не записываем событие в журнал! Загрузка ЦП в норме, менее $MaxValue%" -ForegroundColor Green
        }
}