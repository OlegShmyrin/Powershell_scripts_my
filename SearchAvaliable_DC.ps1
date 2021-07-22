
Import-Module ActiveDirectory
Clear

$CerDomController = "metinvest.ua" # Используемый котроллер домена

# Домены
$AZSdomain = "corp.azovstal.ua"
$MIHdomain = "metinvest.ua"
$NeedDomain = $MIHdomain # Нужный домен.


Write-host "Проверка связи с " -NoNewline
Write-Host -ForegroundColor Cyan $CerDomController
"
"
$StatusArray = @()
$StatusOf = $null
$checkC = 10 # Количество проверок "пингов"
$Mn = $checkC + 1
$PackSize = 1450
$TimeLen = 4
$CerDomController | ForEach-Object {
    $CurDomainController = $_
    Write-Host ''
    While ($Mn -gt 1) {
        $Mn = $Mn - 1
        Try {
            test-connection $CurDomainController -Count 1 -BufferSize $PackSize -ErrorAction Stop | ForEach-Object {
                $IP4 = ($_.IPV4Address).IPAddressToString
                $Time = $_.ResponseTime
                $TimeSTR = $Time.ToString()
                If ($TimeSTR.Length -lt $TimeLen) {
                    While ($TimeSTR.Length -lt $TimeLen) {$TimeSTR = ' ' + $TimeSTR}
                }
                Write-Host "$Mn Проверка связи с " -NoNewline
                Write-Host -ForegroundColor Cyan $CurDomainController -NoNewline
                Write-Host " IP - ($IP4) " -NoNewline
                Write-Host -ForegroundColor Green $TimeSTR -NoNewline
                Write-Host ' ms ' -NoNewline
                $StatusArray += $TimeSTR
                ''
                }
            }
        Catch {
            Try {
                $CurDomainController | Resolve-DNSName -ErrorAction Stop | ForEach-Object {
                    $type = $_.Type;$ipV4 = $_.IPAddress
                    If ($type -eq 'A'){$ipV4 = $_.IPAddress}
                    ElseIf ($type -eq 'AAAA'){$ipV6 = $_.IPAddress}
                }
            }
            Catch {
                $ipV4 = '---.---.---.---'
                $ipV6 = '----:----:----:----:----:----:----:----'
            }
            Write-Host "$Mn Проверка связи с " -NoNewline
            Write-Host -ForegroundColor Cyan $CurDomainController -NoNewline
            Write-Host " IP - ($ipV4) " -NoNewline
            Write-Host -ForegroundColor Red 'Offline ' -NoNewline;
            $TimeSTR = 9999
            $StatusArray += $TimeSTR
            ''
        }
    Wait-Event -Timeout 1
    }
}
$l = 0
$StatusArray | ForEach-Object {
    $curval = $_
    $l = $l + $curval
}
IF ($l/$checkC -ge 9999){
    $StatusOf = 1
}
"

