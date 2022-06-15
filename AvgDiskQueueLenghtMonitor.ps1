# Запустите этот скрипт с привилегированными правами, $ExecutionContext.SessionState.LanguageMode должен быть FullLanguage, а не ConstrainedLanguage
# Version 3.0

$Host.UI.RawUI.WindowTitle="Монитор средней очереди к дискам"

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

$EventSource = "DiskQueueLength"
$EventIdWarning = "61514"
$EventIdNormal = "62514"

$RegKeyServers = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers"
$RegKeyStatus = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers\CurrentStatusofDiskQueue"
$RegKeyServiceMode = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers\ServiceMode"
$RegKeyStatusParameter = "Status"
$RegKeyEndTimeParameter = "EndTime"
$RegKeyThreshold = "MaximumAvgDiskQueueLength"

$WarningStatus = "Warning"
$NormalStatus = "Normal"
$ServiceModeOn = "On"
$ServiceModeOff = "Off"

$EventSourceExist = Get-WmiObject -Class Win32_NTEventLOgFile | Where-Object {$_.Sources -like $EventSource}
if (!$EventSourceExist) 
{
    Write-Host "Регистрация источника событий $EventSource..."
    New-EventLog –LogName Application –Source $EventSource
}  else 
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
$MaxValueStr = (Get-ItemProperty -Path $RegKeyServers).$RegKeyThreshold

$MaxValueStrArr = $MaxValueStr -split '' # Формирование массива из строки для определения повторяющихся разделителей
$DotDuplicates = $MaxValueStrArr | Group | Where-Object {$_.Name -eq '.'} | ? {$_.Count -gt 1} 
$CommaDuplicates = $MaxValueStrArr | Group | Where-Object {$_.Name -eq ','} | ? {$_.Count -gt 1}
$CheckMaxValueStr = $MaxValueStr -match '^[\d\.\,]+$'                                               

if (!$MaxValueStr -or !$CheckMaxValueStr -or $DotDuplicates -or $CommaDuplicates) 
{
    Write-Host "Отсутствует либо не верно задан строковый параметр $RegKeyThreshold в $RegKeyServers" -ForegroundColor Red
    Exit # Выход при отсутствии параметра реестра или отсутствии его значения
}

$CultureEn = [cultureinfo]::GetCultureInfo('en-EN')
$CultureRu = [cultureinfo]::GetCultureInfo('ru-RU')

if ($MaxValueStr.Contains('.')) 
{
    $MaxValue=[decimal]::Parse($MaxValueStr, $CultureEn)
} elseif ($MaxValueStr.Contains(',')) 
{
    $MaxValue=[decimal]::Parse($MaxValueStr, $CultureRu)
} else 
{
    $MaxValue=[decimal]::Parse($MaxValueStr, (Get-Culture)) # Преобразование строки в десятичное число
}

$PhysicalDisk = Get-PerformanceCounterLocalName 234        # Идентификатор счетчика в системном реестре 
$AvgDiskQueueLength = Get-PerformanceCounterLocalName 1400 # Идентификатор счетчика в системном реестре , для CurrentDiskQueueLength - 198
$AvgDiskQueueLengthCounter = "\$PhysicalDisk(_total)\$AvgDiskQueueLength"                

$AvgDiskQueueLengthValues = @()          

for($i = 0; $i -lt $NumberOfSamples; $i++)
{
    $AvgDiskQueueLengthValueStr = ([decimal]::round(((Get-Counter $AvgDiskQueueLengthCounter -SampleInterval $SampleInterval).CounterSamples).cookedvalue, 2)).tostring() 
    $AvgDiskQueueLengthValue=[decimal]::Parse($AvgDiskQueueLengthValueStr, (Get-Culture)) # Преобразование строки в десятичное число
    $AvgDiskQueueLengthValues += $AvgDiskQueueLengthValue
    Write-Host "Средняя длина очереди диска равна $AvgDiskQueueLengthValue (максимум $MaxValue)"
    if ($i -lt ($NumberOfSamples-1)) 
    {
        Start-Sleep $SleepInterval
    }
}

