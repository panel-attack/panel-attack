You can also find this file with prettier formatting at 
https://github.com/panel-attack/panel-attack/blob/beta/docs/themes.md  

This README consists of 2 parts.  
In part 1 some general thoughts on theme creation are discussed.  
In part 2 you can find an exhaustive list of all assets used for theme.  

# How to approach theme creation

## Graphics 

Theme creation is quite different from the creation of other mods.  
Unlike with characters or stages where you provide assets that will go into one exact spot with one exact resolution, themes don't limit you as much in regards to position and scale of assets.  
Various files in fact do not have a specific size or aspect ratio but merely a configurable anchor point to place them.  
Due to this, it is required for theme assets that you specify in the configuration how a graphic should be scaled.  
If no configuration is given, standard values from the default theme will be used.  
You can find the default configuration at  
https://github.com/panel-attack/panel-attack/blob/beta/themes/Panel%20Attack%20Modern/config.json  

You can use the Ctrl+Shift+Alt+T shortcut to reload your theme configuration and graphics in the game.

## Version
Themes have a "version" variable that specifies that last version they were upgraded to use. Whenever you improve a theme, you should change this value to the latest version and fix any problems to get the maximum value and bug fixes out of your theme.

Version: unspecified or 1  
Lots of legacy values were used, scaling was broken etc. Exists only for backward compatibility.  
Version: 2  
Mostly worked, but had some positioning bugs and various offsets were in different coordinates and scales. Exists only for backward compatibility.  
Version: 3  
The current version. All on screen graphics that are associated with a player are positioned relative to the players stack in absolute screen coordinates.  
All non player screen elements are positioned in absolute screen coordinates relative to the top left.  
All example values in this document assume theme version 3. Please do not create themes using older versions as they may no longer be supported in the future!

-----------------------------------------------------------


# Theme configuration and asset list

Theme configuration works differently from character or stage configuration as the theme id never has to be shared over network.
For this reason the "id" of the theme is always the foldername.  

## Graphic assets

You may use .png or .jpg/.jpeg for these.
.gif files are not supported by the framework Panel Attack uses so please refrain from asking devs to support that.  
All file names are case sensitive and the extension *always* has to be lowercase!  
While an incorrectly cased file may load on Windows, it will not on other operating systems!  

### Default image

`transparent` is the fallback image for display if any image asset from any mod type cannot be loaded.

### Backgrounds

Theme backgrounds can be static or scrolling.  
For static backgrounds no extra configuration is necessary.  
For scrolling backgrounds you need to set the `tiled` configuration to `true`.
Additionally you can modify the scrolling speed via `speed_x` and `speed_y`.

Backgrounds need to be placed inside of a background subdirectory inside the theme directory.

#### main

The background shown in button based menus.

Configuration variables and default values:
```
"bg_main_is_tiled": false,
"bg_main_speed_x": 0,
"bg_main_speed_y": 0,
```

#### select_screen

The background shown in character selection.

Configuration variables and default values:
```
"bg_select_screen_is_tiled": false,
"bg_select_screen_speed_x": 0,
"bg_select_screen_speed_y": 0,
```

#### readme

The background shown while displaying readme files.

Configuration variables and default values:
```
"bg_readme_is_tiled": false,
"bg_readme_speed_x": 0,
"bg_readme_speed_y": 0,
```

#### title

The background shown while displaying the title screen at the start of the game.

Configuration variables and default values:
```
"bg_title_is_tiled": false,
"bg_title_speed_x": 0,
"bg_title_speed_y": 0,
```

### Background overlays

Background overlays are displayed during gameplay and cannot be scrolling.  

Like the regular backgrounds they need to be placed inside of the background subdirectory as well.

#### bg_overlay

Background drawn on top of the stage background.  
Use this to give sufficient background contrast to your other theme elements!  
Usually this should be a .png that is transparent in most parts.

#### fg_overlay

This is drawn on top of everything else!  
Although usually not necessary you can use it to obstruct certain parts of the game.

#### Pause

The pause image is displayed when pausing the game in single player game modes.  
Although technically a background, this one does NOT go into the background subdirectory.  
The image will get scaled down to fit the screen while maintaining aspect ratio if it has a different aspect ratio than 16:9.

