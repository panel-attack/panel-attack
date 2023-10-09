# Releasing Panel Attack Notes

## Making a normal love release

Checkout the branch, make sure you have no extra changes

Run the build script and add the date to the love file
```
git status; ./build.sh auto-updater keep-love; mv ../dev-build/panel-attack.love "../releases/LoveFiles/panel-$(date -u "+%Y-%m-%d_%H-%M-%S").love"; open ../releases/LoveFiles
git status; ./build.sh auto-updater keep-love; mv ../dev-build/panel-attack.love "../releases/LoveFiles/panel-beta-$(date -u "+%Y-%m-%d_%H-%M-%S").love"; open ../releases/LoveFiles
```

Upload the love file to the server in the proper location for beta or stable

```
scp -r -i PEMKEYLOCATIONHERE panel-2023-06-17_23-34-47.love  ubuntu@18.188.43.50:panel-attack-server/ftp/updates
scp -r -i PEMKEYLOCATIONHERE panel-beta-2023-07-22_19-49-45.love ubuntu@18.188.43.50:panel-attack-server/ftp/beta-updates/
```

## Auto Updater

auto_updater/main.lua
local UPDATER_NAME = "panel-alpha" -- you should name the distributed auto updater zip the same as this
local UPDATER_NAME = "panel-beta" -- you should name the distributed auto updater zip the same as this
local UPDATER_NAME = "panel" -- you should name the distributed auto updater zip the same as this

auto_updater/_config.lua
server_url= "http://panelattack.com/alpha-updates",
server_url= "http://panelattack.com/beta-updates",
server_url= "http://panelattack.com/updates",

CreateLoveFile.ps1
    $FileNameZip = "panel-alpha-$($UTCTime).zip"
    $FileNameZip = "panel-beta-$($UTCTime).zip"
    $FileNameZip = "panel-$($UTCTime).zip"

Create a love file

date -u "+%Y-%m-%d_%H-%M-%S"

Name it:
panel-alpha-2022-03-20_01-21-08.love
panel-beta-2022-03-08_04-17-21.love
panel-2022-01-29_18-25-38.love
