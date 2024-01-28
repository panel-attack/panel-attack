# Understanding the Panel Attack Codebase
(Endaris Version 1.1)

In general following the sheepolution tutorial up to maybe chapter 12 is a decent idea:
https://sheepolution.com/learn/book/contents  
If you already know some programming, skim the parts that are common to programming languages (variables, functions, if, for etc., read the parts on tables and classes carefully though)

## Game Start

Every love project starts in main.lua (except not, it actually starts in conf.lua where we load/set the configuration for the game and which löve modules we want to use; main is loaded right after)
PA consists of 3 projects:
The auto_updater (that lives in the auto_updater folder of the repository) and the main game (most of everything else). There is also the server living (mostly) in the server folder but I'm not as familiar with that, so no comment.

What most users start PA with is not the main game but the auto_updater. The auto_updater downloads the most recent version from the web or copies its embedded version to the save directory into the updater folder. Then it loads up the main game from there as a replacement of the auto_updater.  
When developing we typically pay the auto_updater no mind but it should be noted that globals loaded inside of the auto_updater stay loaded upon starting the maingame which may cause conflicts in some cases (e.g. both auto_updater and main game have a global definition for `class`).  

## main.lua

In the main.lua we define the 2 most important functions to run our love game: `love.update` and `love.draw`.  
These look fairly small because the sum of their stuff is packed into effectively all the other files.  
Which is why we're importing about all of them (almost) immediately via `require`.

### Drawing

PA does almost all of its drawing by way of a graphics queue.  
That means that there is a global table called `gfx_q`. When we want to draw something anywhere, we can add the function call for our drawing function among with its arguments to the queuen via `gfx_q.push`. These function calls will then get unpacked inside of `love.draw` and called FIFO, then the queue is cleared.  
What we push are typically big functions like `Match.render`. This is because the tables added to the graphics queue are throwaway tables that the "meh" Lua garbage collector needs to clean up. If there are many pushes - and thus many throwaway tables - this can result in massive frame spikes when these tables are collected.  
Unless you are adding a completely new screen, you should avoid pushing to the `gfx_q` directly. Instead, use the functions inside of `graphics_util` as they already make a distinction for whether to push or to draw directly based on the `GAME.isDrawing` flag.


### Update

In `love.load` we define a so called coroutine (threads but not really) for our mainloop.  
Some stuffs aside, all that `love.update` contains is that it resumes the coroutine.  

#### Coroutines

We need coroutines to keep the game responsive. In `CustomRun.lua` we call `update` and `draw` in an endless loop, passing in the argument `dt` how much time has passed since the loop last ran.
If `update` runs for a very long time (for example because we load all of our mods or replays), the game will effectively be frozen and uninteractable until that finishes because it delays th call to `draw`. To circumvent that, we have our mainloop coroutine in `update` and separate coroutines in other asset loading places. Whenever something inside of a coroutine calls `coroutine.yield`, the code running inside of that coroutine is paused and will only get resumed once calling `coroutine.resume` on it. That's effectively how we get to reliably draw things and have our window not go irresponsive until our OS tells us that Panel Attack is not reacting and whether we want to close it.  

#### Mainloop, menus and screens

So our main coroutine turns out to be the function `fmainloop` in `mainloop.lua`.  
What this function does (after some initial setup stuff) is to run our "game loop", that's the `while true` at the end of it.  
We start by defining `func` as the title screen.
Then inside of that game loop, func is being called and we go into `main_title`.  
But look there, another `while true`!  
Right, every single menu function has its own `while true` loop so they can keep adding their draw stuff to the graphics queue while waiting for user input to do something.  
At the end of every `while true` loop we always `yield` to stay responsive.  
Until eventually something will lead to them returning a function + argument in a return:  
This return will then get unpacked again by the top-most loop in fmainloop and whatever function was passed will get called again. Through this mechanism, all the different menus/screens connect with each other to make up the structure you know in PA.  

WE'RE ON TRACK FOR KILLING ALL THESE NESTED GAMELOOPS WITH FIRE, just be patient for a bit longer.

##### Simple menus

Most menus basically just consist of a Menu thrown together with some buttons. A `Menu` as defined in `ui/Menu.lua` is basically an easy way to provide some simple button menu with select options. At least one of your buttons should throw you back to where you came from though.  

##### Select screen

Basically the only dedicated screen besides the click menu. Living in the `select_screen` subfolder it is an amalgamation of many things. Entering through the `select_screen.main` method with information about which mode we want to play, the select_screen does all sorts of setup, character loading, server communication and everything else to prepare your match. Not hard to guess, the drawing part is separated into `select_screen_graphics` making it a bit less of a hell to navigate than it once was.  
There is some semblance of documentation for the server communication in the netplay.md file so read that the moment you have to do anything related to server communication to get a bit of an idea.

