#!/bin/sh
# This script assumes you are running it on a Windows machine with 32 bit LÖVE installed in the default location
# How to add zip to git bash under windows: https://stackoverflow.com/a/55749636

rm panel*.love panel.zip panel.exe auto_updater/panel*.love
zip -r panel-attack.love *.* README THANKS COPYING characters default_data engine panels rich_presence select_screen stages themes
mv panel-attack.love auto_updater/panel-attack.love
cd auto_updater
zip -r ../panel-attack.love *
cd ..
mkdir -p love
mv panel-attack.love love/panel-attack.love
echo "Build windows exe"

# If not running windows, change love source location here
cp -f '/c/Program Files (x86)/LOVE/SDL2.dll' '/c/Program Files (x86)/LOVE/OpenAL32.dll' '/c/Program Files (x86)/LOVE/love.dll' '/c/Program Files (x86)/LOVE/lua51.dll' '/c/Program Files (x86)/LOVE/mpg123.dll' '/c/Program Files (x86)/LOVE/msvcp120.dll' '/c/Program Files (x86)/LOVE/msvcr120.dll' '/c/Program Files (x86)/LOVE/license.txt' '/c/Program Files (x86)/LOVE/love.exe' love
cd ./love
cat love.exe panel-attack.love > panel.exe
zip -u ../panel.zip *.dll license.txt panel.exe

