Adding/modding panels: step by step instructions (Windows example):

1. Press the Windows key then type "%appdata%" without quotes and hit enter.
2. Look at the example folders located in: %appdata%\Panel Attack\panels\ for a reference of where your files should go and how they should be named. 
   Folders starting with "__" will be ignored upon loading.
3. Create a folder with your panels. The name of this folder is different from your panels id and is kinda meaningless (see config.json below).
4. Place assets and json file in that folder with the proper names to add your data. Exhaustive list below.

Note: all panels will be loaded.

~~~~ Exhaustive list of a panels folder data! ~~~~

Note: non-optional data that are missing will automatically get replaced by default ones so they are kinda optional in that sense

~~ [.json] ~~

- "config": this file holds data for the configuration of your panel set. The inside should look like that:
	- id: unique identifier of this panel set, this id should be specific (see note). [IF MISSING YOUR PANELS WILL BE IGNORED!]
   - sheet: Tells the game this is a new sprite sheet mod so it doesn't try converting your panel images.
   - animations: Holds info on all the possible animations a sprite can have, they will be automaticlly created with defaults if not provided
      - panel-0, ..., panel-8: the animation sets for each panel type. [0 is for the empty panel] [8 is the [!] panel]
         - size:{"width": ,"height": } The size of one panel. [you NEED to include the labels "width": and "height": when typing this value in]
         - filter: This animation will be rendered with linear filtering if true.    
            
         [Below is a list of all the animation names and what they represent]

         - normal: the panel's idle animation.
            [Each animation includes the following
               - frames: the number of frames the animation goes on for [default = 1]
               - row: the row to get the frames from [default = 1]
               - fps: the speed of the animation in frames per second [default = 30]
               - loop: if the animation loops [default = true]
            ]
         - swappingLeft: the panel being swapped to the left.
         - swappingRight: the panel being swapped to the right.
         - matched: the panel is matched. [plays a few frames before "popping"]
         - popping: the panel beinging cleared after a match when it stops flashing.
         - hover: when your cursor is over the panel.
         - falling: the panel falling.
         - landing: the panel landing.
         - danger: when the panel's column is close to the top of the board.
         - panic: when the panel's column is topped out, but you haven't lost yet.
         - dead: the panel's losing animation
         - flash: the panel flashing when it's matched
         - dimmed: the dimmed panel when rising from the bottom but isn't in play yet
         - fromGarbage: when the panel is being spawned from a cleared garbage block

         YOU CAN ASSIGN MULTIPLE ANIMATIONS TO THE SAME ROW

      - "garbage-L": the animation info for the LEFT EDGE of the metal garbage sent by [!] panels.
         - size
         - filter
         [Includes the following animations]
         [Contains the same set of parameters as the panel animations]
         - normal
         - falling
         - landing
         - danger
         - panic
         - dead

      -"garbage-M", "garbage-R": Contain the same paramters as garbage-L, but are for the MIDDLE and RIGHT EDGE respectively.
         
      - "garbage-flash"
         [Includes the following animations]
         - flash
	      - matched
	      - popping
      

Note: providing a specific, long enough id is a very good idea so that people renaming your mods folders still get properly match with other users regarding your mods. e.g. "mypanels_myname"

~~ [.png, .jpg] ~~
Each panel type is animated using it's own separate sprite sheet.
When exporting a panel's sprite sheet, each animation should be put on its own row.
[If multiple animations are the same, they can be combined into a single row]

- panel-0, ..., panel-8: Sprite sheets for each panel type. [0 is for the empty panel] [8 is the [!] panel]
- "garbage-L": Sprite sheet for the LEFT EDGE of the metal garbage sent by [!] panels.
- "garbage-M": Sprite sheet for the LEFT EDGE of the metal garbage sent by [!] panels.
- "garbage-R": Sprite sheet for the RIGHT EDGE of the metal garbage sent by [!] panels.
- "garbage-flash": Sprite sheet for the FLASHING AND POPPING animation of the metal garbage sent by [!] panels.

[Outdated panel sprite setup, old mods following this setup can be automatically converted]

- "garbageflash", "metalend0", "metalend1", "metalmid": assets for garbage metals panels: those will be displayed on your opponent side when sending garbage
- "panel11", ...,  "panel17", "panel21", ...,  "panel27", ... , "panel61", ...,  "panel67": 'classic' panels, the sixth one is used above level 8 only
- "panel71", ...,  "panel77": seventh panel only used in puzzles
- "panel00": used in puzzle (represents a to-be-ignored panel) and for debug purpose
- "panel81", ...,  "panel87": metal panel

Tips for creating panels:

Create a background block that is 48 x 48 pixels
Add a shape to the middle

File 1: Base block
File 2: Shape is shifted 2 pixels up
File 3: Shape is shifted 4 pixels up
File 4: Bottom is shifted down 2 pixels, top is squished down 9 pixels, sides are squished out 2 pixels
File 5: Inverted: Middle color shape is about 20% darker, White is 208, 208, 208, outside is same color as inside
File 6: Dead: Add a silly / broken / dead version this is shown at the end of popping and at game over.
File 7: everything is 50% darker  

You can use the Ctrl+Shift+Alt+P shortcut to reload all panel graphics in the game.