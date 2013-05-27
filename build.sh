#!/bin/sh
rm panel-attack.love panel.zip panel.exe
zip -r panel-attack.love *.lua *.txt README THANKS COPYING server.py build.sh assets/*.png assets/*/*png
echo "Build windows exe"
cat /Users/sharpobject/Downloads/love-0.7.2-win-x86/love.exe panel-attack.love > panel.exe
echo "Zip windows exe"
cp /Users/sharpobject/Downloads/love-0.7.2-win-x86/*dll .
zip panel.zip *dll panel.exe
rm *dll
