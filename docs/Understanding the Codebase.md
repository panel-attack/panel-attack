# Understanding the Panel Attack Codebase (the short version)
This version seeks to be more brief and on-point for people familiar with lua/love and the game itself (as a player).  

The codebase combines code used for the client and the server. Code used by both or that is anticipated to be used by both is located in the `common` folder.  
Although not yet a reality, the goal is for files in the common folder to have no references to files in the server/client folders respectively. The only exception to this should be test cases that may use client I/O to load replays, puzzles and configurations as test data.

The server has a separate documentation so this document mainly deals with the client architecture.

A `Scene` is the overarching concept of a thing that manages what you see on a screen, what you hear on a screen and how you can interact with that screen.  
`Scene`s are managed by a `NavigationStack` via pop, push and pull operations with only the top-most `Scene` being active.

To play games, a `BattleRoom` is created in which a bunch of `Player`s can modify their settings and eventually all ready up.
Based on the settings of the `BattleRoom` itself, a `Match` is created which in turn creates `Stack`s based on the settings of the `Player`s, forming a hierarchic architecture in which the components further down the bottom ideally know nothing of the elements above.  
`BattleRoom`, `Player`, `Match` and `Stack` are the key points with `Player` and `Stack` both having base classes `MatchPartipant` and `StackBase` that define the interface for `BattleRoom` and `Match` to use them.  
This concept extends to replays where generally the settings of `Match` and `Player`s are saved on top of the inputs.

# Understanding the Panel Attack Codebase (the long version)
This is a subjective and informal take by Endaris.

## Understanding Lua and Love
In general following the sheepolution tutorial up to maybe chapter 12 is a decent idea:
https://sheepolution.com/learn/book/contents  
There is also a video format but I didn't watch it so I can't vouch for its quality.  
Text is better for learning and backreferencing.

### Understanding Lua
If you already know some programming, you can skim some parts if you are familiar with the concepts from other languages:
- variables, if you're familiar with a dynamically typed language
- functions, if you're familiar with a language that has first class functions
- if/for, if you're familiar with any scripting or programming language

You definitely want to read up very closely on:
- tables and by extension classes; classes are not a native concept in Lua but it's possible to realize something like classes via tables
- coroutines, not used terribly often in Panel Atack but a concept that feels a bit more Lua specific

#### table
Still read the tutorial, I'll just make some additions that I personally consider interesting to know about.
A table is an array and dictionary at once and is the monolithic data type on which basically all of Lua is built.  
Functions in a "class" in Lua are ultimately just regular fields on a table that happen to contain a function.  
This means that functions can be freely overwritten on individual tables - whether that is a good idea or not is questionable but it is possible and in some cases extraordinarily useful.


### Understanding Love
Love is a game development framework that provides bindings to SDL and various other crossplatform libraries, allowing us to easily deliver the same build for every platform - provided they have the autoupdater installed in case of windows (it contains a love.exe) or love installed separately on any other OS.  

In Panel Attack, there are mainly 3 important things to understand about love:
- the gameloop
- the callbacks
- the modules

#### The Gameloop

The gameloop of love is effectively
```Lua
while true do
  love.run()
end
```

love.run is a function with a standard implementation. Panel Attack overwrites this function with a similar but for diagnosis and garbage collection purposes modified function inside of the file `CustomRun`.  
Studying either that or https://love2d.org/wiki/love.run is a great idea to get a general understanding of how the loop works.  
In the case of Panel Attack, unlike in the default version, the loop is inherently locked to a certain frame rate, ordinarily 60 FPS.

#### The callbacks

If you looked at the gameloop, you should have noticed the somewhat cryptic seeming part with `love.handlers` and some `a, b, c, d, e, f` variables.  
This is love pumping events to its callbacks.  
Love provides a handful of useful callbacks, mostly related to user interaction such as `love.keypressed`, `love.joystickadded` or `love.resize` but also some related to things happening in the code, most prominently `love.errorhandler`.  
These callbacks are collectively executed at the start of the frame so that all inputs during the last frame are available.  
For Panel Attack, all love callbacks should be implemented in `main.lua`.

