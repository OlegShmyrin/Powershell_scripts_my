$computers = get-content C:\temp\servers.txt
foreach ($computer in $computers)
{ 
    $DNSServers = ”10.11.201.10",“10.25.201.10","10.41.50.10","10.41.70.10","10.51.1.4","10.51.1.6"

    Get-WMIObject -class Win32_NetworkAdapterConfiguration -computername $computer -Filter IPEnabled=TRUE | 
        %{ 

            $_.DNSHostName
            #$_.SetDNSServerSearchOrder($DNSServers)
            $_.DNSServerSearchOrder

        }
}