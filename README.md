# Windows Setup
This guide assume you are using `{PATH_TO_LUA}` as the root directory for all files unless otherwise specified
1. Install visual studio 2022
   - https://visualstudio.microsoft.com/downloads/
   - The following commands will assume you are using the x64 Native Tools Command Prompt for VS 2022
 1. Download zerobrane
     - https://studio.zerobrane.com/download?not-this-time
## Running the client
1. Download love
   - https://github.com/love2d/love
2. Compile love via the megasource (instructions in the repository README)
   - https://github.com/love2d/megasource
3. Copy the contents of `{PATH_TO_LUA}\megasource\build\love\Release` to `C:\Program Files\love`
4. Setup zerobrane
   - Set the interpreter to love
5. Run the Panel Attack
   - The main game
     - Set the project directory to the root directory
   - Main game via the auto updater
     - Set the project directory to the auto_updater subdirectory
## Running the server
1. Download lua 5.4.4
   - https://www.lua.org/ftp/
2. Compile lua with a windows make file
   - https://github.com/vtudorache/lua-msvc
   - With the above repo from the `{ROOT}\msvc\5.4\dynamic` directory run:
     -  `nmake install INSTALL_ROOT={PATH_TO_LUA}\lua-5.4.4 SOURCE_ROOT={PATH_TO_LUA}\lua-5.4.4`
3. Setup zerobrane for lua 5.4
	- Copy the following
		-  `{PATH_TO_LUA}\lua-5.4.4\bin\lua.exe` -> `{PATH_TO_LUA}\ZeroBraneStudio\bin\lua54.exe`
		- `{PATH_TO_LUA}\lua-5.4.4\bin\lua54.dll` -> `{PATH_TO_LUA}\ZeroBraneStudio\bin\lua54.dll`
	- Write the following to `{PATH_TO_LUA}\ZeroBraneStudio\interpreters\luadeb54.lua`
```
dofile 'interpreters/luabase.lua'
local interpreter = MakeLuaInterpreter(5.4, ' 5.4')
interpreter.skipcompile = true
return interpreter
```

4. Download luarocks
   - http://luarocks.github.io/luarocks/releases/
5. Link rocks to lua
   - Write the following to `C:\Users\{USER}\AppData\Roaming\LuaRocks\share\lua\5.4\luarocks\config-5.4.lua`
```
lua_interpreter = "lua.exe"
variables = {
   LUA_BINDIR = "{PATH_TO_LUA}\\lua-5.4.4\\bin",
   LUA_INCDIR = "{PATH_TO_LUA}\\lua-5.4.4\\include",
   LUA_LIBDIR = "{PATH_TO_LUA}\\lua-5.4.4\\lib",
   LUA_DIR = "{PATH_TO_LUA}\\lua-5.4.4"
}
```
6. Install the following modules with the following command
   - `{LUAROCKS_ROOT}\luarocks install --lua-version=5.4 --tree={PATH_TO_LUA}\lua-5.4.4\modules {module}`
   - luasocket
   - luafilesystem
7. Copy the modules to `{PATH_TO_LUA}\ZeroBraneStudio\bin\clibs54`

Scratch all of this, the server is built on lua 5.1 ...
Just set zerobrane to the default lua interpreter and run server.lua

## Lua style guide
http://lua-users.org/wiki/LuaStyleGuide
https://github.com/luarocks/lua-style-guide

## Lua docs
https://stevedonovan.github.io/ldoc/

## luarocks tips
https://leafo.net/guides/customizing-the-luarocks-tree.html