#### The modules

While love has a lot of functionality like a physics system, only some of that is used in Panel Attack.  
Love modules are loaded in `conf.lua` and only loaded modules are usable.  
Panel Attack uses most of the more standard modules. Most of these modules are quite basic with the exception of the `graphics` module which offers way more functionality than Panel Attack currently uses.  
Overall it is relatively easy to guess what a love function does if you see it in context and many of them are also wrapped inside of our own functions so that it's often not that necessary to add new calls yourself.

## Game start

Distribution and development setup differs a bit.  
Panel Attack uses an auto updater that fetches updates from panelattack.com and then reinitializes itself by mounting the actual game in its place. It leaves behind a `GAME_UPDATER` global that offers functions to check for updates or restart with a different release stream.  
You can find the current updater at https://github.com/Endaris/panel-attack-updater with documentation.

## Broad Client Structure 

Panel Attack has many files, maybe too many and not all of them are in an intuitive place.  
At the core of Panel Attack lives the `Game` class defined in `Game.lua`.  
`Game` is practically the big global game object that has everything, is accessible from everywhere and handles the actual game loop + drawing.  
In the most recent version, Panel Attack uses a scene system governed by the `NavigationStack`.
This `NavigationStack` holds onto a table of scenes with the latest scene being the active one.
It provides various functions to alter that table to navigate between the scenes and add new ones.
A scene must be able to deal with user inputs and control audio and visuals and can have any level of complexity.  
In the current version of Panel Attack, the title screen is a single scene and so is the entire options menu (including sub menus). Character selection is also a single scene and so is ingame.  

Scenes can broadly be divided in 3 types of scenes:
- menu and configuration
- game setup
- ingame

### Menu and configuration
Menu and configuration obviously includes the main menu, options, setting your name, inputs and the replay browser.  
There is no real trick to these, it's either navigation or changing client settings.

### Game Setup
Game setup includes every menu that prepares a game and has players select their preferred settings before starting the game. So anything that lets you select speed, difficulty, level or character belongs to this.  
What is important to know is that all scenes belonging to these work with a `BattleRoom`.  

#### BattleRoom
The `BattleRoom` is the unified representation of game setup and the life cycle of a set of `Match`es. A `BattleRoom` may have one or more `MatchParticipant`s, it will always hold the constraints of the game mode the game is being set up for in its `mode` field and it generally governs everything about the experience of setting up and coordinating switches between setup scene and game scene to run a sequence of matches.  
If online, the BattleRoom (further defined in `network/BattleRoom.lua`) handles sending and receiving of network messages to update `MatchParticipant` settings and is also responsible for starting the game once everyone is ready.  

##### ChallengeMode
`ChallengeMode` inherits `BattleRoom` in order to control the life cycle of a set for its own purposes.  

#### MatchParticipant
The `MatchParticipant` represents the abstract concept of a participant in a `BattleRoom` that has a range of settings and can create a `Stack` or `SimulatedStack` with those settings.  
Alongside these settings the `MatchParticipant` also tracks data such as their win count.  
The `MatchParticipant` implements the outlines of an observer pattern to allow other objects to subscribe to updates on the settings of the `MatchParticipant`. 

##### Player
A `Player` is the specialization of `MatchParticipant` that represents (human) players with the full set of settings to create an actual `Stack` driven by the engine.  
They support a lot more settings and can be flagged as `isLocal = false` to mark them as remote players that get updated via the network component of `BattleRoom`. Respectively, local players will send changes of their settings to the server by having the network components subscribe to the `Player`'s settings, keeping the `Player` decoupled from all network activity.

