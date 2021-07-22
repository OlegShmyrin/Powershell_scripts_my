$properties=@(
    @{Name="Name"; Expression = {$_.name}},
    @{Name="PID"; Expression = {$_.IDProcess}},
    @{Name="CPU (%)"; Expression = {$_.PercentProcessorTime}},
    @{Name="Memory (MB)"; Expression = {[Math]::Round(($_.workingSetPrivate / 1mb),2)}}
    @{Name="Disk (MB)"; Expression = {[Math]::Round(($_.IODataOperationsPersec / 1mb),2)}}
)
$ProcessCPU = Get-WmiObject -class Win32_PerfFormattedData_PerfProc_Process |
    Select-Object $properties |
    Sort-Object "CPU (%)" -desc |
    Select-Object -First 5
$ProcessCPU | select *,@{Name="Path";Expression = {(Get-Process -Id $_.PID).Path}} | Format-Table