######################### Проверка запущенного процесса резервного копирования и увеличение порога при его наличии  #########################
                $ProcessNames = "wbengine", "any_other_process"
                Foreach ($ProcessName in $ProcessNames)
                {
                    $Process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
                    if (!$Process) 
                    {
                        Write-Host "$ProcessName не запущен, порог без изменений - $MaxValue" -ForegroundColor Green
                    }
                    else
                    {
                        $MaxValue = $MaxValue*3   
                        Write-Host "$ProcessName запущен, порог изменен - $MaxValue" -ForegroundColor Yellow
                    }
                }
#############################################################################################################################################


$AvgDiskQueueLengthgtMaxValue = (($AvgDiskQueueLengthValues[0]) -gt $MaxValue)
if ($AvgDiskQueueLengthgtMaxValue) 
{
    for($i = 1; $i -lt $AvgDiskQueueLengthValues.Count; $i++)
    {
        if (($AvgDiskQueueLengthValues[$i]) -lt $MaxValue)
        {
            $AvgDiskQueueLengthgtMaxValue = $false
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
        Write-Host "Сервер будет в режиме мониторинга до тех пор, пока не снизится нагрузка на диск" -ForegroundColor Yellow
    } else
    {
        Write-Host "Сервер находится в режиме мониторинга или переводится в режим мониторинга в данный момент" -ForegroundColor Yellow
        New-ItemProperty -Path $RegKeyServiceMode -Name $RegKeyStatusParameter -PropertyType 'String' -Value $ServiceModeOff -Force | Out-Null
    }
} else
{
    Write-Host "Сервер находится в режиме мониторинга" -ForegroundColor Yellow
}
#################################################################################################################################################################

if ($AvgDiskQueueLengthgtMaxValue) 
{
    if (!$Status -or $Status -eq $NormalStatus)
    {
        Write-Host "Записываем событие в журнал! На сервере $env:COMPUTERNAME превышен порог ($MaxValue) средней очереди длины диска - $AvgDiskQueueLengthValue" -ForegroundColor Red
        $TopProcesses = GetTopProcesses -SortBy 'Disk (B/s)' | Out-String -Width 200
        Write-EventLog –LogName Application –Source $EventSource –EntryType Warning –EventID $EventIdWarning –Message "На сервере $env:COMPUTERNAME превышен порог ($MaxValueStr) средней очереди длины диска - $AvgDiskQueueLengthValueStr. $TopProcesses"
        New-ItemProperty -Path $RegKeyStatus -Name $RegKeyStatusParameter -PropertyType 'String' -Value $WarningStatus -Force | Out-Null # Изменение статуса в реестре с Normal на Warning
    } else 
    {
        Write-Host "Не записываем событие в журнал! На сервере $env:COMPUTERNAME превышен порог ($MaxValue) средней очереди длины диска - $AvgDiskQueueLengthValue" -ForegroundColor Red
    }
} else 
{
    if ($Status -eq $WarningStatus)
        {
            Write-Host "Записываем событие в журнал! Средняя очередь длины диска в норме (менее $MaxValue)" -ForegroundColor Green
            Write-EventLog –LogName Application –Source $EventSource –EntryType Information –EventID $EventIdNormal –Message "Средняя очередь длины диска в норме (менее $MaxValueStr)"
            New-ItemProperty -Path $RegKeyStatus -Name $RegKeyStatusParameter -PropertyType 'String' -Value $NormalStatus -Force | Out-Null # Изменение статуса в реестре с Warning на Normal    
        } else
        {
            Write-Host "Не записываем событие в журнал! Средняя очередь длины диска в норме (менее $MaxValue)" -ForegroundColor Green
        }
}