##### ChallengeModePlayer
A `ChallengeModePlayer` is the specialization of `MatchParticipant` that represents the opposing player in a `ChallengeMode` to create a `SimulatedStack` that is driven solely with an `AttackEngine` and a `Health` engine.  
As they are mainly managed by the `ChallengeMode` itself they only implement the bare minimum to interface with `BattleRoom` and `Match`.

### Ingame
All actual ingame happening are operated on a `Match` that runs a certain number of `Stack`s or `SimulatedStack`s belonging to `MatchParticipant`s.  
`Stack`, `SimulatedStack` and `Match` are oblivious to the existence of `BattleRoom` and for every single game a new `Match` and new `Stack`s/`SimulatedStack`s are being created - the `Match` based on the game mode and the `Stack`s/`SimulatedStack`s based on the settings of the `MatchParticipant`s.

## The engine

The engine is located in the `common/engine` directory.
While currently only in use by the client, the goal is for the engine to become an independently versioned component that can be used by client and server alike, in the latter case for example to validate scores for online leaderboards.
The bulk of the game physics lives inside the `Stack` class which is defined in `Stack.lua` and derives from the conceptual minimum `StackBase` a table needs to implement to be run by a `Match`.  

The client extends engine classes like `Stack` and `Match` with graphics functions.  
While the engine, in particular StackBase still holds some graphics functions, the eventual goal is for all graphics functions to move to client. This is so the server - that doesn't use love - can run the engine as well.

### Stack.lua
`Stack.lua` contains the code for construction of `Stack`s, running them, performing rollback, creating new rows, various puzzle stuff and most of the physics that is not directly related to the behaviour of an individual `Panel`.  

### Panel.lua
The behaviour of individual `Panel`s is recorded in `Panel.lua`. Each panel on its own represents somewhat of a finite state machine that changes state based on its own state and the state of the panel below.  
However, the only state transformations for panels governed in this are those that happen passively and without player interaction.  
Via player interaction there are 2 more transformations possible that are handled on the `Stack` level instead of the `Panel` level:
- getting swapped (this is in `Stack.lua` again)
- getting matched

### checkMatches.lua
This file contains the entire routine for checking if there are any matches on the board.  
As a natural extension of that, it is also responsible for transforming garbage panels into regular panels and fetch new colors for that purpose from the `PanelGenerator`.  
Effectively it is just a small collection of `Stack` functions, isolated for better orientation within the repository.

### PanelGenerator.lua
In this file lives the Panel Generator which provides functions to generate panels for a certain seed via a pseudo random number generator and assign possible metal placements for these panels.

### client/src/network/Stack.lua
This small bit covers functions of Stack that have network activity such as taunt or sending inputs to an opponent.  
Ideally the network part of them will be performed by a dedicated network client in the future so that `Stack` has no knowledge of network.

### client/src/graphics/Stack.lua
This file contains entirely draw functions for the `Stack` besides the one defined in `common/engine/StackBase.lua`.

### Telegraph.lua and GarbageQueue.lua
These are strongly coupled classes that act as an intermediary between `Stack`s to transmit attacks from one `Stack` to another.  
They're currently performing much more calls to `deepcpy` than strictly necessary to do their job and a refactoring is in order once enough tests have been written to verify the behaviour of a new implementation.

### SimulatedStack.lua

A fake stack based on `StackBase` that can sport an AttackEngine and/or a HealthEngine to mimic a player without actually dealing with any of the complexity a fully fledged CPU player would require.  
Includes graphics functions.

### Match.lua
A match creates and runs the stacks, holding and applying the concrete game settings that aren't on `Stack`.  
As the controlling entity, the match is supposed to control all behaviours that involve more than one stack, such as changing music, playing countdown, determining whether a stack needs to save rollback copies or determining a winner.  
There are still some interactions inside of `Stack` that I would rather see on `Match`, such as sending garbage from the telegraph to another stack, applying rollback or determining if shock panels should be in the game via a different avenue than levelData itself.
The match will continue running stacks until either only one is left or until or done, depending on the given conditions for winning the match (see section about GameModes).

