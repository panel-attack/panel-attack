Adding/modding themes:

Step by step instructions (Windows example):

1. Press the Windows key then type "%appdata%" without quotes and hit enter.

2. See the folder located in: %appdata%\Panel Attack\themes\__Panel Attack for a reference of where your files should go and how they should be named.
   
Note: folders starting with "__" will be ignored upon loading. You may choose to remove those "__" to mod default themes

3. Create a folder with your theùe. The name of the folder will be the id of your theme.

4. Place assets, sounds and txt files in that folder with the proper names to add your data. Exhaustive list below.

~~~~ Exhaustive list of a character folder data! ~~~~

Note: non-optional data that are missing will automatically get replaced by default ones so they are kinda optional in that sense

~~ [.txt] ~~

- "characters": list of the characters to be displayed in the select screen
- "stages": list of the stages to be displayed in the select screen

~~ [.png, .jpg] ~~

- "background/main", "background/select_screen", "background/readme": backgrounds used in the menus
- "chain/chain00", "chain/chain02", ... "chain/chain19", "combo/combo04", ..., "combo/combo66": chains and combo counter
- "1", "2", "3": countdown
- "p1", "p1_cursor", "p1_select_screen_cursor1", "p1_select_screen_cursor2": cursors for player 1, change p1 by p2 for those of player 2
- "ready", "loading": displayed when a player is ready or loading something in the select screen
- "frame", "wall": layout ingame
- "random_stage": thumbnail for random stage selection

~~ [.mp3, .ogg, .it] ~~

- "countdown", "go", "move", "swap", "land", "game_over": game sfx
- "fanfare1", "fanfare2", "fanfare3": fanfare
- "thud_1", "thud_2", "thud_3": garbage thuds
- "menu_move", "menu_validate", "menu_cancel": menu
- "pop1-1", "pop1-2", ..., "pop1-10", "pop2-1", ..., "pop2-10", ..., "pop4-10": panel pops
