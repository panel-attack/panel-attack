
How to run your own panel attack server:

install luajit
on linux, I think this is as simple as sudo apt-get install luajit
on windows, I think you have to build the binary yourself.  Takes some googling and effort.

on linux you may need to install lua (version 5.1 should be ok, though I think 5.3 works too).  The repository includes a lua binary for windows.

to start the server, run at the terminal or command prompt:
luajit server.lua

It will probably complain about missing files. 
in the directory you are running the command you should have the following files (this list may have more or less than is required. THIS README NEEDS REVISION!). you should be able to find these in the github repository for panel attack, but note that problems happen if you just dump the whole repository into your folder.  For example, I think there are conflicts if you have globals.lua in there.


In the root of your chosen panel attack server folder

class.lua
csprng.lua
dkjson.lua
gen_panels.lua
save.lua
server.lua
server.py
server_file_io.lua
socket.lua
stridx.lua
timezones.lua
util.lua

Note: for these next few, look in the folders like "luapower lfs for win64 server"
lfs.dll (on windows)
lfs.so (on linux)
lua51.dll (on windows)
socket/core.so (on linux, make a folder for socket and put core.so in there)

it may still complain about missing files.  Try to figure out from the error message what you are missing.


If you want to host your own server with ranking, be sure to change your csprng_seed.txt file, or your users' user_ids will be less secure.

Once you have a server up and running, you'll want to change mainloop.lua, around where it says something like

{"2P vs online at Jon's server", main_net_vs_setup, {"18.188.43.50"}},

to something that makes sense for your server.  (replace "Jon's server", and the IP. Using a URL here instead is ok)

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
