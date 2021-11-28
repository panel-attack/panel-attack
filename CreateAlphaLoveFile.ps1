#This file may need to be unblocked on your computer in order to run. Go to your file properties to do this.

$Time = Get-Date 
$UTCTime = $Time.ToUniversalTime().ToString("yyyy-MM-dd_HH-mm-ss")
$FileNameZip = "panel-alpha-$($UTCTime).zip"

$compress = @{
Path = "$($PSScriptRoot)\*"
DestinationPath = "$($PSScriptRoot)\$($FileNameZip)"
}

Compress-Archive @compress; Rename-Item -Path "$($PSScriptRoot)\$($FileNameZip)" -NewName $($FileNameZip).Replace(".zip", ".love")
