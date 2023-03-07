You can also find this file with prettier formatting at https://github.com/panel-attack/panel-attack/blob/beta/readme_themes.md  

This README consists of 2 parts.  
In part 1 some general thoughts on theme creation are discussed.  
In part 2 you can find an exhaustive list of all assets used for theme.  

# How to approach theme creation

## Graphics 

Theme creation is quite different from the creation of other mods.  
Unlike with characters or stages where you provide assets that will go into one exact spot with one exact resolution, themes don't limit you much in regards to position and scale of assets.  
Many files in fact do not have a specific size or aspect ratio but merely a configurable anchor point to place them.  
Due to this, it is required for theme assets that you specify how big the file is relative to the canvas of 1280x720.  



# Theme configuration and asset list

Theme configuration works differently from character or stage configuration as the theme id never has to be shared over network.
For this reason the "id" of the theme is always the foldername.  

## Graphic assets

[.png, .jpg, .jpeg]

- "background/main", "background/select_screen", "background/readme": backgrounds used in the menus
- ("background/bg_overlay"), ("background/fg_overlay"): overlays: the first one is on top of the stage's background while the other one is up front
- "pause": overlay during the pause
- "chain/chain00", "chain/chain02", ... "chain/chain19", "combo/combo04", ..., "combo/combo66": chains and combo counter
- "flags/": flags to be displayed in the select screen (based on the character's specified flags). Values are mostly the country codes from https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2, not all flags are available
- "1", "2", "3": countdown
- "p1", "cursor1", "p1_select_screen_cursor1", "p1_select_screen_cursor2": cursors for player 1, change p1 by p2 for those of player 2
- "ready", "loading", "super": displayed when a player is ready, loading, or super selecting something in the select screen
- "frame", "wall", "healthbar_frame_1P", "healthbar_frame_1P_absolute": layout ingame
- "random_stage", "random_character": thumbnail and icon for random stage and random character


## SFX assets

~~ [.mp3, .ogg, .wav, .it, .flac] optional sounds are in parenthesis ~~

- "sfx/countdown", "sfx/go": played at the start of a match
- "sfx/move", "sfx/swap": played when moving and swapping
- "sfx/land": Played when a panel lands
- "sfx/gameover": played when each game is over
- "sfx/fanfare1": played when a player makes a x4 chain
- "sfx/fanfare2": 5x chain, "sfx/fanfare3": x6 chain
- "sfx/thud_1", "sfx/thud_2", "sfx/thud_3": garbage landing noise
- "sfx/menu_move", "sfx/menu_validate", "sfx/menu_cancel": menu
- "sfx/notification": will play upon receiving a request or a request's answer while playing online
- "sfx/pop1-1", "sfx/pop1-2", ..., "sfx/pop1-10", "sfx/pop2-1", ..., "sfx/pop2-10", ..., "sfx/pop4-10": panel pops

## Music assets

- ("music/main", ("music/main_start")), ("music/select_screen", ("music/select_screen_start")): musics that will be used in those menus, "main" will be used as fallback if "select_screen" is missing. 
"_start"s are played before the normal versions, once.


## Miscellaneous assets

### Font

You may provide a font by simply dropping a .ttf font file in the theme folder.  

#### config

The font's size can be changed in the config.json file with the parameter font_size.  
The value given should be a whole number.

----

#### Character selection filters

You may override the visible state configured in each character's/stage's configuration by providing respective files that explicitly state the visible mods.

##### characters.txt

If present, only characters listed in this file will show up in character selection.  
Separate the IDs by new lines.

##### stages.txt

If present, only stages listed in this file will show up in stage selection.  
Separate the IDs by new lines.