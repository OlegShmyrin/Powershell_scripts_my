$params = @{
  Name = "TestService"
  BinaryPathName = '"c:\Windows\System32\tasklist.exe >> C:\logfiles\srv.log"'
  DisplayName = "Test Service"
  StartupType = "Manual"
  Description = "This is a test service."
}
New-Service @params

$params = @{
  Name = "TestService"
  BinaryPathName = "c:\Windows\System32\tasklist.exe >> C:\logfiles\srv.log"
  DisplayName = "Test Service"
  StartupType = "Manual"
  Description = "This is a test service."
}
New-Service @param

"C:\Windows\System32\sc.exe delete TestService"