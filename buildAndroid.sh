#!/bin/bash
# This script assumes you are running it on a Linux machine 
echo "Removing remnants of prior build process"
rm panel*.love panel.zip auto_updater/panel*.love
echo "Build Android.love (relies on separate love2d install)"
zip -rq panel-attack.love *.* README THANKS COPYING characters computerPlayers default_data engine panels rich_presence select_screen stages themes
mv panel-attack.love auto_updater/panel-attack.love
cd auto_updater
zip -r ../panel-attack-android.love *

