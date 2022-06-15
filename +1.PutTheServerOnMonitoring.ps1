# Запустите этот скрипт с привилегированными правами, $ExecutionContext.SessionState.LanguageMode должен быть FullLanguage, а не ConstrainedLanguage
# Version 3.0

$Host.UI.RawUI.WindowTitle="Постановка сервера на мониторинг"

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


$RegKeyServers = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers"
$RegKeyMonitoredServices = "HKLM:\SOFTWARE\METINVEST\MonitoredServices"
$TaskScriptRoot = "C:\Monitoring\"
if (-not (Test-Path $TaskScriptRoot))
{
    Write-Host "Отсутствует путь $TaskScriptRoot" -ForegroundColor Yellow
    Write-Host "Выход через 30 сек..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    Exit  # Выход при отсутствии пути к файлам скриптов через 30 сек
}

$TaskScriptFiles = (Get-ChildItem *.ps1 -Path $TaskScriptRoot) | ForEach-Object {$_.FullName}
if (!$TaskScriptFiles) 
{
    Write-Host "Отсутствуют файлы скриптов в $TaskScriptRoot" -ForegroundColor Yellow
    Write-Host "Выход через 30 сек..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    Exit # Выход при отсутствии файлов скриптов через 30 сек
}

if (-not (Test-Path $RegKeyServers))
{
    New-Item -Path $RegKeyServers -Force | Out-Null
    Write-Host "Создание ключа $RegKeyServers" -ForegroundColor Green # Создание ключа реестра при его отсутствии
}
if (-not (Test-Path $RegKeyMonitoredServices))
{
    New-Item -Path $RegKeyMonitoredServices -Force | Out-Null
    New-ItemProperty -Path $RegKeyMonitoredServices -Name 'Performance_Data_Counter' -PropertyType 'Dword' -Value '1' -Force | Out-Null
    Write-Host "Создание ключа $RegKeyMonitoredServices" -ForegroundColor Green # Создание ключа реестра при его отсутствии
}

