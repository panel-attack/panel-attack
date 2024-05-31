You can also find this file with prettier formatting at https://github.com/panel-attack/panel-attack/blob/beta/docs/panels.md  

Adding/modding panels: step by step instructions (Windows example):

1. Press the Windows key then type "%appdata%" without quotes and hit enter.
2. Look at the example folders located in: %appdata%\Panel Attack\panels\ for a reference of where your files should go and how they should be named. 
   Folders starting with "__" will be ignored upon loading.
3. Create a folder with your panels. The name of this folder is different from your panels id and is kinda meaningless (see config.json below).
4. Place assets and json file in that folder with the proper names to add your data. Exhaustive list below.

Note: all panels will be loaded on game start.  
While working on a panel set you can use the Ctrl+Shift+Alt+P shortcut to reload all panel graphics in the game.

# config.json

This file holds data for the configuration of your panel set.

## Minimum configuration

Every config.json should specify the panel set's id

## id

The unique identifier of the panels. IF MISSING THE PANELS WILL BE IGNORED!  
The id should be long and unique so that the game can properly distinguish between different panel mods.  
It is generally recommended to add your username to the id to ensure its uniqueness.  
For example "panelhd_rings_mizunoketsuban" for a panel set featuring ring shapes by user Mizuno.

## type

How you supply your panel images. If no value is given, "single" is assumed.

### single

Supplying your panel images in single files, image by image, e.g.:
- panel11.png
- panel12.png
- panel13.png
- panel14.png
- panel15.png
- panel16.png
- panel17.png

would constitute 7 images for color 1.  
The images for color 2 would be called panel21, panel22 and so on.

### sheet

Supplying your panel images in one spritesheet per color, e.g.:
- panel-1.png
- panel-2.png
- panel-3.png
- panel-4.png
- panel-5.png
- panel-6.png
- panel-7.png
- panel-8.png

would constitute 8 spritesheets, one for each color.

## animationConfig

A configuration table that looks different depending on your chosen type.  
Inside the animation configuration you can pick how panels look and in some cases animate depending on their game state.

### Panel states

To make a cool panel set, it helps to understand when which panel state is active.

#### normal

The idle state of a panel when nothing happens. Currently a single frame and not animatable.

#### landing

An animation that plays when a panel lands on the ground after falling.  
The animation can be up to 12 frames long and will not loop.

#### swapping

When a panel is in the process of being swapped. Currently a single frame and not animatable.

#### flash

When a panel gets matched it initially enters this flashing state.  
This animation loops and its actual length in the game depends on the level.

#### face

When a panel gets matched it enters the flash state and after a while transitions to the face state.  
The panel will remain in the face state until it pops.  
The face state can be animated but it will not loop.

#### popping

Right before a matched panel disappears it plays the popping animation.  
The popping animation is at maximum 6 frames long and does not loop.

#### hovering

When a panel gets swapped above empty space it briefly stays suspended in the air before it falls.  
This suspension is referred to as hovering.  
The hovering panel is also displayed for panels that popped from garbage after they finished their garbageBounce animation.  
Currently a single frame and not animatable.

#### falling

After a panel stops hovering and falls down, this frame is displayed, unless a garbageBounce animation is still ongoing.  
Currently a single frame and not animatable.

#### dimmed

Panels that rise up from the bottom but have not become active for gameplay yet, are dimmed.  
Currently a single frame and not animatable.

#### dead

When a player loses all health and goes game over, all panels in their stack are displayed with their dead frame.  
Currently a single frame and not animatable.

#### danger

Panels in the states "normal", "falling" and "hovering" in a column that is close to the top or even touching it, perform a danger animation.  
This animation loops but is held on its last frame if the player is topped out and has no stop time left.  
At the moment this animation *has* to be 18 frames long.

#### garbageBounce

Panels converted from garbage will perform a garbageBounce animation for the combined duration of the time they are
- hovering
- falling
until they reach ground and start their landing animation instead.  
This animation does not loop and lasts at the maximum for 12 frames.

#### garbagePop

When garbage is being cleared, the colors of the freed panels become visible one by one.  
As long as the garbage pops and the panels are suspended, the garbage pop frame is being shown.  
Currently a single frame and not animatable.

### Animation configuration with type "single"

