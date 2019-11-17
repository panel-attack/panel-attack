Adding/modding panels:

Step by step instructions (Windows example):

1. Press the Windows key then type "%appdata%" without quotes and hit enter.

2. Look at the folders starting with "__" located in: %appdata%\Panel Attack\panels\ for a reference of where your files should go and how they should be named.
   
Note: folders starting with "__" will be ignored upon loading. You may choose to remove those "__" to mod the default panels

3. Create a folder with your panels. The name of this folder is different from your panels id and is kinda meaningless (see config.json below).

4. Place assets and json file in that folder with the proper names to add your data. Exhaustive list below.

Note: all panels will be loaded.

~~~~ Exhaustive list of a panels folder data! ~~~~

Note: non-optional data that are missing will automatically get replaced by default ones so they are kinda optional in that sense

~~ [.json] ~~

- "config": this file holds data for the configuration of your panel set. The inside should look like that:
	- id: unique identifier of this panel set, this id should be specific (see note). [IF MISSING YOUR PANELS WILL BE IGNORED!]

Note: providing a specific, long enough id is a very good idea so that people renaming your mods folders still get properly match with other users regarding your mods. e.g. "mypanels_myname"

~~ [.png, .jpg] ~~

- "garbageflash", "metalend0", "metalend1", "metalmid": assets for garbage metals panels: those will be displayed on your opponent side when sending garbage
- "panel11", ...,  "panel17", "panel21", ...,  "panel27", ... , "panel61", ...,  "panel67": 'classic' panels, the sixth one is used above level 8 only
- "panel71", ...,  "panel77": seventh panel only used in puzzles
- "panel00": used in puzzle (represents a to-be-ignored panel) and for debug purpose
- "panel81", ...,  "panel87": metal panel