### Fonts

`pixel_font_blue.png` is a sprite atlas for a font that is used for displaying 1P records in menus and character selection.  
While `pixel_font_grey` and `pixel_font_yellow` can also be specified, they currently don't get used by the game.

### Character selection

#### Flags

Flags are saved in the flags subdirectory.  
Flags will be displayed during character selection on characters that specify a flag in their config.json that has an image of the same name in the flags directory.
It is generally recommended to at least supply the flags already provided by the default theme to tell apart language specific versions of mods.  

#### Character Selection Cursor

The character selection cursor is made from 2 different images that are alternately being drawn on various occasions.  
A general recommendation is to use a more transparent version for the second image.  

For player 1:
p1_select_screen_cursor1
p1_select_screen_cursor2

For player 2:
p2_select_screen_cursor1
p2_select_screen_cursor2

#### Character Selection Player Indicator 

In multiplayer, various selection submenus have a marker to show which player the setting belongs to.  
The image used for this is called p1 or p2 respectively for each player number.

#### Button Overlays

`load` will be displayed on top of the player tile if the selected character of the player is still being loaded.
`ready` will be displayed on top of the player tile when the player has loaded all assets and readied up.  
Additionally it used ingame during the countdown.
`super` will be displayed on top of a character tile when holding the selection key and the character is super selectable.

#### Icons

`random_stage`: Thumbnail for random stage selection. See readme_stages for the recommended size.
`random_character`: Icon for random character selection. See readme_characters for the recommended size.

#### Level display

Level icons have to be provided inside its own `level` subdirectory.  
Each level has to provide a focused and unfocused version for the level slider:  
```
level1
level1unfocus
level2
level2unfocus
etc...
level10
level10unfocus
level11
level11unfocus
```

Additionally an extra `level_cursor` image is being used for the selection process.


-----------------------------------------------------------


### Ingame

#### Cards

Cards are the indicators displayed during gameplay and in analytics to show the achieved combo/chain size.  
They will be scaled to be quadratic if they aren't already, recommended size is 96x96.

##### Chain cards

Chain cards are saved in the chain subdirectory.  
They are displayed upon achieving a chain during gameplay and also shown in analytics.  
Panel Attack supports up to 99 numbered chain cards plus one for a mystery chain.  
Chain cards have to be named chain, followed by 2 digits for the chain index, e.g. chain02.png for a x2 chain.
chain00.png is used as the mystery chain card and displayed for any chain index that does not have its own chain card.  
The general recommendation is to provide chain cards up to x13, but better x19.

##### Combo cards

Combo cards are saved in the combo subdirectory.  
They are displayed upon achieving a combo during gameplay and also shown in analytics.  
Combos are naturally limited to +66 due to the stack size.
Combo cards have to be named combo, followed by 2 digits for the combo size, e.g. `combo04.png` for a +4 combo.
If a combo does not have a card, the +30 combo card will get displayed.  
If that one isn't available either, the game falls back to the mystery chain card.  
The general recommendation is to provide combo cards at least up to +27, but better all combo sizes.

#### Ingame cursor

The ingame cursor is made from 2 different images, `cursor1` and `cursor2`, that are alternately being drawn.  

#### Countdown

Images numbered `1`, `2` and `3` respectively that are displayed during countdown.  
Will get displayed just as is, no scaling or configuration available!

#### Stack Frame

The sum of images that are drawn around the stack as borders plus additional information.
They need to be saved in the frame subdirectory.

##### frame

Image for the borders to left, right and top side of the stack.  
Will always get scaled to an aspect ratio of 13:28!!  
One version needs to be provided for each player:
`frame1P` for player 1  
`frame2P` for player 2

##### wall

Image for the bottom border of the stack. 
Unlike stack, this needs to be opaque in order to obstruct panel vision when raising it to the top to "lock" the stack.  
Width of this image always gets scaled to fit the stack width

#### Multibar 

The multibar is being drawn to the side of the stack to indicate remaining invincibility frames
The multibar supports two different display modes, configured in the theme's config.json:
```
"multibar_is_absolute": true,
```

##### Absolute multibar

