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
- Avoid the use of shortlived tables and consider pooling if you can't

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

# Windows Setup
This guide assume you are using `{PATH_TO_LUA}` as the root directory for all files unless otherwise specified
1. Install visual studio 2022
   - https://visualstudio.microsoft.com/downloads/
   - The following commands will assume you are using the x86 Native Tools Command Prompt for VS 2022
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
1. Download luaJIT 2.1
   - https://github.com/LuaJIT/LuaJIT
2. Compile lua with a windows make file
   - With the above repo from the `{PATH_TO_LUA}\luaJIT2.1\src` directory run:
     -  `msvcbuild`
     - Make the following directories under `{PATH_TO_LUA}\luaJIT2.1` and move the corresponding files in them:
       - bin: lua51.dll, luajit.exe
       - include: 
       - lib: lua51.lib, luajit.lib
3. Setup zerobrane for luaJIT
	- Copy the following
		-  `{PATH_TO_LUA}\luaJIT2.1\bin\luajit.exe` -> `{PATH_TO_LUA}\ZeroBraneStudio\bin\luajit.exe`
		- `{PATH_TO_LUA}\luaJIT2.1\bin\lua51.dll` -> `{PATH_TO_LUA}\ZeroBraneStudio\bin\lua51.dll`
	- Write the following to `{PATH_TO_LUA}\ZeroBraneStudio\interpreters\luadebjit21.lua`
```
dofile 'interpreters/luabase.lua'
return MakeLuaInterpreter('jit', 'JIT 2.1')
```

4. Download luarocks
   - http://luarocks.github.io/luarocks/releases/
5. Link rocks to lua
   - Write the following to `C:\Users\{USER}\AppData\Roaming\LuaRocks\config-5.1.lua`
```
lua_interpreter = "luajit.exe"
variables = {
   LUA_BINDIR = "D:\\Lua\\LuaJIT-2.1\\bin",
   LUA_INCDIR = "D:\\Lua\\LuaJIT-2.1\\include",
   LUA_LIBDIR = "D:\\Lua\\LuaJIT-2.1\\lib",
   LUA_DIR = "D:\\Lua\\LuaJIT-2.1"
}
```
6. Install the following modules with the following command
   - `{LUAROCKS_ROOT}\luarocks install --lua-version=5.1 --tree={PATH_TO_LUA}\luaJIT-2.1\modules {module}`
     - luasocket
     - luafilesystem
     - lsqlite3
       - download tcl (this is only needed to compile sqlite3 you can delete afterwards): http://www.tcl.tk/
	     - for ease of use place in root directory (aka, C:\ or D:\)
	     - from `{TCL_ROOT}/win` directory, install with the following commands
         - `nmake -f makefile.vc INSTALLDIR=path_to_your_install_dir`
         - `nmake -f makefile.vc install INSTALLDIR={PATH_TO_LUA}\sqlite3`
         - move the contents of `{PATH_TO_LUA}\sqlite3\bin` up a directory
         - rename `{PATH_TO_LUA}\sqlite3\tclsh84.exe` to `tclsh.exe`
        - download sqlite3 (check for the latest version under tags):
	        - https://github.com/sqlite/sqlite/tree/master
	        - from `{PATH_TO_LUA}\sqlite3` run:
		      - `nmake /f {PATH_TO_LUA}\sqlite-version-{VERSION}\Makefile.msc TOP={PATH_TO_LUA}\sqlite-version-{VERSION}`
		    - move all .h files into the includes folder 
        - use this command to install lsqlite3 instead:
	      - `{LUAROCKS_ROOT}\luarocks --lua-version 5.1 --tree={PATH_TO_LUA}\luaJIT-2.1\modules install lsqlite3 SQLITE_DIR={PATH_TO_LUA}\sqlite3`
7. Copy the modules to `{PATH_TO_LUA}\ZeroBraneStudio\bin\clibs54`
	- note in order lsqlite3.dll to work the lua.exe needs to be next to the sqlite3.dll

run serverLauncher.lua

## Lua style guide
http://lua-users.org/wiki/LuaStyleGuide
https://github.com/luarocks/lua-style-guide

## Lua docs
https://stevedonovan.github.io/ldoc/

## luarocks tips
https://leafo.net/guides/customizing-the-luarocks-tree.html