foreach ($TaskScriptFile in $TaskScriptFiles)
{
    # Формирование имени задачи в зависимости от имени файла скрипта
    if ($TaskScriptFile -like "*FreeDiskSpace*") {$TaskName = "MonitorFreeDiskSpace"}
    elseif ($TaskScriptFile -like "*CpuLoad*") {$TaskName = "MonitorCpuLoad"}
    elseif ($TaskScriptFile -like "*FreeRam*") {$TaskName = "MonitorFreeRam"}
    elseif ($TaskScriptFile -like "*SvcStatus*") {$TaskName = "MonitorSvcStatus"}
    elseif ($TaskScriptFile -like "*DiskQueue*") {$TaskName = "MonitorDiskQueue"}
    else {continue} # Переход к следующему скрипту, если имя скрипта не совпадает поддерживаемыми с масками 

    # Запроос подтверждения
    while( -not ( ($choice= (Read-Host "Добавить задачу мониторинга '$TaskName' ?")) -match "y|n")){ "Y или N?"} 
    if ($choice -eq 'n') 
    {
        Write-Host "Задача $TaskName не добавлена" -ForegroundColor Red; 
        continue # Переход к следующему скрипту при отрицательном ответе
    } 

    # Добавление пороговых значений или имен служб для мониторинга
    if ($TaskName -like "*FreeDiskSpace*") 
    {
        Do 
		{
           $InputError = $false
           $InputErrorValue = $false # Переменная для записи ошибки, не перезаписывается в цикле проверки, определяет хотя бы одну не верную запись 
           $MinimumValueOfFreeDiskSpaceMB = Read-Host "Введите буквы дисков и пороговые значения для них в MB через запятую без пробелов, например: 'c,1024,d,4096'" 
           $MeasureArray = $MinimumValueOfFreeDiskSpaceMB -split ','
		   
		    # Проверка каждого элемента массива на соответствие условиям

			for ($i=0;$i -lt $MeasureArray.count;$i+=2)
			{
				$CheckValueDisk = $MeasureArray[$i] -match '^[a-zA-Z]{1}$'
				$CheckValueMin = $MeasureArray[$i+1] -match '^[\d\.\,]+$'
				if ($CheckValueDisk -eq $false -or $CheckValueMin -eq $false)
				{
					$InputErrorValue = $true # Запись ошибки ввода при несоответствии условиям хотя бы одного из элементов массива
				}
				$DiskLetters += $MeasureArray[$i] -split '`n' # Формирование массива значений дисков для проверки наличия дубликатов
			}

			# Поиск дубликатов в массиве значений дисков

			$DiskDuplicates = $DiskLetters | Group | ? {$_.Count -gt 1}

			if (!$MeasureArray -or $MeasureArray.count%2 -gt 0 -or $CheckValueDisk -eq $false -or $CheckValueMin -eq $false -or $DiskDuplicates -or $InputErrorValue -eq $true) 
			{
				$InputError = $true
				Write-Host "Некорректный ввод!" -ForegroundColor Magenta
				$DiskLetters = $null
				$DiskDuplicates = $null
			} 
			else 
			{
				$InputError = $false
				$InputErrorValue = $false
				#Write-Host "Ошибок ввода нет"
				$DiskLetters = $null
				$DiskDuplicates = $null
			}
        } While ($InputError)
		   
        New-ItemProperty -Path $RegKeyServers -Name 'MinimumValueOfFreeDiskSpaceMB' -PropertyType 'String' -Value $MinimumValueOfFreeDiskSpaceMB -Force | Out-Null
    }
	
    if ($TaskName -like "*CpuLoad*") 
    {
         Do 
		 {
            $InputError = $false 
            $MaximumCPULoadPercentage = Read-Host "Введите пороговое значение загрузки ЦП (максимальный процент загрузки, например: '95')"
            $CheckMaxValue = $MaximumCPULoadPercentage -match '^[\d]+$'                       
            if (!$MaximumCPULoadPercentage -or $CheckMaxValue -eq $false) 
            {
                $InputError = $true
                Write-Host "Некорректный ввод!" -ForegroundColor Magenta
            } 
			else 
			{
				$InputError = $false
				#Write-Host "Ошибок ввода нет"
			}
         } While ($InputError)
			
        New-ItemProperty -Path $RegKeyServers -Name 'MaximumCPULoadPercentage' -PropertyType 'String' -Value $MaximumCPULoadPercentage -Force | Out-Null
    }
	
    if ($TaskName -like "*FreeRam*") 
    {
         Do 
		 { 
            $InputError = $false
            $MinimumValueOfFreeMemoryMB = Read-Host "Введите пороговое значение свободной памяти RAM в MB, например: '512'"
            $CheckMinValue = $MinimumValueOfFreeMemoryMB -match '^[\d]+$'                       
            if (!$MinimumValueOfFreeMemoryMB -or $CheckMinValue -eq $false)                         
            {
                $InputError = $true
                Write-Host "Некорректный ввод!" -ForegroundColor Magenta
            } 
			else 
			{
				$InputError = $false
				#Write-Host "Ошибок ввода нет"
			}
        } While ($InputError)
		
        New-ItemProperty -Path $RegKeyServers -Name 'MinimumValueOfFreeMemoryMB' -PropertyType 'String' -Value $MinimumValueOfFreeMemoryMB -Force | Out-Null
    }
	
    if ($TaskName -like "*SvcStatus*") 
    {
        Do 
		{
		   $InputError = $false
		   $ServicesNamesList = Read-Host "Введите имена служб через запятую без пробелов, например: 'CcmExec,wuauserv,CmRcService'"
		   $ServicesList = $ServicesNamesList -split ','
		   
		   
		   # Поиск дубликатов в массиве имен служб

		   $SvcDuplicates = $ServicesList | Group | ? {$_.Count -gt 1}

			if (!$ServicesNamesList -or $SvcDuplicates) 
			{
				$InputError = $true
				Write-Host "Некорректный ввод!" -ForegroundColor Magenta
				$SvcDuplicates = $null
			} 
			else 
			{
				$InputError = $false
				#Write-Host "Ошибок ввода нет"
				$SvcDuplicates = $null
			}
        } While ($InputError)
		
        New-ItemProperty -Path $RegKeyServers -Name 'ServicesNamesList' -PropertyType 'String' -Value $ServicesNamesList -Force | Out-Null
    }
	
    if ($TaskName -like "*DiskQueue*") 
    {
         Do 
		 { 
            $InputError = $false
            $MaximumAvgDiskQueueLength = Read-Host "Введите пороговое значение средней длины очереди диска, не обязательно целое число, например: '0.05'"
            $MaxValueStrArr = $MaximumAvgDiskQueueLength -split '' # Формирование массива из строки для определения повторяющихся разделителей
            $DotDuplicates = $MaxValueStrArr | Group | Where-Object {$_.Name -eq '.'} | ? {$_.Count -gt 1} 
            $CommaDuplicates = $MaxValueStrArr | Group | Where-Object {$_.Name -eq ','} | ? {$_.Count -gt 1}
            $CheckDotandComma = ($MaxValueStrArr -contains '.') -and ($MaxValueStrArr -contains ',')
            $CheckMaxValueStr = $MaximumAvgDiskQueueLength -match '^[\d\.\,]+$'                                               
    
            if (!$MaximumAvgDiskQueueLength -or $CheckMaxValueStr -eq $false -or $DotDuplicates -or $CommaDuplicates -or $CheckDotandComma)                         
            {
                $InputError = $true
                Write-Host "Некорректный ввод!" -ForegroundColor Magenta
            } 
			else 
			{
				$InputError = $false
				#Write-Host "Ошибок ввода нет"
			}
         } While ($InputError)
		 
        New-ItemProperty -Path $RegKeyServers -Name 'MaximumAvgDiskQueueLength' -PropertyType 'String' -Value $MaximumAvgDiskQueueLength -Force | Out-Null
    }

    # Создание и регистрация задачи
    $TaskCommand = "powershell.exe"
    $TaskArg = "-WindowStyle Hidden -Executionpolicy Unrestricted -file $TaskScriptFile"
    $Time = (get-date).AddMinutes(1)
    $service = new-object -ComObject("Schedule.Service")
    $service.Connect()
    $rootFolder = $service.GetFolder("\")
    $TaskDefinition = $service.NewTask(0)
    $TaskDefinition.Principal.RunLevel = "1"
    $TaskDefinition.Settings.Enabled = $true
    $TaskDefinition.Settings.AllowDemandStart = $true
    $triggers = $TaskDefinition.Triggers
    $trigger = $triggers.Create(1)
    $trigger.StartBoundary = $Time.ToString("yyyy-MM-dd'T'HH:mm:ss")
    $trigger.Repetition.Interval = "PT15M"
    $trigger.Enabled = $true
    $Action = $TaskDefinition.Actions.Create(0)
    $action.Path = "$TaskCommand"
    $action.Arguments = "$TaskArg"
    $rootFolder.RegisterTaskDefinition("$TaskName",$TaskDefinition,6,"System",$null,5) | out-null

    # Проверка наличия задачи
    $CheckTask = schtasks.exe /query /tn $TaskName
    if (!$CheckTask) 
    {
        Write-Host "Задача $TaskName не добавлена" -ForegroundColor Red
    } 
    else 
    {
        Write-Host "Задача $TaskName добавлена" -ForegroundColor Green
    }

}
