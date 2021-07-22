$conn = New-Object Data.Odbc.OdbcConnection
 $conn.ConnectionString= "DRIVER=Firebird/InterBase(r) driver;UID=SYSDBA;PWD=1;DBNAME=dc04-apps-06/3050:D:\DB_IASKC_test\AKZ\BASEKC1.GDB;"

#$conn.ConnectionString='Provider=MSDASQL.1;Persist Security Info=False;Extended Properties="DSN=test;Driver=Firebird/InterBase(r) driver;Dbname=dc04-apps-04/3051:D:\MasterD\MD-Declaration\Base\DECLDOCPLUS.FD2;CHARSET=NONE;UID=scomu;Password=scompas;Role=scomreadonly;Client=D:\FBDs\Firebird_2_5\bin\fbclient.dll;READONLY=YES;'
#$conn.ConnectionString='Provider=MSDASQL.1;Persist Security Info=False;Extended Properties="DSN=TEMP;Driver=Firebird/InterBase(r) driver;Dbname=dc04-apps-04/3051:D:\MasterD\MD-Declaration\Base\DECLDOCPLUS.FD2;CHARSET=NONE;UID=scomu;Password=scompas;Role=scomreadonly;Client=D:\FBDs\Firebird_2_5\bin\fbclient.dll;READONLY=YES;'

$conn.open()
#$result =(new-Object Data.Odbc.OdbcCommand('SELECT MON$PAGE_READS, MON$PAGE_WRITES, MON$PAGE_FETCHES, MON$PAGE_MARKS FROM MON$IO_STATS WHERE MON$STAT_GROUP = 0;',$conn)).ExecuteReader()
$result =(new-Object Data.Odbc.OdbcCommand('SELECT r.RDB$DB_KEY, r.RDB$PAGE_NUMBER, r.RDB$RELATION_ID, r.RDB$PAGE_SEQUENCE, r.RDB$PAGE_TYPE FROM RDB$PAGES r;',$conn)).ExecuteReader()
#$result =(new-Object Data.Odbc.OdbcCommand('SELECT MON$PAGE_READS, MON$PAGE_WRITES, MON$PAGE_FETCHES, MON$PAGE_MARKS FROM MON$IO_STATS WHERE MON$STAT_GROUP = 0;',$conn)).ExecuteReader()
$table = new-object "System.Data.DataTable"
$table.Load($result)
$table #| Out-File C:\Temp\test.txt
$conn.close()

#SELECT MON$PAGE_READS, MON$PAGE_WRITES, MON$PAGE_FETCHES, MON$PAGE_MARKS FROM MON$IO_STATS WHERE MON$STAT_GROUP = 0;