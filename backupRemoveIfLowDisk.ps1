
    $Source = "D:\MD_OFFICE\MasterDN\MD-Declaration\BackUp"
    $FileExt = "*.bku"
    $DiskLetter = "D";
    
    
    #count of bakups
    $CountOfFiles = get-childitem -path $Source -Filter $FileExt |
    #Исключаем каталоги
    where-object { -not $_.PSIsContainer } | Measure-Object

    Write-Host $CountOfFiles.Count

    if ($CountOfFiles.Count -gt 2){
        Write-Host "work"
 
            #Получаем список фалов из папки по фильтру .bku
            $backupFile = get-childitem -path $Source -Filter $FileExt |
            #Исключаем каталоги
            where-object { -not $_.PSIsContainer } |
            #Сортируем по дате создания
            Select-Object $_.CreationTime |
            sort-object -Property CreationTime | 
            #Выбираем последний созданный файл
            select-object -last 1 #поставить first

            Write-Host $backupFile -ForegroundColor Green

            $backupFileSize = ([decimal]::round($backupFile.Length / 1MB)).tostring()     
            write-host $backupFileSize
    
    
            $DeviceID = ($DiskLetter+':').ToUpper()
            $Disk = Get-WMIObject Win32_LogicalDisk —filter "DeviceID='$DeviceID'"

            $FreeDiskSpace = ([decimal]::round($Disk.FreeSpace / 1MB)).tostring()
             Write-Host "На диске $DeviceID свободно $FreeDiskSpace МБ"
             write-host "Размер бэкапа $backupFileSize Мб" 
                                                                                                                
			        if ([int]$FreeDiskSpace -lt [int]$backupFileSize) # Если свободного места не достаточно
                    {
                        Write-Host "свободного места не достаточно, надо удалять!"
                        $backupTodelete = get-childitem -path $Source -Filter $FileExt |
                        #Исключаем каталоги
                        where-object { -not $_.PSIsContainer } |
                        #Сортируем по дате создания
                        sort-object -Property $_.CreationTime |
                          sort-object -Property CreationTime |  
                        #Выбираем последний созданный файл
                        select-object -first 1 
                        Write-Host $backupTodelete -ForegroundColor Red
                        Remove-Item "$Source\$backupTodelete"

                    }else{
                        Write-Host "Место есть!"
                    }
     }else{
        Write-Host "backup count is less then 2"
    }
