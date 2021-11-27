$Time = Get-Date 
$UTCTime = $Time.ToUniversalTime().ToString("yyyy-MM-dd_HH-mm-ss")
$FileNameZip = "panel-alpha-$($UTCTime).zip"

$compress = @{
Path = ".\*"
DestinationPath = ".\$($FileNameZip)"
}

Compress-Archive @compress; Rename-Item -Path ".\$($FileNameZip)" -NewName $($FileNameZip).Replace(".zip", ".love")