When set to true, the multibar will be filled up depending on how many invincibility frames were gained.
The depletion speed is constant.  

##### Relative Multibar

When set to false, each type of invincibility frame has its own maximum height.  
When gained, the bar for the type always caps out and then depletes at a rate relative to how much invincibility frames were actually obtained.  
There are plans to discontinue the relative multibar in the future, so please create new themes only with the absolute multibar.

##### Multibar Frame

Depending on which mode is chosen, different images will be used.  
For an absolute multibar, use `healthbar_frame_1P_absolute`.  
This expects a single compartment shared by health and invincibility frames.
For a relative multibar, use `healthbar_frame_1P`.  
This expects separate compartments for health and invincibility frames.

Position and scale have to be configured separately in the config.json:
```
"multibar_Pos": [-13, 96],
"multibar_Scale": 1,
```

For absolute multibars, the y-offset refers to the bottom of the multibar, not the top.

For a relative multibar, the compartment for health bar needs to be specified separately:
```
"healthbar_frame_Pos": [-17, -4],
"healthbar_frame_Scale": 1,
```

For absolute multibars, the healthbar setting is obsolete as health will be part of the multibar.  
Absolute multibar is only supported for version 3 themes.  

##### Multibars

Multibars are colered bars for display inside of the multibar frame.  
They will get scaled vertically to match the available invincibility frames / health at the respective moment.  

`healthbar` for the remaining health  
`multibar_shake_bar` for remaining shake time
`multibar_stop_bar` for remaining stop time
`multibar_prestop_bar` for remaining pre-stop time

#### Game info

Game info is the info usually displayed in the middle of the screen between the two stacks.  
Location and scale is configurable for each element.  
Note that each configuration that has to be displayed per player is configured for player 1.  
Player 2 will use mirrored values based on the player 1 configuration.

##### Match type

Match type refers to the `ranked` or `casual` image label.  
Configuration:
```
"matchtypeLabel_Scale": 1,
"matchtypeLabel_Pos": [640, 60],
```

##### Time

Refers to the `time` label and the time displayed.
Time itself is drawn from the `time_numbers` tile map.
Configuration:
```
"timeLabel_Scale": 1,
"timeLabel_Pos": [640, -126],
"time_Scale": 0.70,
"time_Pos": [640, 8],
```

##### Spectator position

Only the position is configurable here.  
Specifying an offscreen position effectively disables spectator display.
Configuration:
```
"spectators_Pos": [546, 460],
```

##### Player names

The position and font size of the player names are configurable:
```
"name_Pos": [184, -108],
"name_Font_Size": 20,
```

##### Game Over text

The position of the "game over" text.
```
"gameover_text_Pos": [640, 620],
```

##### Score

Refers to the `score_1P` and `score_2P` label.  
Score itself is drawn from the `numbers_1P` and `numbers_2P` tile maps.  
Configuration:
```
"scoreLabel_Scale": 1,
"scoreLabel_Pos": [316, 64],
"score_Scale": 0.5,
"score_Pos": [352, 88],
```

##### Speed

Refers to the `speed_1P` and `speed_2P` label.  
Speed itself is drawn from the `numbers_1P` and `numbers_2P` tile maps.  
Configuration:
```
"speedLabel_Scale": 1,
"speedLabel_Pos": [316, 122],
"speed_Scale": 0.5,
"speed_Pos": [352, 146],
```

##### Level

Refers to the `level_1P` and `level_2P` label.  
Level itself is drawn from the `level_numbers_1P` and `level_numbers_2P` tile maps.  
Configuration:
```
"levelLabel_Scale": 1,
"levelLabel_Pos": [318, 0],
"level_Scale": 1,
"level_Pos": [340, 24],
```

##### Rating

Refers to the `rating_1P` and `rating_2P` label.
Rating itself is drawn from the `numbers_1P` and `numbers_2P` tile maps.  
Configuration:
```
"ratingLabel_Scale": 1,
"ratingLabel_Pos": [310, 180],
"rating_Scale": 0.5,
"rating_Pos": [354, 206],
```

##### Wins