### client/src/graphics/match_graphics.lua
Graphics for rendering the match  
Some parts of rendering are instead taken care of by the scene running the Match and in the future it should ideally be most or all of it.

### GameModes.lua

This effectively holds presets for existing game modes in the game.  
In addition to game mode defining settings, they also contain which scene to use for setup and game.
In the current iteration GameModes are thought to be mainly defined by a set of 5 settings:  

#### Stack Interactions
Defining how the stacks interact with each other.  
The currently possible settings are  
- NONE, if garbage is not sent anywhere, nor is any received
- VERSUS, if garbage is sent to another stack and received from another stack
- SELF, if garbage is sent to yourself

#### Game Win Conditions
These define a set of zero or more conditions that cause a `Stack` to stop running as soon as one is met.  
The currently possible settings are  
- NO_MATCHABLE_PANELS, if there are no remaining panels of color 1-8
- NO_MATCHABLE_GARBAGE, if there is no unmatched garbage left on the board

#### Game Over Conditions
These define a set of zero or more conditions that cause a `Stack` to go game over as soon as one is met.  
The currently possible settings are  
- NEGATIVE_HEALTH, results in game over if `health` reaches 0
- NO_MOVES_LEFT, results in game over if the amount of available moves for a puzzle has been met
- CHAIN_DROPPED, results in game over if the active chain was dropped

#### Match Win Conditions
These define a set of zero or more conditions to determine a winner between multiple Stacks inside a Match.  
The currently possible settings are  
- LAST_ALIVE, the last stack alive wins, typically used with no conditions for game win on the Stack level
- SCORE, the stack with the highest score wins
- TIME, the stack with the lowest clock time wins

Match win conditions are order sensitive and are evaluated until the last one while a tie is present.  
Example:  
In a hypothetical 99999 point race capped to 10 minutes with the match win condition { SCORE, LAST_ALIVE, TIME }, player 1 and player 2 manage to reach 99999 points before time is up, player 3 self destructs at 72000 points before time is up while player 4 only manages to reach 43000 points when time is up.
First SCORE is evaluated. Player 3 and player 4 are both eliminated as potential winners because player 1 and 2 beat them in points.  
Second LAST_ALIVE is evaluated. Both player 1 and 2 finished in a winning state so they aren't game over, they are still tied.  
Finally TIME is evaluated, player 2 has a lower clock time than player 1 so they are determined winner.  
In the future each condition should also act as a tiebreaker so that player 3 would be determined to beat player 4 because they win in the score win condition.

#### Stack behaviours
Stack possesses certain behaviour flags under its `behaviours` table that can toggle major functions.  
Currently available toggles are  
- passiveRaise, controls if the Stack will passively rise from the bottom
If disabled, the player cannot lose health from being topped out.  
The NEGATIVE_HEALTH condition may still be met by manually raising while topped out.
- allowManualRaise, controls if Raise input can be used to manually raise the stack

At the moment Stack behaviours are only applied by way of setting a puzzle.  
As different puzzle types may have different needs for these (e.g. clear puzzles needing death), this is currently not preset for any GameMode preset and they're always assumed until toggled off by setting a puzzle.

### Summary

As a short version for understanding "roughly" what is going on as part of a single player match:  
Inside of a `BattleRoom`, after the `Player` has readied up a `Match` is being created and started.  
In the start process, a `Stack` is being constructed via the constructor `Stack = class(... etc)` based on the `Player`'s settings.  
Every frame, `Match.run()` is called on the game scene which in turn calls `run` on the `Stack`.  
Via `inputManager.lua`, there are inputs injected to the `Stack`'s `input_buffer` via `receiveConfirmedInput`.
`Stack.run` applies the input as part of `Stack.simulate` and advances its state by one frame.  
If you read the comments for `Stack.simulate`, you may notice a suspicious absence of phase 1 and 2, mostly because they already got extracted into separate functions. There is still a good amount of extracting functions to be done, especially for SFX/Music.  

## The user interface

