$fbServerList = "dc04-apps-04",
                "dc04-apps-03",
                "dc04-apps-06",
                "DC09-apps-09",
                "Dc08-apps-11",
                "Dc08-apps-16",
                "Dc43-apps-07",
                "Dc44-apps-09",
                "dc38-apps-18"


foreach($Server in $fbServerList) 
{

Write-Host $Server -ForegroundColor Green
Get-NetTCPConnection -LocalPort 3050,3051 -CimSession $Server -ErrorAction Continue| % { Get-Process -id $_.OwningProcess -ComputerName $Server}

}