Refers to the `wins` label.
Rating itself is drawn from the `numbers_1P` and `numbers_2P` tile maps.  
Configuration:
```
"winLabel_Scale": 1,
"winLabel_Pos": [318, -246],
"win_Scale": 0.75,
"win_Pos": [260, -112],
```

In the current default config the win label is offscreen to align the wincounts with the background overlay instead.

##### Moves

Refers to the `moves` label, drawn in puzzle mode only.
Move count itself is drawn from the `numbers_1P` tile map.  
Configuration:
```
"moveLabel_Scale": 1,
"moveLabel_Pos": [312, 60],
"move_Scale": 1,
"move_Pos": [354, 86],
```

#### Fallback PopFX

A theme should provide a fallback for the `burst` and `fade` PopFX tile maps for display in case the selected character does not provide them.  

#### Analytics

If analytics are enabled, several icon graphics will be shown to the side of each stack.  
Some of them are derived from character or other theme assets but some are specific for analytics.  
All icons get scaled for quadratic display

`GPM` for garbage per minute icon
`APM` for actions per minute icon
`swap` for the swap counter icon
`CursorCount` for the cursor move counter icon

-----------------------------------------------------------


## SFX assets

You may use .mp3, .ogg, .wav, .it or .flac for these.  
.midi files are not supported by the framework Panel Attack uses so please refrain from asking devs to support that.  
All file names are case sensitive and the extension *always* has to be lowercase!  
While an incorrectly cased file may load on Windows, it will not on other operating systems!  

All sfx have to be placed inside the `sfx` subdirectory.  

### Menus

`menu_move`: will play when moving the cursor in menus  
`menu_validate`: will play when confirming a menu with Swap1/A/Start  
`menu_cancel`: will play when exiting menus with Swap2/B  
`notification`: will play upon receiving a request or a request's answer while looking for games

### Gameplay

`countdown` and `go`: will play at the start of the match if countdown is enabled for the game mode  
`move`: will play when moving the cursor  
`swap`: will play when performing a swap  
`land`: will play when a non-garbage panel lands  
`thud_1`, `thud_2`, `thud_3`: will play when garbage lands (depending on garbage size)  
`fanfare1`: will play when a player finishes a chain at x4  
`fanfare2`: will play when a player finishes a chain at x5  
`fanfare3`: will play when a player finishes a chain at x6 or higher  
`gameover` will play when the game is over

#### Pop sounds

Pop sounds will play based on the length of the currently on-going chain.  
Every time a match happens, the game plays `pop#-1` for the first popping panel, `pop#-2` for the second etc. until maxing out at `pop#-10` which is then getting repeated for further panels.

While no chain is on-going, `pop1` SFX are used.  
`pop2` SFX is used for x2 chains.  
`pop3` SFX is used for x3 chains.  
`pop4` SFX is used for x4 chains and higher.  


-----------------------------------------------------------


## Music assets

Music can optionally play at various screens of the game.  
You may use .mp3, .ogg, .wav, .it or .flac for these.  
.midi files are not supported by the framework Panel Attack uses so please refrain from asking devs to support that.  
All file names are case sensitive and the extension *always* has to be lowercase!  
While an incorrectly cased file may load on Windows, it will not on other operating systems!  

All music has to be placed inside the `music` subdirectory.  

`title_screen` and optionally `title_screen_start` for the title screen.  
`main` and optionally `main_start` for all button menus.  
`select_screen` and optionally `select_screen_start` for character selection.  
If `main` exists but `select_screen` does not, `main` will play in character selection as well.

`_start` files are played before the main music file once and serve to facilitate looping with a reasonable intro.


-----------------------------------------------------------


## Miscellaneous assets

### Font

You may provide a font by simply dropping a .ttf font file in the theme folder.  

#### config

The font's size can be changed in the config.json file with the parameter font_size.  
The value given should be a whole number.

### Character selection filters

You may override the visible state configured in each character's/stage's configuration by providing respective files that explicitly state the visible mods.

#### characters.txt

If present, only characters listed in this file will show up in character selection.  
Only characters listed in this file will be eligible for random selection.  
Separate the IDs by new lines.

#### stages.txt

If present, only stages listed in this file will show up in stage selection.  
Only stages listed in this file will be eligible for random selection.  
Separate the IDs by new lines.