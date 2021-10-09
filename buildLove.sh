#!/bin/sh
build_dir="../dev-build/"
mods_dir="../custom-mods/"

echo "Generating panel-attack.love ${build_dir}"
rm -Rf "${build_dir}"
mkdir "${build_dir}"
zip -r --quiet "${build_dir}panel-attack.love" *.lua *.txt *.ttf *.csv *.py zero_music.ogg auto_updater/* default_data/* panels/Panel\ Attack/* panels/pdp_ta/* characters/__default/* stages/__default/* themes/Panel\ Attack/*

echo "Generating panel-attack zip"
zip -r --quiet "${build_dir}panel-attack.zip" "${build_dir}panel-attack.love" readme_*.txt README THANKS COPYING 