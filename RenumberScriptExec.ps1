
try {
"$(Get-Date)" + " Начало работы скрипта " >> D:\DB_IASKC_test\AKZ-renumber\logs.txt

$yesterday = (Get-Date).AddDays(-1).ToString("dd-MM-yy")
$yesterday

Get-Service -Name "FirebirdServerDefaultInstance" | Restart-Service -Verbose >> D:\DB_IASKC_test\AKZ-renumber\logs.txt
#Restart-Service -Name FirebirdServerDefaultInstance

d:
cd D:\DB_IASKC_test\AKZ-renumber\ 
Rename-Item -Path BASEKC4.GDB -NewName "BASEKC4+$($yesterday).GDB" -Force

#Удалять через 5 дней

Get-ChildItem -Path D:\DB_IASKC_test\AKZ-renumber\ -Filter "BASEKC4+*.gdb" | Where-Object {$_.CreationTime -lt (Get-Date).AddDays(-6)} | Remove-Item

#  get-childitem -path D:\DB_IASKC_test\AKZ-renumber\ -Filter "BASEKC4+*.gdb" |
    #Исключаем каталоги
#    where-object { -not $_.PSIsContainer } |
    #Сортируем по дате создания
#    sort-object -Property $_.CreationTime | 
    #Выбираем последний созданный файл
#    select-object -last 1 |
    #Копируем файл в составной каталог на локальный диск D:
#    copy-item -Destination (join-path $LocalPath "BASE$Shop.gbk")

#Remove-Item D:\DB_IASKC_test\AKZ-renumber\BASEKC4.GDB -Force -Verbose >> D:\DB_IASKC_test\AKZ-renumber\logs.txt

Copy-Item D:\CopyDB_IASKC_prod\AKZ\KC4\BASEKC4.GDB -Destination D:\DB_IASKC_test\AKZ-renumber\ -Verbose *>> D:\DB_IASKC_test\AKZ-renumber\logs.txt

$script = Get-Content D:\DB_IASKC_test\AKZ-renumber\script.sql

$script | D:\FBDs\Firebird_2_5\bin\isql.exe 127.0.0.1/3050:D:\DB_IASKC_test\AKZ-renumber\BASEKC4.GDB -user sysdba -pass 1 >> D:\DB_IASKC_test\AKZ-renumber\logs.txt

Copy-Item D:\DB_IASKC_test\AKZ-renumber\BASEKC4.GDB -Destination D:\DB_IASKC_test\AKZ-renumber\BASEKC4_DEV.GDB -Verbose *>> D:\DB_IASKC_test\AKZ-renumber\logs.txt

"$(Get-Date)" + " Работы окончены " >> D:\DB_IASKC_test\AKZ-renumber\logs.txt

}
Catch{
    
    #Write-Host $_.exception 
    "$(Get-Date)" + " Error " + "$_.exception" | Out-File D:\DB_IASKC_test\AKZ-renumber\logs.txt -Append
}