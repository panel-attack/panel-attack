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


### lua-utf8

```
sudo luarocks --lua-dir=/opt/homebrew/opt/lua@5.1 install lua-utf8
```
on some OS's you may need this command instead
```
sudo luarocks install luautf8
```

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

For windows you need to make sure the following platform specific libraries are present and working

lua51.dll (may have to go into the root folder, not sure)
server\lib\lfs.dll (included version should work)
common\lib\sqlite\lsqlite3.dll (included version should work)
common\lib\socket\core.dll 

Try to figure out from the error message what you are missing.

## Ranking

If you want to host your own server with ranking, be sure to change your csprng_seed.txt file, or your users' user_ids will be less secure.

## Connecting with the client

If you are running locally you can go into the client settings -> debug -> show debug connections to add a menu option for connecting to localhost.

If you want to access your server from an IP you need to add your ip to the client's menus.

Change MainMenu.lua, around where it says something like

{MenuItem.createButtonMenuItem("Beta Server", switchToScene(sceneManager:createScene("Lobby", {serverIp = "betaserver.panelattack.com", serverPort = 59569})},

to something that makes sense for your server. Replace "Beta Server" the URL and the port number. The port number is optional, the game will try to connect to port 49569 if not supplied.