SELECT SCREEN IS CURRENTLY GETTING A PARTIAL REWRITE

##### Replay Browser

The replay browser is the only big menu in the game without touch support. Bad. We're likely going to rewrite it after the UI rework. To none's surprise this lives inside of `replay_browser.lua`.

##### Game screen

Effectively through whatever method you are going to initiate a game, it will create a `match` table based on `match.lua` on the `GAME` global (that holds basic game information plus a bit more). The match has its own `render` method and inside of that it renders the stack(s) that also have their render methods but we'll learn a lot more about stacks shortly anyway.

## Mods and Assets

On game start we load all our mods once in a superficial manner (except for the theme which we load fully).  
In select_screen we load the panels, characters and stages that are actually being used by the player(s).  
Every single asset type has its own file that specifies what properties that thing has and how it is getting loaded. Additionally, characters and stages have an extra "loader" file, aimed at providing (global) utilities for loading and unloading mods on the fly and wherever you want which is relevant for both resizing your game (for reloading stuff in the correct resolution) and switching characters in select_screen.  
Additionally there is a magic method inside of select_screen.lua (although it's also used for watching replays) called `refreshBasedOnOwnMods` that runs through a routine to replace an opponent's character/stage/panel selection with a mod you actually have in case you don't have theirs.  
Access on assets typically happens by assigning the mod either to a stack or the global `config` of the player and are then used in the respect draws.  
Finally there are typically some extra globals for giving access to all the mods and mod-ids there are by type.

As selectScreen is being rewritten so is getting `refreshBasedOnOwnMods` being phased out due to some problems.


## The cursed engine

Honestly, it used to be a lot worse but it's still very intimidating.  
The bulk of this lives in engine.lua but there a substantial part of it already moved into separate files inside the engine folder.  
engine.lua effectively defines all of the logic for things that happen on a stack, like swapping, stack raising, managing music, playing SFX, sending garbage to the garbage queue of the garbage_target if there is one, saving and applying rollbacks and whatnot.  
In the engine folder itself, the file names are sort of a give-away for what part of engine is inside:
 - checkMatches.lua contains the logic for checking the board for matches and updating all involved channels
 - panel.lua defines the panel, its fields and states and most importantly all of its state transformations
 - GarbageQueue.lua and telegraph.lua are components used for managing attacks and garbage that are still on their way. These are mentioned together because they are still a bit functionally entangled; ideally telegraph would be a pure observer of the garbage queue that is only responsible for graphics.
 - TouchInputController specifies how the stack interacts with touch inputs and TouchDataEncoding specifies how it is sent over network in the case of multiplayer. This is functional but not enabled yet.

As a short version for understanding "roughly" what is going on in the enginie:  
A stack is getting constructed via the constructor `Stack = class(... etc)`.  
Via `input.lua`, there are inputs injected to the stack via `receiveConfirmedInput` by the `match` that controls the stack and checks our input tables.
Then the stack runs via `Stack.run` that calls the heart of the engine called `Stack.simulate`. All other methods in the engine are basically used by that method in one or another way or it's something only relevant to puzzles (don't get me started) or some functions used to get some info about the stack from other places (like dumping a stack into puzzle form).  
If you read the comments for `simulate`, you may notice a suspicious absence of phase 1 and 2, mostly because they already got extracted into separate functions. There is still a good amount of extracting functions to be done, especially for SFX/Music.  

One of the greatest thing about the Stack class is that it doesn't end in engine. The bulk of graphics-related stuff is found in `graphics.lua` and some extra stuff in `network.lua` for processing taunts and sending your inputs to the server.

## Localization

We have a cool localization.csv file. In the first column is the codename of a string, then the traductions into the different languages.  
When adding text to the game, we usually reference it by `loc(codename)` so that the loc function can automatically fetch the correct string based on the language configuration.

## Third party libraries

### dkjson.lua

An external library for serializing lua tables into json-like strings and vice versa. No touchy.

## Everything else I haven't talked about

### analytics.lua

Responsible for tracking analytics. Typically a stack will own an analytics instance in its `analytics` field and from there the graphics functions of the stack will display them. Analytics are always on even if disabled in the config so they can get written to the local analytics.json/analytics.txt file that track all time statistic (assuming bug-free, haha). Unlike most other io writes, analytics.lua actually writes to the file itself.

### save.lua

Basically accumulates file functions for various areas of the game, e.g. loading and saving puzzles, your server id, attack files, saving replays, but also some generic functions for copying.

### AttackEngine.lua

Has functions to construct an attack engine, add attacks to it and run it on the stack it was constructed with. Used in training mode.

