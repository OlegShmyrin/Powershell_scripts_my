class MonitoredService {

    [String]$name
    [int]$port
    [String]$ControlFile
    [String]$ServiceProcessName

    MonitoredService()
    {
        Write-Host "Конструктор по умолчанию"
    }
       
    MonitoredService([String]$name, [int]$port, [String]$ControlFile, [String]$ServiceProcessName)
                        {
                        $this.name = $name
                        $this.port = $port
                        $this.ControlFile=$ControlFile
                        $this.ServiceProcessName = $ServiceProcessName
                       }
}

#[MonitoredService]::new("wuauclt",1234,"wu.txt","ServiceProcessName")
#[MonitoredService]::new

$ServicesFromFile = Import-Csv -Path C:\ServiceControlTest\Monitorig\ServiceToMonitoring.csv

foreach($service in $ServicesFromFile){

    [MonitoredService]::new($service.Name,$service.port,$service.ControlFile,$service.PServiceProcessName)
}