Effectively there are two big new things in the new user interface that comes with the scene refactor:
- everything is navigable with touch (shush replay browser)
- everything is organized within a composite tree of `UIElement`

### Touch

Touch is implemented via the pair of `ui/touchHandler.lua` and `ui/UIElement.lua`.  
UiElements that should support touch are automatically considered touchable by implementing at least one of the functions `onTouch`, `onDrag`, `onHold` and `onRelease`.
All scenes have an `uiRoot` that is traversed by the touch handler through `UIElement:getTouchedElement` and only children of the active scene's uiRoot are active for touch.  

### UIElement composite

For general menu design, UIElements should be used.  
There is a lot to say about UIElements and nothing at the same time.  
There are some generic UIElements with very basic functionality such as Button, Label, Slider, Stepper.  
There are some UIElements for layouting such as Grid or StackPanel.  
There are some rather specific UIElements for certain purposes such as LevelSlider, StageCarousel or MultiPlayerSelectionWrapper.  
Via UIElement the composite tree supports the use of alignments and horizontal and vertical fill flags to automatically position and size a UIElement relative to its parent.  
For example to have an element centered within its parent you would choose `hAlign = "center"`, `vAlign = "center"`, `x = 0`, `y = 0`.
Note that this comes with some limitations, e.g. if your top level element does not specify a width and the child wants to horizontally fill its parent, this won't work, even if children of the child have a size they would want to fill out. Meaning to say, the top level element in a tree needs sane settings for x, y, width, height and may not use any of the align/fill settings.  
This is realised on `Scene`s by having a standard `uiRoot` which is just a basic UIElement with canvas size that provides a container to add all other UIElements to.

If you can, don't use `Menu` for now, a menu redesign is planned and it will very likely die with it.  

#### Internal working

The way the relative positioning works is that each element has its `drawSelf` function.  
Each element is called via `UIElement.draw` however which first calls `drawSelf` and then calls the predefined `UIElement.drawChildren` that manages the offset for each child with the alignment before calling `draw` on it.  
This mechanism is mainly intended for the children to be able to be drawn on their own without relying on their parent.  
While this is the default, both `draw` and `drawChildren` can be overwritten for a certain element to have it exert more fine control over how its children are drawn.  
Given that functions are overridable on ANY table, even individual ones, it is however also possible to simply overwrite the respective child's `drawSelf` function to rely on its parent instead which can be the easier approach as it allows use of alignments + relative offset without extra setup.

## Localization

We have a cool localization.csv file. In the first column is the codename of a string, then the traductions into the different languages.  
When adding text to the game, we can reference it by `loc(codename)` so that the loc function can automatically fetch the correct string based on the language configuration.  
For text that is properly embedded within the new UI structure, `Label`s are used for display. `Label` possesses a `translate` attribute that defaults to `true` if not explicitly passed as `false` so that the codenames for the strings can often be passed directly.  
If there are placeholders in a localized string, the `replacements` field can be passed with the values that should be used as replacements.  
If you add new localization entries please make sure to **always** add them at the bottom. There is a google doc we pull from where non-developers can submit changes / new localizations and it spoils any syncing attempt if we get new entries in the middle of the file.

## Mods and Assets
The default assets can be found in the `client/assets folder`.  
`client/assets/default_data` contains mods that ship with the game while the other directories contain fallbacks for user mods that don't provide certain assets.
Each graphic asset type has its own file for managing the loading process in `client/src/mods`:  
`Character.lua`, `Panels.lua`, `Stages.lua` and `Theme.lua` with characters and stages having a dedicated `CharacterLoader.lua` and `StageLoader.lua` to lazy load new assets on the fly. Panels and themes don't need this as panels always get loaded fully due to their small size and only a single theme can be loaded at a time.  
For characters, panels and stages, a table with id by index and a table with the actual mod by id is created for global access.  

