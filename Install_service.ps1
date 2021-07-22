.\instreg.exe install
(Get-Content -path D:\FBDs\Firebird_2_5_ZKZ\firebird.conf -Raw) -replace '3051','3052'
.\instsvc.exe install -m -a -n Firebird_ZKZ
