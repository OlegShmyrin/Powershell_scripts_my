﻿#попробовать параллельное выполнение

$SourceZKZ ="\\dc43-apps-07\Copy_base\"
$ZKZ_DB = "bat2", "bat56"




function Copy-And-Restore-ZKZ {
  #Передаем путь к Шаре на продуктивном сервере и имя цеха
  param ($Source,$Shop)

# объявляем ИМЯ актива для перехода в каталог актива на локальном диске D:
$ZKZ="ZKZ"
#Путь к БД на диске d: 
$DBsCatalogPath = "D:\CopyDB_IASKC_prod"

#Проверка доступности шары
if(Test-Path -path $Source)
    {
    #Составной путь к папке с БД Актв/Цех
    $LocalPath = $DBsCatalogPath +"\"+ $ZKZ+"\"+$Shop
    $ShopRemotePath = $Source+"\"+$Shop

    #Получаем список фалов из шары по фильтру ЦЕХ*.gbk
    get-childitem -path $ShopRemotePath -Filter "$Shop*.gbk"|
    #Исключаем каталоги
    where-object { -not $_.PSIsContainer } |
    #Сортируем по дате создания
    sort-object -Property $_.CreationTime | 
    #Выбираем последний созданный файл
    select-object -last 1 |
    #Копируем файл в составной каталог на локальный диск D:
    copy-item -Destination (join-path $LocalPath "BASE$Shop.gbk")
    #Выводим сообщение
    Write-Host "Копируем БД $Shop из $Source в $LocalPath" -ForegroundColor Green
    
    #Перезапускаем службу Соответсвующего АКТИВА
    #Get-Service -name "*Firebird_$ZKZ" | Restart-Service
    #Удаляем БД
    get-childitem -path $LocalPath -Filter "*.GDB" | Remove-Item

    #Запускаем восстановление из бэкапа
    & {D:\FBDs\Firebird_2_5\bin\gbak.exe -c -v -user SYSDBA -pas 1 $LocalPath\BASE$Shop.gbk $LocalPath\BASE$Shop.GDB}
    
    #ToDO:   Start service
    
    #Удаляем файл бэкапа
    get-childitem -path $LocalPath -Filter "*.gbk" | Remove-Item

    }
    else 
    {
    Write-Host "нет доступа к шаре: $Source" -ForegroundColor DarkRed
    }

}


#Вызываем функцию копирования для АКХЗ в цикле для каждого Цеха.
foreach($database in $ZKZ_DB) {
    Copy-And-Restore-ZKZ -Source $SourceZKZ -Shop $database
}