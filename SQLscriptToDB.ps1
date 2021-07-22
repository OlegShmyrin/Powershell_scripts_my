$script = Get-Content D:\DB_IASKC_test\AKZ-renumber\Shift_Update_KC2_23.06.2021.sql

$script | D:\FBDs\Firebird_2_5\bin\isql.exe 127.0.0.1/3050:D:\DB_IASKC_test\ZPC\BASEBAT2.GDB -user sysdba -pass 1 >> D:\DB_IASKC_test\AKZ-renumber\logs.txt

$script | D:\FBDs\Firebird_2_5\bin\isql.exe 127.0.0.1/3050:D:\DB_IASKC_test\ZPC\BASEBAT56.GDB -user sysdba -pass 1 >> D:\DB_IASKC_test\AKZ-renumber\logs.txt