### Mod loading
PA has a (still experimental) `ModController` component that tries to automatically load balance the loaded mods.  
`ModController:loadModFor` is a function that lazy loads a mod for a certain user (this can be a player or match) and holds a table with mods that have been loaded.  
Additionally each mod also holds by who it is loaded via weak tables.  
The `ModController` tries to unload any mod not associated with a certain user during its updates, keeping asset use low.

## Utilities

Panel Attack uses various more or less generic helpers to deal with things.  
These are a bit strewn all over the code base so I'll summarize them here.

### client side

Client side helpers are considered that because they innately rely on love functions and thus aren't usable by non-love components like the server.

#### FileUtils.lua

Provides various helper functions around I/O access using the love.filesystem module.


#### BarGraph.lua

Draws a bar graph used for per frame value display in debug mode with FPS counter activated (see RunTimeGraph.lua)

### [batteries](https://github.com/1bardesign/batteries)

A powerful library seeking to fill in the huge gaps in Lua's own standard library.  
In Panel Attack we only use the standalone `manual_gc.lua` which offers some functionality for manually collecting garbage on the client.

### common

This includes some helpers written for Panel Attack but also third party libraries.

#### tableUtils.lua
A collection of functions specifically to work with Lua tables.

#### util.lua
A rather random assortment of utility functions.

#### class.lua
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

Classes support inheritance for their constructor but child classes have no direct access to the functions of their parent classes if they overwrote their functions (e.g. no `super:print()`).

#### queue.lua and by extension server_queue.lua and TimeQueue.lua

A queue is a numerically indexed table that works via the first-in-first-out principle.  
Other than a regularly indexed table it cannot be iterated with ipairs as it does not shift queue entries down by an index after removing an element. This is mainly a performance concern as `table.remove(t, 1)` is quite expensive performancewise on bigger tables.  
On any persistent table within engine that has entries removed from the front, `queue.lua` should be used.  

`server_queue.lua` uses a similar approach albeit under the premise that elements may get removed from anywhere in the queue, not just the front. The name is misleading and mostly owed to the original creation for queueing incoming server messages.

`TimeQueue.lua` does not queue by index but instead by time. Its primary objective is to schedule or delay events pushed to it for later usage. At the moment it is only being used with its delay function for behaviour testing with delayed message processing of the `TcpClient`.

## Libraries

Panel Attack has picked up some libraries for various purposes, below a short summary what each can be used for and is being used for.

### lsqlite

This is currently only used on the server.  
With the lsqlite library we can access a sqlite database to persist and query data relevant to the server.


### dkjson.lua

An external library for serializing lua tables into json-like strings and vice versa. Don't touch this. This supports some cases that don't fulfill the .json spec and "fixing" those cases would break any mods "relying" on these behaviour quirks.

### simplecsv.lua

A csv parser, only used by the server. For the leaderboard if I recall correctly.
Avoid requiring this anywhere else, we'll only want .json or .sqlite as future file formats.

## Server

See README in server folder

## client/src/network

The network folder primarily hosts files that deal with network on the client side.  
This may include network components of classes that are not primarily network oriented.  

### ClientProtocol.lua

Presents getters for all messages the client may proactively send to the server

### ServerMessages.lua

Provides sanitization in format for messages the server may send to the client.  
Along with ClientProtocol.lua this serves as an extra level of abstraction so that the client internals don't have to match whatever the server sends and vice versa.

### LoginRoutine.lua

Provides a coroutine wrapper for the login process.

### Request and Response

Generic classes for network requests.  
Get a request message from `ClientProtocol.lua`.  
Send it off with `TcpClient:sendRequest`.  
If the request has an expected response, this will return a Response table that can be polled via `tryGetValue()` until a response was received (or a timeout was met).  
See the comments for `Response:tryGetValue()` to see how to interpret return values.

### TcpClient

Where all the network magic actually happens. Uses luasocket.

### MessageListener

Listen to one specific server message on the TcpClient's incoming message queue.

### NetworkProtocol

Contract between client and server for message types and protocol version.