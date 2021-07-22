$connection = New-Object Data.OleDbConnection

#$cn = new-object system.data.SqlClient.SqlConnection("Provider=MSDASQL.1;Persist Security Info=False;Dbname=dc04-apps-04/3051:D:\MasterD\MD-Declaration\Base\DECLDOCPLUS.FD2;CHARSET=NONE;UID=scomu;Password=scompas;Role=scomreadonly;Client=D:\FBDs\Firebird_2_5\bin\fbclient.dll;READONLY=YES;");

$cnonnrction = new-object system.data.SqlClient.SqlConnection("Provider=MSDASQL.1;Persist Security Info=False;'User=scomu;Password=scompas;Database=D:\MasterD\MD-Declaration\Base\DECLDOCPLUS.FD2;DataSource=dc04-apps-04;Port=3051;Dialect=3;Charset=NONE;Role=;Connection lifetime=15;Pooling=true;MinPoolSize=0;MaxPoolSize=50;Packet Size=8192;ServerType=0;");
ServerType=0;

$connection.conn