Write-Host "Введите логин и пароль Доменного пользователя имеющего доступ к шарам МИХ в формате metinvest\oleg.shmyrin" -ForegroundColor Yellow
$crdUser = Get-Credential



    $pathPF = 'C:\Program Files'

    if(!(Test-Path $pathPF)){
    New-Item -ItemType Directory -Force -Path $pathPF 
    }

$pathTMP = 'C:\intes'
    if(!(Test-Path $pathTMP)){
        New-Item -ItemType Directory -Force -Path $pathTMP 
    }


New-PSDrive -Name 'NetShare' -PSProvider FileSystem -Root \\metinvest.ua\root\AKZ\Application\install -Credential $crdUser
If (Test-Path -Path 'NetShare:\Jinitiator11827_x64')
{
    Write-Host "Копируем файлы во временные каталоги" -ForegroundColor Green
    Copy-Item -Path NetShare:\Jinitiator11827_x64 -Destination $pathTMP -Recurse -Force
    sleep(10)
}


Copy-Item $pathTMP\Jinitiator11827_x64\Oracle $pathPF -Recurse -Force
Copy-Item $pathTMP\Jinitiator11827_x64\JinPanel.dll C:\Windows\System32 -Force

Write-Host "Добавляем файлы реестра" -ForegroundColor Green

$SID = "userSID" 
Get-ChildItem C:\Users | %{
    $objUser = New-Object System.Security.Principal.NTAccount($_.Name)
    $objUser
    $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
    $strSID.Value
    
        $regFiles = Get-ChildItem $pathTMP\Jinitiator11827_x64\REG_FILES
        foreach ($file in $regFiles) {
            (Get-Content $file.PSPath) |
            ForEach-Object {$_ -replace $SID, $strSID.Value } |
            Set-Content $file.PSPath
            $file
            Start-Process $pathTMP\Jinitiator11827_x64\psexec64.exe -ArgumentList "/accepteula cmd /c -s c:\Windows\regedit.exe /s $file"
            sleep (1)
        }
    $SID = $strSID.Value
    #sleep (30)
    
}

Write-Host "Удаляем временные файлы, отмонтируем шары." -ForegroundColor Green
rmdir $pathTMP -Force
Remove-PSDrive -Name 'NetShare'
Write-Host "Все!" -ForegroundColor Green

Exit-PSSession 



