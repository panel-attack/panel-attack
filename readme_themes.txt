Adding/modding themes:

Step by step instructions (Windows example):

1. Press the Windows key then type "%appdata%" without quotes and hit enter.

2. See the folder located in: %appdata%\Panel Attack\themes\__Panel Attack for a reference of where your files should go and how they should be named.
   
Note: folders starting with "__" will be ignored upon loading. You may choose to remove those "__" to mod default themes

3. Create a folder with your theùe. The name of the folder will be the id of your theme.

4. Place assets, sounds and txt files in that folder with the proper names to add your data. Exhaustive list below.

~~~~ Exhaustive list of a theme folder data! ~~~~

Note: non-optional data that are missing will automatically get replaced by default ones so they are kinda optional in that sense

~~ [.txt] ~~

- "characters": list of the characters to be displayed in the select screen
- "stages": list of the stages to be displayed in the select screen

~~ [.png, .jpg] ~~

- "background/main", "background/select_screen", "background/readme": backgrounds used in the menus
- ("background/bg_overlay"), ("background/fg_overlay"): overlays: the first one is on top of the stage's background while the other one is up front
- "pause": overlay during the pause
- "chain/chain00", "chain/chain02", ... "chain/chain19", "combo/combo04", ..., "combo/combo66": chains and combo counter
- "flags/": flags to be displayed in the select screen (based on the character's specified flags). Values are mostly the country codes from https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2, not all flags are available
- "1", "2", "3": countdown
- "p1", "p1_cursor", "p1_select_screen_cursor1", "p1_select_screen_cursor2": cursors for player 1, change p1 by p2 for those of player 2
- "ready", "loading", "super": displayed when a player is ready, loading, or super selecting something in the select screen
- "frame", "wall": layout ingame
- "random_stage", "random_character": thumbnail and icon for random stage and random character

~~ [.mp3, .ogg, .wav, .it, .flac] optional sounds are in parenthesis ~~

- "sfx/countdown", "sfx/go", "sfx/move", "sfx/swap", "sfx/land", "sfx/gameover": game sfx
- "sfx/fanfare1", "sfx/fanfare2", "sfx/fanfare3": fanfare
- "sfx/thud_1", "sfx/thud_2", "sfx/thud_3": garbage thuds
- "sfx/menu_move", "sfx/menu_validate", "sfx/menu_cancel": menu
- "sfx/notification": will play upon receiving a request or a request's answer while playing online
- "sfx/pop1-1", "sfx/pop1-2", ..., "sfx/pop1-10", "sfx/pop2-1", ..., "sfx/pop2-10", ..., "sfx/pop4-10": panel pops
- ("music/main", ("music/main_start")), ("music/select_screen", ("music/select_screen_start")): musics that will be used in those menus, "main" will be used as fallback if "select_screen" is missing. 
"_start"s are played before the normal versions, once.
