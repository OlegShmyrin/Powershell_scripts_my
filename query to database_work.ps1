$conn = New-Object Data.Odbc.OdbcConnection
$conn.ConnectionString= "dsn=dc04-apps-03;"
$conn.open()
$result =(new-Object Data.Odbc.OdbcCommand('select * from SHIFT_MODES',$conn)).ExecuteReader()
$table = new-object "System.Data.DataTable"
$table.Load($result)
$table #| Out-File C:\Temp\test.txt
$conn.close()

#select * from SHIFT_MODES


#$result =(new-Object Data.Odbc.OdbcCommand('SELECT MON$PAGE_READS, MON$PAGE_WRITES, MON$PAGE_FETCHES, MON$PAGE_MARKS FROM MON$IO_STATS WHERE MON$STAT_GROUP = 0;',$conn)).ExecuteReader()
#$result =(new-Object Data.Odbc.OdbcCommand('SELECT r.RDB$DB_KEY, r.RDB$PAGE_NUMBER, r.RDB$RELATION_ID, r.RDB$PAGE_SEQUENCE, r.RDB$PAGE_TYPE FROM RDB$PAGES r;',$conn)).ExecuteReader()
