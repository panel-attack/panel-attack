#!/bin/bash
# This script assumes you are running it on a Linux machine 
rm panel*.love panel.zip panel.exe auto_updater/panel*.love
zip -rq panel-attack.love *.* README THANKS COPYING characters default_data engine panels rich_presence select_screen stages themes
mv panel-attack.love auto_updater/panel-attack.love
cd auto_updater
zip -r ../panel-attack.love *
cd ..
mkdir -p love
mv panel-attack.love love/panel-attack.love
echo "Build windows exe"

# Provide a path to the contents of the unzipped 32-bit windows version of love downloaded from the love2d mainpage
cp '/home/florian/Apps/love-11.4-win32/SDL2.dll' love
cp '/home/florian/Apps/love-11.4-win32/OpenAL32.dll' love
cp '/home/florian/Apps/love-11.4-win32/love.dll' love
cp '/home/florian/Apps/love-11.4-win32/lua51.dll' love
cp '/home/florian/Apps/love-11.4-win32/mpg123.dll' love
cp '/home/florian/Apps/love-11.4-win32/msvcp120.dll' love
cp '/home/florian/Apps/love-11.4-win32/msvcr120.dll' love
cp '/home/florian/Apps/love-11.4-win32/license.txt' love
cp '/home/florian/Apps/love-11.4-win32/love.exe' love
cd ./love
cat love.exe panel-attack.love > panel.exe
zip -u ../panel.zip *.dll license.txt panel.exe

