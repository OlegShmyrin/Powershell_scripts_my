# Запустите этот скрипт с привилегированными правами, $ExecutionContext.SessionState.LanguageMode должен быть FullLanguage, а не ConstrainedLanguage
# Version 3.0

$Host.UI.RawUI.WindowTitle="Включение/Выключение режима обслуживания"

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

#################################################### Включение/Выключение режима обслуживания ###################################################
$ServiceModeOn = "On"
$ServiceModeOff = "Off"
$RegKeyServiceMode = "HKLM:\SOFTWARE\METINVEST\SCOM\Servers\ServiceMode"
$RegKeyStatusParameter = "Status"
$RegKeyEndTimeParameter = "EndTime"

if (-not (Test-Path $RegKeyServiceMode)) 
{
    New-Item -Path $RegKeyServiceMode -Force | Out-Null # Создание ключа реестра при его отсутствии
    Write-Host "Ключ реестра $RegKeyServiceMode добавлен" -ForegroundColor Green
}

Write-Host "1. Включить (Enable)" -ForegroundColor Green
Write-Host "2. Выключить (Disable)" -ForegroundColor Red

while( -not ( ($choice= (Read-Host "Выберите действие?")) -match "1|2"))
{
	Write-Host "1 или 2!" -ForegroundColor Magenta
} 
if ($choice -eq '2') 
{
    New-ItemProperty -Path $RegKeyServiceMode -Name $RegKeyStatusParameter -PropertyType 'String' -Value $ServiceModeOff -Force | Out-Null
    Write-Host "Режим обслуживания выключен. Сервер в режиме мониторинга. Выход через 30 сек..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    Exit # Выключение и выход через 30 сек
} 

Clear-Host

while( -not ( ($DurationOfServiceMode= (Read-Host "Введите продолжительность режима обслуживания (целое значение в минутах)")) -match '^[\d]+$'))
{
	Write-Host "Некорректный ввод, введите целое число!" -ForegroundColor Magenta
} 

New-ItemProperty -Path $RegKeyServiceMode -Name $RegKeyStatusParameter -PropertyType 'String' -Value $ServiceModeOn -Force | Out-Null
$CurrentTime = Get-Date
$EndOfServiceModeTime = $CurrentTime.AddMinutes($DurationOfServiceMode)
$EndOfServiceModeString = $EndOfServiceModeTime.ToString('MM.dd.yyyy HH:mm:ss')
if (!$EndOfServiceModeString) 
{
    Write-Host "Не удалось преобразовать дату. Режим обслуживания не включен. Выход через 30 сек..." -ForegroundColor Red
    New-ItemProperty -Path $RegKeyServiceMode -Name $RegKeyStatusParameter -PropertyType 'String' -Value $ServiceModeOff -Force | Out-Null
    Start-Sleep -Seconds 30
    Exit # Выход если не удалось преобразовать дату в строку для записи в реестр
}

New-ItemProperty -Path $RegKeyServiceMode -Name $RegKeyEndTimeParameter -PropertyType 'String' -Value $EndOfServiceModeString -Force | Out-Null
Write-Host "Режим обслуживания включен" -ForegroundColor Green
Write-Host "Мониторинг не будет производиться в течение $DurationOfServiceMode мин." -ForegroundColor Green
Write-Host "Время возврата в режим мониторинга - $EndOfServiceModeTime" -ForegroundColor Green
Write-Host "Выход через 30 сек..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
Exit
