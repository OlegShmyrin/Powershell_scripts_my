$fileshares = Get-SmbShare -Special 0 | Where-Object {$_.Path -notlike "C:\Windows\*"}


#### Create ACL for Audit ###
$AuditUser = "Everyone"
$AuditRules = "FullControl"
$InheritType = "ContainerInherit,ObjectInherit"
$AuditType = "Success"
$AccessRule = New-Object System.Security.AccessControl.FileSystemAuditRule($AuditUser,$AuditRules,$InheritType,"None",$AuditType)


foreach ($TargetFolder in $fileshares)
{
    if(Test-Path $TargetFolder.Path){  #Exclude printers
        $ACL = Get-Acl $TargetFolder.Path
        $ACL.SetAuditRule($AccessRule)
        Write-Host "Processing >",$TargetFolder.Path -ForegroundColor Green
        $ACL | Set-Acl $TargetFolder.Path
    }
}
Write-Host "Audit Policy applied successfully." -ForegroundColor Magenta