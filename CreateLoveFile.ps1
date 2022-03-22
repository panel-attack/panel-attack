#This file may need to be unblocked on your computer in order to run. Go to your file properties to do this.

if (Test-Path "$($PSScriptRoot)\main.lua") {
    $Time = Get-Date 
    $UTCTime = $Time.ToUniversalTime().ToString("yyyy-MM-dd_HH-mm-ss")
    $FileNameZip = "panel-$($UTCTime).zip"
    $compress = @{
        Path            = "$($PSScriptRoot)\*"
        DestinationPath = "$($PSScriptRoot)\$($FileNameZip)"
    }
      
    Compress-Archive @compress; Rename-Item -Path "$($PSScriptRoot)\$($FileNameZip)" -NewName $($FileNameZip).Replace(".zip", ".love")
}
else {
    Write-Error -Message "main.lua was not found in $($PSScriptRoot)"
}
