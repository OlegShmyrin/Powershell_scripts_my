Function Test-ODBCConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,
                    HelpMessage="dc04-apps-06_FB_KC1")]
                    [string]$DSN
    )
    $conn = new-object system.data.odbc.odbcconnection
    $conn.connectionstring = "(DSN=$DSN)"
    
    try {
        if (($conn.open()) -eq $true) {
            $conn.Close()
            $true
        }
        else {
            $false
        }
    } catch {
        Write-Host $_.Exception.Message
        $false
    }
}

Function Test-ODBCConnection