<<<<<<<
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
=======
# Panel Attack Development

## Development Setup

Install the **32-bit** version of love (http://love2d.org/)

Clone a copy of the repository  
```
git clone https://github.com/panel-attack/panel-attack.git
```  
We recommend using [GitHub Desktop](https://desktop.github.com) as it manages login for you and makes working with git easier.
  
We recommend developing and running the game using [Visual Studio Code](https://code.visualstudio.com/).  
You can setup VSCode with a debugger and more [following this tutorial](https://sheepolution.com/learn/book/bonus/vscode).

Alternatively, you can edit with your own favorite text editor and run love from the command line

```
cd Panel-Attack
love ./
```

or via drag and drop with the repository folder (not recommended).


## Repository

The beta branch is where we do all main development.  

All pull requests require a review by a maintainer (or 1 review and written by a maintainer).  
Feature and bug commits are done by maintainers using squash merges.  
Merges are done by the maintainers as merge commits.  


## Contributing

The best place to coordinate contributions is through the issue tracker and the [official Discord server](http://discord.panelattack.com).

If you have an idea, please reach out in the #pa-development channel of the discord or on github to make sure others agree and coordinate.

After coordinating with others, post pull requests against the `beta` branch. 

Try to follow the following code guidelines when contributing:
- Separate functionality into separate files that only interact with each other as much as needed
- Avoid globals
- Make smaller methods
- Don’t duplicate code, break it into smaller reusable chunks and use that in both spots
- Writing tests for how the code should work is extremely beneficial
- Follow the formatting guidelines below
- Constants should be local to a file / scope unless they need to be shared everywhere

## Formatting Guidelines

- Constants should be `ALL_CAPS_WITH_UNDERSCORES_BETWEEN_WORDS`
- Class names start with a capital like `BattleRoom`
- All other names use `camelCase`
- You should set your editor to use 2 spaces of identation. (not tabs)
- Set your column width to 1000
- All control flow like if and functions should be on multiple lines, not condensed into a single line. Putting it all on a single line can make it harder to follow the flow.

For those using VSCode we recommend using this [styling extension](https://marketplace.visualstudio.com/items?itemName=Koihik.vscode-lua-format) with the configuration file in the repository named VsCodeStyleConfig.lua-format

## Release schedule

**Beginning of the month:**  
beta feature development followed by a release

**Mid month:**  
Stop landing new features and only add bug fixes

**After last tournament of the month:**  
Merge beta into stable and release
Hot fix stable as needed

Release notes are posted in #panel-attack-updates on the discord when updates go out.


## Useful Lua Programming Tips

**Big comment**  
```Lua
--[[
--]]
```

**Comment parameter names inline**
```Lua
  return self:pop_all_ready_garbage(frame, true--[[just_peeking]])
```

Lua Manual  
https://www.lua.org/pil/contents.html  

Love2d Tutorial  
https://sheepolution.com/learn/book/contents



# For Maintainers

## Releasing

To make a release we create a love file and put it on the server. Change the name of the love file to the output of a command like this:  
    Stable:  
        `echo "panel-$(date -u "+%Y-%m-%d_%H-%M-%S").love"`  
    Beta:  
        `echo "panel-beta-$(date -u "+%Y-%m-%d_%H-%M-%S").love"`  

Secure copy the file to the server in correct folder on the server.  
    Stable:  
        `scp -i privatekey.pem panel-2022-06-25_03-50-14.love username@panelattack.com:updates`  
    Beta:  
        `scp -i privatekey.pem panel-2022-06-25_03-50-14.love username@panelattack.com:beta-updates`  

Test that the game updates properly.  

Post release notes in #panel-attack-updates on the discord.

### Releasing a new full release with auto updating

First make a love file, then copy that all into the auto updater folder and make that a love file.  
Then copy the windows files in to your release folder.  
Tack the autoupdater love file on the end of the exe.  
Release a zip of the whole release directory.  

More details and scripts to follow.


>>>>>>>