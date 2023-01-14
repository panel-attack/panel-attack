#!/bin/bash
# This script assumes you are running it on a Linux machine 
# It should be possible to run as well in git bash under windows after adding some of the commands to it
rm panel*.love panel.zip panel.exe auto_updater/panel*.love love/panel.exe
zip -rq panel-attack.love *.* README THANKS COPYING characters computerPlayers default_data engine panels rich_presence select_screen stages themes
mv panel-attack.love auto_updater/panel-attack.love
cd auto_updater
zip -r ../panel-attack.love *
cd ..
# Your panel-attack repository needs to have a directory called love
# That directory is expected to contain the contents of the unzipped 32-bit windows version of love downloaded from the love2d mainpage
mv panel-attack.love love/panel-attack.love
echo "Build windows exe"

cd ./love
cat love.exe panel-attack.love > panel.exe
cp panel.exe ../panel.love
zip -u ../panel.zip *.dll license.txt panel.exe