If using single images, you have to configure for each state which image index is supposed to be used.
Additionally you can specify for how many frames each image is displayed.  
If no animation configuration is set, the following is used:
```Json
// durationPerFrame defaults to 2 if not specified
{
   "normal": {"frames":[1]},
   "landing": {"durationPerFrame": 3, "frames":[4, 3, 2, 1]},
   "swapping": {"frames":[1]},
   "flash": {"frames":[5, 1]},
   "face": {"frames":[6]},
   "popping": {"frames":[6]},
   "hovering": {"frames":[7]},
   "falling": {"frames":[1]},
   "dimmed": {"frames":[7]},
   "dead": {"frames":[6]},
   "danger": {"durationPerFrame": 3, "frames":[1, 2, 3, 2, 1, 4]},
   "garbageBounce": {"durationPerFrame": 3, "frames": [1, 4, 3, 2]}
}
```

As an example, for the flash state, the game will alternate between image 5 and image 1, holding each for 2 frames before switching.  
5 and 1 refers to the files panel15 and panel11 for color 1, panel25 and panel21 for color 2 and so on.

### Animation configuration with type "sheet"

If using the type "sheet" it is assumed that the image has multiple rows where each row has one or more panels from left to right.  
In the case of animations, the frames will be picked from left to right (with the exception of danger where they get picked right to left).  
You can use the same row for more than one panel state.  

Example:  

```Json
// durationPerFrame defaults to 2 if not specified
{
   "normal": {"row": 1, "frames": 1},
   "landing": {"row": 2, "durationPerFrame": 3, "frames": 4},
   "swapping": {"row": 1, "frames": 1},
   "flash": {"row": 3, "frames": 2},
   "face": {"row": 4, "frames": 1},
   "popping": {"row": 6, "frames": 2},
   "hovering": {"row": 7, "frames": 1},
   "falling": {"row": 1, "frames": 1},
   "dimmed": {"row": 9, "frames": 1},
   "dead": {"row": 10, "frames": 1},
   "danger": {"durationPerFrame": 3, "row": 5, "frames": 6},
   "garbageBounce": {"durationPerFrame": 2, "row": 8, "frames": 3}
}
```

If possible, reference existing panel sets using sheets as it's a lot easier to understand if you have a picture to look at.

# Shock Images

## metalend0

Image representing the left edge of shock garbage.  
Should be half a panel wide and an entire panel tall.

## metalend1

Image representing the right edge of shock garbage.  
Should be half a panel wide and an entire panel tall.

## metalmid

Image representing the center part of shock garbage.  
Should be half a panel wide and an entire panel tall.

## garbageflash

Image representing during the flash animation when shock garbage matches.
Should be a full panel tall and wide.

# Panel Images

## panel00

Used in puzzle mode, represents a panel that can be swapped but not matched with other panels

## "single" panel images

All panel images should use the same size and have equal width and height.

- "panel11", ...,  "panel17", "panel21", ...,  "panel27", ... , "panel51", ...,  "panel57"
- "panel61", ...,  "panel67": sixth panel used above level 8
- "panel71", ...,  "panel77": seventh panel only used in puzzles
- "panel81", ...,  "panel87": metal/shock panel

If you add your own animation configuration, you can of course use more than 7 or 10 images.  
Naming a file panel111 will be used as image 11 for color 1.

### Tips for creating panels with single images

Create a background block that is 48 x 48 pixels
Add a shape to the middle

- File 1: Base block
- File 2: Shape is shifted 2 pixels up
- File 3: Shape is shifted 4 pixels up
- File 4: Bottom is shifted down 2 pixels, top is squished down 9 pixels, sides are squished out 2 pixels
- File 5: Inverted: Middle color shape is about 20% darker, White is 208, 208, 208, outside is same color as inside
- File 6: Dead: Add a silly / broken / dead version this is shown at the end of popping and at game over.
- File 7: everything is 50% darker  

## "sheet" panel images

One sheet for each panel color:
- panel-1.png
- panel-2.png
- panel-3.png
- panel-4.png
- panel-5.png
- panel-6.png for the sixth color used above level 8
- panel-7.png for the seventh color normally only used in puzzles
- panel-8.png for metal/shock panels

All sheets should be the same size, feature the same amount of rows and have the same amount of frames in each row.
