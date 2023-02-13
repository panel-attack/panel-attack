# Running a Panel Attack Server

## Installation


### lua 5.1
We target a version of lua 5.1 that has a couple fixes, namely the one that comes from luajit

If you just try to run lua5.1 you will get an error about math.random interval

linux / macos
```
brew install lua@5.1
```

windows

The repository includes a lua binary for windows.


### luajit

linux
```
sudo apt-get install luajit
```

macos
```
brew install luajit
```

Windows

I think you have to build the binary yourself.  Takes some googling and effort.

### luarocks

Lua Rocks is a lua package manager on macOS and linux that will install what we need, if you are on windows see the end section.

```
brew install luarocks
```

### luasocket

```
sudo luarocks --lua-dir=/opt/homebrew/opt/lua@5.1 install luasocket
```

### luafilesystem

```
sudo luarocks --lua-dir=/opt/homebrew/opt/lua@5.1 install luafilesystem
```

### lsqlite3

```
sudo luarocks --lua-dir=/opt/homebrew/opt/lua@5.1 install sqlite3
sudo luarocks --lua-dir=/opt/homebrew/opt/lua@5.1 install lsqlite3
```

if that doesn't work you can use 
```
sudo luarocks --lua-dir=/opt/homebrew/opt/lua@5.1 install lsqlite3complete
```
and change the require to use lsqlite3complete

### Add lua to your path

This step depends more on your shell and environment, but make sure lua's install directory is on your path

macOS fish shell example
```
fish_add_path --path /opt/homebrew/lib/lua
```

### Add luarocks 5.1 to your lua search path

This step depends more on your shell and environment, but make sure luarock's install directory is on your path

macOS fish shell example
```
luarocks path --lua-version 5.1
```

Take that output and put it in your config file

```
vi ~/.config/fish/config.fish
```

## Checkout Repository

Checkout the panel attack repository
```
git clone https://github.com/panel-attack/panel-attack.git
```

go into that directory

## Running
```
luajit serverLauncher.lua
```

### Windows versions of luasocket and luafilesystem

For windows you either need to include the files in the repository or get the files yourself.

look in the folders like "luapower lfs for win64 server"
lfs.dll (on windows)
lfs.so (on linux)
lua51.dll (on windows)
socket/core.so (on linux, make a folder for socket and put core.so in there)

it may still complain about missing files.  Try to figure out from the error message what you are missing.

## Ranking

If you want to host your own server with ranking, be sure to change your csprng_seed.txt file, or your users' user_ids will be less secure.

## Connecting with the client

If you are running locally you can go into the client settings -> debug -> show debug connections to add a menu option for connecting to localhost.

If you want to access your server from an IP you need to add your ip to the client's menus.

Change mainloop.lua, around where it says something like

{loc("mm_2_vs_online", ""), main_net_vs_setup, {"18.188.43.50"}},

to something that makes sense for your server.  (replace "loc("mm_2_vs_online", "")", and the IP. Using a URL here instead is ok)


## Outdated info on how to build a client

Then build a windows binary for the client from source code.
see this link for instructions:
https://love2d.org/wiki/Game_Distribution

Here's a windows script that does this:

7z a -tzip ./output/panel.love ./panel-attack/*  -x!./panel-attack/.git
mkdir .\output\panel-attack
copy /b love.exe+.\output\panel.love .\output\panel-attack\panel.exe
xcopy .\love-0.9.0-win32\*.* .\output\panel-attack

instructions for the above script:
This does assume you've installed 7zip and have added its installation folder to your PATH environmental variables
place the source code you'd like to package into a folder called "panel-attack" in the same directory as the builder.bat file.
also place the love.exe downloaded from the zip file for the version of love you'd like to use from https://bitbucket.org/rude/love/downloads/
it will create a panel.love file, and a panel.exe from the source code.

Note you can get love.exe and the love-0.9.0-win32 folder from here:
https://bitbucket.org/rude/love/downloads/

Note: you can supposedly run a built love windows executable on mac or linux by installing love2d (0.9.0), changing the extension from .exe to .love, and opening the file with love2d.  In pratice though, people have had more luck with WINE.