"
If ($StatusOf -eq 1){
    Write-host "Связи с " -NoNewline
    Write-Host -ForegroundColor Cyan $CerDomController -NoNewline
    Write-host " нет! Поиск нового контроллера...
    "

    $z = $i = 0
    $Domains = @()
    Write-host "Получние списка доверенных доменов..." -NoNewline
    $Domains += (Get-ADTrust -filter * -Server $MIHdomain).Name
    $Domains += $MIHdomain
    Write-host " результат: " -NoNewline
    Write-Host -ForegroundColor Cyan $Domains.Count -NoNewline
    $DomContrArray = @{}
    Write-host " Список доменов:"
    Write-Host -ForegroundColor Yellow $Domains

    "
Получение списка контроллеров доменов..
    "
    $Domains | ForEach-Object {
        $curDomain = $_
        If ($NeedDomain -eq $curDomain){
            Write-host "Домен " -NoNewline
            Write-Host -ForegroundColor Cyan $curDomain -NoNewline
            Write-host "... " -NoNewline
            If ($curDomain -eq "metinvest.ua") {
                $CurCred = $CredMIH
            }
            ElseIf ($curDomain -eq "corp.azovstal.ua"){
                $CurCred = $CredAZS
            }
            ElseIf ($curDomain -eq "azovstal.ua"){
                $CurCred = $CredAZS
            }
            Else {
                $CurCred = $CredMIH
            }
            $CurDomContrArray = @()
            Try {
                (Get-ADDomain $curDomain -Server $curDomain  -ErrorAction Stop).ReplicaDirectoryServers | ForEach-Object {
                    $CurContrDomain = $_
                    $CurDomContrArray += $CurContrDomain
                }
                Write-host "найдено " -NoNewline
                Write-Host -ForegroundColor Cyan $CurDomContrArray.Count -NoNewline
                Write-host " контроллеров"
                $DomContrArray.$curDomain=$CurDomContrArray
            }
            Catch {
                Write-host "возникли проблемы при получении информации о домене " -NoNewline
                Write-Host -ForegroundColor RED $curDomain
            }
        }
    }

    "
Список контроллеров домена:"
    Write-Host -ForegroundColor Yellow $DomContrArray.$curDomain

    "

------------------"
    $BestDomControllerArray = @{}
    $DomContrArray.GetEnumerator() | ForEach-Object {
        $curArrDomController = $_.Value
        $curArrDom = $_.Key
        Write-host "

Поиск контроллера с минимальной задержкой... " -NoNewline
        $TempDomContrOtklArray = @{}
        $PackSize = 1450
        $TimeLen = 4
        $curArrDomController.GetEnumerator() | Sort-Object | ForEach-Object {
            $CurDomainController = $_
            Write-Host ''
            $otklMs = 0
            Try {
                test-connection $CurDomainController -Count 1 -BufferSize $PackSize -ErrorAction Stop | ForEach-Object {
                    $IP4 = ($_.IPV4Address).IPAddressToString
                    $Time = $_.ResponseTime
                    $TimeSTR = $Time.ToString()
                    If ($TimeSTR.Length -lt $TimeLen) {
                        While ($TimeSTR.Length -lt $TimeLen) {$TimeSTR = ' ' + $TimeSTR}
                    }
                    Write-Host 'Проверка доменконтроллера ' -NoNewline
                    Write-Host -ForegroundColor Cyan $CurDomainController -NoNewline
                    Write-Host " IP - ($IP4) " -NoNewline
                    Write-Host -ForegroundColor Green $TimeSTR -NoNewline
                    Write-Host ' ms ' -NoNewline
                    $TempDomContrOtklArray.$CurDomainController=$TimeSTR
                    }
                }
             Catch {
                Try {
                    $CurDomainController | Resolve-DNSName -ErrorAction Stop | ForEach-Object {
                        $type = $_.Type;$ipV4 = $_.IPAddress
                        If ($type -eq 'A'){$ipV4 = $_.IPAddress}
                        ElseIf ($type -eq 'AAAA'){$ipV6 = $_.IPAddress}
                    }
                 }
                 Catch {
                    $ipV4 = '---.---.---.---'
                    $ipV6 = '----:----:----:----:----:----:----:----'
                 }
                 Write-Host 'Проверка доменконтроллера ' -NoNewline
                 Write-Host -ForegroundColor Cyan $CurDomainController -NoNewline
                 Write-Host " IP - ($ipV4) " -NoNewline
                 Write-Host -ForegroundColor Red 'Offline ' -NoNewline;
                 $TimeSTR = 9999
                 $TempDomContrOtklArray.$CurDomainController=$TimeSTR
            }
        }
        $domStroper = 0
        $TempDomContrOtklArray.GetEnumerator() | Sort-Object Value  | ForEach-Object {
            $TempDomContrOtklMS = $_.Value
            $TempDomContrOtklHost = $_.Key
            If ($domStroper -eq 0){
                $BestDomControllerArray.$curArrDom=$TempDomContrOtklHost
            }
            $domStroper = $domStroper + 1
        }
        Write-Host ''

    }

    $recomController =  $BestDomControllerArray.$NeedDomain

    Write-host "
Меньше задержки у: " -NoNewline
    Write-Host -ForegroundColor Cyan $recomController
}
Else {
    Write-host "Связь с " -NoNewline
    Write-Host -ForegroundColor Cyan $CerDomController -NoNewline
    Write-host " в наличии." -NoNewline
} 


