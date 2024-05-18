#!/bin/bash
# This script builds the love files, and the windows exe for the game
# pass "local" if you want just a local build, and "just-love" if you want just the love files
# pass "discard-love" for the second argument if you want to delete the love files
#
# Your panel-attack repository needs to have a directory in the directory above the repo named "love-12.0-win64"
# That directory is expected to contain the contents of the unzipped 32-bit windows version of love downloaded from the love2d mainpage

shopt -s extglob

build_dir="../dev-build/"
win_files_dir="../love-12.0-win64/"

# Cleanup the build dir
rm -Rf "${build_dir}"
mkdir "${build_dir}"

echo "Building... Results can be found at ${build_dir}"

echo "Generating panel attack love file"

# We are explicitly specifying which files are included. Make sure to add specific files in alphabetical order.
zip -r --quiet "${build_dir}panel-attack.love" conf.lua main.lua docs client common -x ".*" \*__MACOSX* \*\.DS_Store

if [ -n "$1" ] && [ $1 == "local" ]
then
  echo "Generating Custom Build EXE"
  loveFile="${build_dir}panel-attack.love"
fi

if [ -z "$1" ] || [ $1 != "just-love" ]
then
  cp -R "${win_files_dir}." "${build_dir}"

  cat "${build_dir}love.exe" $loveFile > "${build_dir}panel.exe"
  rm "${build_dir}love.exe"
  rm "${build_dir}lovec.exe"
fi

if [ -n "$2" ] && [ $2 == "discard-love" ]
then
  echo "Removing panel attack love from build directory"
  rm "${build_dir}panel-attack.love"
fi