# run this script with privileged rights, $ExecutionContext.SessionState.LanguageMode should be FullLanguage, not ConstrainedLanguage

Function GetProccessAndLog
{
    $properties=@(
        @{Name="Name"; Expression = {$_.name}},
        @{Name="PID"; Expression = {$_.IDProcess}},
        @{Name="CPU (%)"; Expression = {$_.PercentProcessorTime}},
        @{Name="Memory (MB)"; Expression = {[Math]::Round(($_.workingSetPrivate / 1mb),2)}}
        @{Name="Disk (B/s)"; Expression = {$_.IODataBytesPersec}}
        )

    $ProcessCPU = Get-WmiObject -class Win32_PerfFormattedData_PerfProc_Process |
                    Select-Object $properties |
                    Sort-Object "Memory (MB)" -desc |  # 
                    Select-Object -First 10

    $ProcessCPU | select *,@{Name="Path";Expression = {(Get-Process -Id $_.PID).Path}} | Format-Table -AutoSize 
}
##################################################################################################


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

Clear-Host

$NumberOfSamples = 3 # repeat 3 times
$SleepInterval = 240   # 240 или 4 минуты
$SampleInterval = 60  # 60 или 1 минута

$EventSource = "RamUsage"
$EventIdWarning = "61512"
$EventIdNormal = "62512"

$RegKeyServers = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers"
$RegKeyStatus = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers\CurrentStatusofFreeMemoryMB"
$RegKeyStatusParameter = "Status"
$RegKeyThreshold = "MinimumValueOfFreeMemoryMB"

$WarningStatus = "Warning"
$NormalStatus = "Normal"

$EventSourceExist = Get-WmiObject -Class Win32_NTEventLOgFile | Where-Object {$_.Sources -like $EventSource}
if (!$EventSourceExist) 
{
    Write-Host "Регистрация источника событий $EventSource..."
    New-EventLog –LogName Application –Source $EventSource
}  else {Write-Host "Источник событий $EventSource существует"}

if (-not (Test-Path $RegKeyServers))
{
    Write-Host "$RegKeyServers не существует" -ForegroundColor Red
    Exit #Выход при отсутствии ключа реестра
}

if (-not (Test-Path $RegKeyStatus))
{
    New-Item -Path $RegKeyStatus -Force | Out-Null
    Write-Host "Создание ключа $RegKeyStatus" #Создание ключа реестра при его отсутствии
}

$Status = (Get-ItemProperty -Path $RegKeyStatus).$RegKeyStatusParameter
$MinValue = (Get-ItemProperty -Path $RegKeyServers).$RegKeyThreshold
$CheckMinValue = $MinValue -match '^[\d]+$'                       
if (!$MinValue -or !$CheckMinValue) 
{
    Write-Host "Отсутствует либо не верно задан строковый параметр $RegKeyThreshold в $RegKeyServers" -ForegroundColor Red
    Exit #Выход при отсутствии параметра реестра или не верном его значении
}
        
$Ram = Get-PerformanceCounterLocalName 4       # counter's ID in system registry
$FreeMb = Get-PerformanceCounterLocalName 1824 # counter's ID in system registry
$RamCounter = "\$Ram\$FreeMb"
$TotalRamValue = ([decimal]::Round((Get-Ciminstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB, 1)).tostring()                 
$FreeRamValues = @()          

for($i = 0; $i -lt $NumberOfSamples; $i++)
{
    $FreeRamValue = ([decimal]::round(((Get-Counter $RamCounter -SampleInterval $SampleInterval).CounterSamples).cookedvalue)).tostring() 
    $FreeRamValues += $FreeRamValue
    $TopProcesses = GetProccessAndLog | Out-String -Width 200
    Write-Host "Свободно $FreeRamValue МБ из $TotalRamValue ГБ. $TopProcesses"
    if ($i -lt ($NumberOfSamples-1)) 
    {
        Start-Sleep $SleepInterval
    }
}

$FreeRamltMinValue = ([int]($FreeRamValues[0]) -lt [int]$MinValue)
if ($FreeRamltMinValue) 
{
    for($i = 1; $i -lt $FreeRamValues.Count; $i++)
    {
        if ([int]($FreeRamValues[$i]) -gt [int]$MinValue)
        {
            $FreeRamltMinValue = $false	
            Break
        }
    }
}

if ($FreeRamltMinValue) 
{
    if (!$Status -or $Status -eq $NormalStatus)
    {
        Write-Host "Записываем событие в журнал! На сервере $env:COMPUTERNAME превышен порог использования памяти! Свободно $FreeRamValue МБ RAM из $TotalRamValue ГБ" -ForegroundColor Red
        $TopProcesses = GetProccessAndLog | Out-String -Width 200
        Write-EventLog –LogName Application –Source $EventSource –EntryType Warning –EventID $EventIdWarning –Message "На сервере $env:COMPUTERNAME превышен порог использования памяти! Свободно $FreeRamValue МБ RAM из $TotalRamValue ГБ. $TopProcesses" 
        New-ItemProperty -Path $RegKeyStatus -Name $RegKeyStatusParameter -PropertyType 'String' -Value $WarningStatus -Force | Out-Null #Изменение статуса в реестре с Normal на Warning                                                                                                                             
    } else
        {
            Write-Host "Не записываем событие в журнал! На сервере $env:COMPUTERNAME превышен порог использования памяти! Свободно $FreeRamValue МБ RAM из $TotalRamValue ГБ" -ForegroundColor Red  
        }
} else
    {
        if ($Status -eq $WarningStatus)
        {
            Write-Host "Записываем событие в журнал! На сервСвободноере $env:COMPUTERNAME достаточно свободной памяти $FreeRamValue МБ RAM из $TotalRamValue ГБ" -ForegroundColor Green
            Write-EventLog –LogName Application –Source $EventSource –EntryType Information –EventID $EventIdNormal –Message "На сервере $env:COMPUTERNAME достаточно свободной памяти $FreeRamValue МБ RAM из $TotalRamValue ГБ"
            New-ItemProperty -Path $RegKeyStatus -Name $RegKeyStatusParameter -PropertyType 'String' -Value $NormalStatus -Force | Out-Null #Изменение статуса в реестре с Warning на Normal  
        } else
            {
                Write-Host "Не записываем событие в журнал! На сервере $env:COMPUTERNAME достаточно свободной памяти $FreeRamValue МБ RAM из $TotalRamValue ГБ" -ForegroundColor Green
            }   
    }                                                        