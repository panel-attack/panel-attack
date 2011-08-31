#!/bin/sh
rm panel-attack.love panel.zip panel.exe
zip -r panel-attack.love *.lua *.txt README THANKS COPYING server.py build.sh assets/*.png
echo "Build windows exe"
cat ~/love/love.exe panel-attack.love > panel.exe
echo "Zip windows exe"
zip panel.zip ~/lovex/*dll panel.exe
rm panel.exe