### AttackFileGenerator.lua

This is to dump attack information from a real game at game-over into an attack file that can be used in 1p training.  

### BattleRoom.lua

This is effectively a slim data representation of select_screen that lives on the `GAME` global. Tracks information about the players, win counts, ranked, that kind of stuff.

### ChallengeMode.lua, ChallengeStage.lua, Health.lua

Everything challenge mode, uses AttackEngine for its attacks.

### class.lua

Allows us to pretend that tables are classes.  
Defining a class such as
```Lua
Sample = class(function(self, sampleNumber)
  self.msg = "I'm a sample nr " .. sampleNumber
  -- do something with your args
end)
```
allows us to create a table as specified in the function passed as an argument to class:
```Lua
local samples = {}
for i=1,5 do 
  sample[i] = Sample(i)
end
```
Additionally we can create class functions like this:
`function Sample.someFunction() end`  
Note that class functions innately cannot be local because they are defined on the table and therefore have their scope defined by the table itself.

### computerPlayers

This has its own doc, go, read it

### config.lua

Holds default configuration data and functions to read and write them from disk (config.json)

### consts.lua

All the happy unchanging frame, garbage and score data we need to access once in a while (mostly in engine).

### csprng.lua

Don't ask me, I think the server uses this and it hasn't made its way into the folder yet.

### CustomRun.lua

CustomRun defines its own implementation for the `love.run` function that is called by love as its standard gameloop.  
CustomRun allows us to collect more diagnostic data, in part via a pretty graph that activates when activating debug mode and turning FPS count on.  
`love.run` needs to be overwritten before it is first called which is why the auto_updater overwrites it too, allowing the maingame to later inject its own gameloop via overwriting `pa_runInternal`.  
As the main gameloop, CustomRun is also responsible for capping the game to 60 FPS.

### developer.lua

This activates the debugger if the `debug` argument was passed.  
When using ZeroBrane Studio you will want to replace the `lldebugger` part with this:  
```Lua
  io.stdout:setvbuf("no")
  require("mobdebug").start()
  require("mobdebug").coro() 
```
Additionally determines if tests or performance tests should be run. The latter can only be run if tests are activated as well. You can check the list of available tests easily by searching for the `TESTS_ENABLED` variable via ctrl+shift+f.

### FileUtil.lua

Provides some extra things for loading files, e.g. a standard filter for MacOS filesystem files.

### game.lua

Mostly self-documenting I think, going forward this will replace the coroutine fiesta for our screens.

### gen_panels.lua

Algorithm for generating panels - usually generates a whole screenfull at once and then refills when necessary.

### globals.lua

Holds various globals we're using. We kind of want to make this smaller but it's difficult.

### graphics_util

Contains various helper functions for graphics. For example stores the font in different sizes for cheap reusage and manages quads for drawing parts of tilemaps (check the lovewiki for quads if you don't know what they are)

### input.lua

Joystick interpretation lives here and keyboard/mouse/touch inputs get tracked.

### logger.lua

Writes to warnings.txt depending on logging level. We honestly don't log a whole lot.

### network.lua

Besides the things already mentioned, has functions for receiving messages and adding them to the global `server_queue`.

### NetworkProtocol.lua

A more formal documentation of message types and various meta information about messages.  
Used by both server and client.

### profiler.lua

Some magical tool that can be used with a commandline argument to find out which functions need what part of CPU time to run.  
Note that it has some quirks, in some profiling runs, UI functions will randomly show up and pretend to take a lot of CPU time so ignore those. For non-drawing functions it seems to work well though.

### Puzzle.lua

Various functions belonging to puzzle loading (color randomization, validation)

### puzzles.lua

Loads and writes puzzle files (near obsolete tbh)

### PuzzleSet.lua

A class that wraps a table of puzzles (near obsolete tbh)

### queue.lua

Message queue used for both graphics and server messages.

### replay.lua

Code for loading replays from disk until they're ready for replay.

### rich_presence folder

Makes it so that Discord provides more detailed information about what we are doing in panel attack.

### RunTimeGraph.lua

For debug mode, used by CustomRun.

### scores.lua

Tracks records for time attack, endless, 1p vs self and reads/writes them to/from scores.json.

### server files

Don't ask me.

### socket folder

Also server

### sound.lua

Contains generic functions pertaining to both sounds and SFX (such as volume control, stopping all audio)

### sound_util.lua

Actually not that different in character from sound.lua

### table_util.lua

Provides various helper functions to make tables easier to manage.

### TimeQueue.lua

A queue used for networking.

### timezones.lua

It's in the name, time related stuff

### UpdatingImage.lua

Image class with functions that support animations to some degree

### util.lua

Various helper functions for common problems.