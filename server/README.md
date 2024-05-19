# Running a Panel Attack Server

## Installation

### luajit
[LuaJIT](https://luajit.org/luajit.html) is a Just-In-Time compiler for Lua, based on Lua's 5.1 version.
Running Lua code with the JIT compiler has significant performance gains and it also comes with some extra features.
Both server and game use LuaJIT.

linux
```
sudo apt-get install luajit
```

macos
```
brew install luajit
```

Windows

You have to build the binary yourself or find a package manager that does it for you. 
Refer to https://luajit.org/install.html for building yourself.

### lua 5.1
Specifically on the server you may need to install some libraries locally for the server.  
Lua has a dedicated package manager called luarocks.
To work with LuaJIT, Lua 5.1 is required to compile packages that will work with LuaJIT.

linux / macos
```
brew install lua@5.1
```

Windows

You can download the source code on the [Lua website](https://www.lua.org/ftp/).  

### luarocks

Lua Rocks is a lua package manager that will install what we need.

#### brew
```
brew install luarocks
```

#### apt
```
apt install luarocks
```

#### Windows

Precompiled binaries are available from http://luarocks.github.io/luarocks/releases/  
Alternatively there are install instructions at https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Windows

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