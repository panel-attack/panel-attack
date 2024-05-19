You can also find this file with prettier formatting at  
https://github.com/panel-attack/panel-attack/blob/beta/docs/characters.md  

This README consists of 3 parts.  
In part 1 some general thoughts on character creation are discussed.  
In part 2 you can find an exhaustive list of all assets used for characters.  
In part 3 you can learn how to make your mod support different resolutions.

# How to approach character creation

Before getting into the process, there are some things to consider to make sure your mod turns out the best it can be.  

## Copying from other mods

Rather than trying to read through all of this and trying to understand it, it ought to be much more simple to take an existing mod and simply edit it until it is completely different right?!  

Well, yes and no.  
Over the years, many things have changed and a mod created five, two, one or half a year ago may not use all features available or not use the available features optimally.  
Chain cards for example can go up to x99, combo SFX can be assigned per combo size if you wish so and high resolution assets actually look good on high resolution monitors now (unlike in the past).  
All of the mentioned changes happened in late 2022 and who knows what the future brings? (aside from updates for this doc)

Referencing existing mods is generally a fantastic idea (especially for garbage).  
However, try to understand the context and the possibilities when referencing a mod so you can very clearly decide which parts you want to copy and which ones you want to do differently.  

For instance, most mods created until late 2022 are made with a target resolution of 1280x720. The majority that aren't are made with a target resolution of 640x360 instead.  
Chances are, you are playing Panel Attack on a higher resolution and things may end up looking like sandpaper if you just copy sizes from an existing mod.

## Resolution

In the graphic assets reference for characters you will find specific pixel size recommendation for each asset.  
These recommendations are based on a window size of 2560x1440.  
You CAN choose to make your assets smaller, consider however that it is quite easy to reduce the size of your assets later on if you don't get a satisfying result on your own (lower resolution) machine.  
On the other hand, increasing resolution later later on is near impossible without a noticeable drop in quality.  

If you're unsure what this is all supposed to mean, try to follow the recommendations as closely as possible. 
If you can't manage to follow the recommended size for an asset, make sure its aspect ratio of your asset is correct as it will get stretched otherwise.

## Planning

The minimum character consists of merely a single configuration file that records the unique identifier of the character.  
You can play with it and Panel Attack will fill in for most of its assets but it obviously won't be an enjoyable character to use.  

So what makes a character a character?  
Opinions on this might differ but the overall gameplay experience is constructed from the combination of visuals and sound effects.  

### Personalised elements

The strongest noticeable elements of a character are:  
- character portrait in gameplay
- character icon in character select
- garbage icon, garbage color and garbage filler
- SFX for combos, chains and a small handful of other SFX

#### Character portrait

This should be relatively easy for most custom characters.  
Do a wallpaper search for your character and then cut out your character in the correct aspect ratio.  
If it is smaller than the recommended size do not scale it up inside the image editor.  
Scaling up forces your image editing program to come up with pixels that weren't there before, usually resulting in noticeable quality loss.  
If Panel Attack then scales your image again, it can look quite poor compared to if Panel Attack can scale the original version directly

#### Character icon

The easiest way to do this is to simply cut out a square face from the character portrait you prepared.  

#### Garbage

Garbage can be VERY finnicky to do if you do it from scratch or want to do a creative solution (there is a wild watermelon style garbage out there).
There is a reasonable low-effort way around truly having to deal with it:  

##### Stealing the borders

Look through other characters.  
Pick one that has a fitting color + border for your character.  
Copy its garbage assets to your character!  
The borders are the most annoying part and now you don't have to do them anymore!

##### Personalising the garbage!

The truly impactful elements of garbage are face, face2, doubleface, filler1 and filler2.  
Many mods won't even have face2 and some may not have filler1 or filler2.  
Draw over whatever icon/symbol the other mod used with the background color to clear them up.  
And now paste your own symbol on top for face and doubleface! How?  
You can find a lot of assets with transparent backgrounds online that fit this purpose.  
There are various dedicated websites that aggregate graphic assets of games you can use.  
If you're not successful there, search the internet for the respective character/series/game/franchise you want with keywords like "png", "transparent background", "icon" and you should find something good.  

For the fillers, you can follow the same approach but often something more subtle or even leaving them with only with the background color works better than choosing another flashy icon.

#### SFX

These are the backbone of a good character.  
SFX are very important because they allow you to roughly tell what your opponent is doing just by listening.  
Aside from the obvious chain and combo SFX there are two more SFX that can contribute strongly and in a more subtle way:  
garbage_land and garbage_match are sounds that can let you know when your opponent is letting garbage drop and when they start clearing.
While garbage_land and garbage_match are not quite as important, Panel Attack does currently not provide default sounds for these, making their absence quite noticeable.  

As a recommendation (for what is currently possible, may change with future updates):  
It should be somewhat possible to tell combo and chain SFX apart so you know what is coming.  
If you have sufficient sound files available, using per_chain/per_combo style is generally preferable.  
If used, garbage_match should be a subtle sound with a different characteristic as it will very often play in parallel to combo or chain SFX.  
If used, garbage_land should be a short sound as it will often directly be followed by garbage_match + combo/chain, so it doesn't overlap too much.  

Finally, adding a win SFX is a great idea as on average in half of the games played with the character, that SFX will play.  


### Optional elements

These are generally very nice to have but not as defining for a character.

#### Music

Music can be a very nice addition and probably the first one in most people's minds, however, it can come from a stage as well instead and is therefore not quite as necessary.  
If you found a good SFX resource for your character however, you will probably be able to find the necessary music files in the same place.

#### Other SFX

Selection SFX is nice to have but as it is neither a telegraph, nor will it play very often, it is not quite as important.  
Taunts have neither gameplay nor menu functionality and should be done last.  
If you are short on SFX, selection SFX and taunt SFX could be the same as your win SFX.

#### PopFX

PopFX is a visual pop effect for doing matches, combos and chains.  
Panel Attack provides a backup for this and too fancy PopFX may distract the player through the playfield obstruction so it is comparably the least relevant.  
A good popFX can however be quite the nice visual addition to an already good character.


-----------------------------------------------------------


# Character configuration and asset list

## config.json

This file holds data for the configuration of your character.

### Minimum configuration

Every config.json should specify the character's id and its name.

#### id

The unique identifier of the character. IF MISSING THE CHARACTER MAY BE IGNORED!  
The id should be long and unique so that the game can properly distinguish between different character mods of potentially the same character.  
It is generally recommended to add your username to the id to ensure its uniqueness, e.g. "Sil_Paper_Mario" for a character mod of Mario by user Sil based on the Paper Mario games.  

#### name

The display name of the character.  
This value will be displayed in character selection and will also serve as a fallback when trying to load your opponent's character.  
The folder name will be displayed if this value is missing.  


### Super select configuration

Super select is a mechanism that aims to provide a cohesive visual experience to the user by making it possible to automatically select a stage and/or panels upon character selection.
Upon holding the selection on a character in character select, a SUPER text will appear above. 
If the selection is held long enough for it to fill up, the stage/panels stated in the config.json will automatically be selected.
The player can always opt out of super selection by only short tapping a character selection.

#### stage

This specifies which stage to select alongside the character when 'super selecting' it.  
Example:  
{  
	"id":"PPL_Bruno",  
	"name":"Bruno",  
	"stage":"ppl_fire3"  
}  
Upon super selecting Bruno, the stage with the id "ppl_fire3" would automatically get picked as well if available.

#### panels

This specifies which panels to select alongside the character when 'super selecting' it.


### Bundle configuration

#### sub_ids

Identifiers for other characters, this allows you to define a character bundle that encompasses multiple other characters (picked at random).  

By providing more than one id in the sub_ids field, the game will randomly pick one of the sub_ids as your character instead.  
Example:  
{  
	"id":"PPL_Bruno",  
	"name":"Bruno",  
	"sub_ids":["ppl_hitmonchan","ppl_onix","ppl_primeape"],  
}  
Commonly the characters in the sub_ids are made invisible by setting visible = false in their respective config.json:  
{  
	"id":"ppl_primeape",  
	"name":"Bruno's Primeape",  
	"visible":false  
}  

### Music and SFX configuration

#### music_style

Defines which music style should be used.  
Available options are "normal" and "dynamic".

##### normal

The default option that is used if music_style is not specified in the configuration.  
Music will restart the normal/danger music track upon getting into/out of danger.

##### dynamic

Normal music and danger music will maintain the same play time stamp and crossfade seamlessly.


#### chain_style

Change the way the chain SFX files are being used.  
Available options are "classic" and "per_chain".

##### classic

The default option if not specified. Also deprecated, please use per_chain style for new characters instead.  
	x2/3 plays "chain",   
	x4 plays "chain2",  
	x5 plays "chain_echo",   
	x6+ plays "chain2_echo"  
Due to backwards compatibility reason the classic system remains as the default.  
If you wish to use classic style chain sounds, you can use the per_chain system.  
Simply rename the classic system's  
"chain" as "chain2",  
"chain2" as "chain4",  
"chain_echo" as "chain5"    
"chain2_echo" as "chain6"

##### per_chain

Provide a SFX for each chain length. More than one variation may be provided for each length by appending _# to the filename where # is a number.
If no file is provided for a certain chain length the first available lower chain SFX will be played instead. This means the minimum of per_chain style SFX consists of only a single "chain" or "chain2" SFX.  
It also means you can leave gaps if you want the same chain sound to play for 2 consecutive chain sizes.
Example: 	
	x2 plays "chain2"(, "chain2_2", "chain2_3"...),  
	x3 plays "chain3"(, "chain3_2", "chain3_3"...),  
	...,  
	x13 plays "chain13"(, "chain13_2", ...),  
	x13+ plays "chain0"(, ...) 


#### combo_style

Change the way the combo SFX files are being used.  
Available options are "classic" and "per_combo". 

##### classic

The default option if not specified.  
For combos of any size this will play the SFX "combo" (,"combo2", "combo3", ...) [selected at random if more than one]

##### per_combo

Provide a SFX for each combo size. More than one variation may be provided for each size by appending _# to the filename where # is a number.  
If no file is provided for a certain combo size the first available lower combo SFX will be played instead. This means the minimum of per_combo style SFX consists of only a single "combo4" SFX.  
It also means you can leave gaps if you want the same chain sound to play for 2 consecutive combo sizes.  
Example:  
		+4 "combo4"(, "combo4_2", "combo4_3"...),  
		+5 "combo5"(, "combo5_2, "combo5_3"...),  
		...,   
		+20 "combo20"(, "combo20_2", ...)  
		+27 "combo27"(, "combo27_2", ...)  
While the combo size you may provide files for is not limited, combos above +27 will not send any more garbage, having no added value as a sound cue.


### Display configuration

Specifies how the character is displayed in character selection.

#### visible

Possible values are true or false.  
If set to false, the character is hidden in character selection but it will still get used if the opponent picks it.  
Visibility may also be controlled by the theme's characters.txt

#### flag

Originally intended to display flags for language specific versions of the same mod.  
An icon will be display next to the character's name in character select if a file with the same name as the value of this field is found in the flags folder of your active theme.


### Pop Effects configuration (PopFX)

Pop effects is the general name used for the animations that come out of panels after they match and the effects that rotate around the chain and combo cards.

#### popfx_style
The style of popfx to use, options:  
 "burst" (default) - Shows the burst image of the character coming out of panels and circling attack cards  
 "fade" - Shows the fade image of the character as the matched panels disappear  
 "fadeburst" - Shows both the burst and fade animations

#### popfx_burstRotate
If this option set to true, the burst effects are rotated about the center of the panel or card.
For the card burst the left of the frame will be pointing towards the center of the cards when rotation is on.
For the panel burst, the top left one will not be rotated and the bottom right one will be rotated 180. The ones inbetween will be rotated proportionally.
Default is false.

#### popfx_burstScale
The scale of the burst popfx, default is 1, 2 means twice the size, 0.5 half the size, etc.

#### popfx_fadeScale
The scale of the fade popfx, default is 1, 2 means twice the size, 0.5 half the size, etc.

-----------------------------------------------------------


## Graphic assets

You may use .png or .jpg/.jpeg for these.
.gif files are not supported by the framework Panel Attack uses so please refrain from asking devs to support that.

Assets will get scaled and stretched if they don't match the recommended size or aspect ratio.  
The per-file recommendations below are given for a resolution of 2560x1440. Using 1.5x/2x the size may look better at higher resolutions while 0.5x the size may look better on lower resolutions.  

You can use the Ctrl+Shift+Alt+C shortcut to reload character graphics in the game.

### Garbage assets

See https://cdn.discordapp.com/attachments/417706389813592068/874106744392007680/garbage_ref.png for an arrangement overview.

#### Filler sprites

Filler sprites are drawn first, then everything else is getting drawn on top, potentially obscuring the left/right/edge of a filler sprite.  
Putting things too close to the edge or the middle may cause unsightly cutoffs.  
Good use of face/face2 may alleviate these issues for the center.  

Aspect ratio: 1:1 (square)  
Recommended size: 96x96px

##### filler1

Filling up the garbage blocks.

##### filler2

Filling up the garbage blocks for blocks with height 3 and up, alternating with filler1


#### Center icon

The icon that will be drawn in the middle of the garbage piece.  
This will get drawn on top of the filler sprites.

##### face

Sprite for the center of garbage pieces of odd-numbered height (1, 3, ...)  
Aspect ratio: 1:1 (square)  
Recommended size: 96x96px

##### face2

Optional sprite that replaces face on garbage pieces of odd-numbered width  
Aspect ratio: 1:1 (square)  
Recommended size: 96x96px

For most mods this will be obsolete, it exists mainly to provide better support for garbage blocks with tiled backgrounds.

##### doubleface

Sprite for the center of garbage pieces of even-numbered height (2, 4, ...)  
Aspect ratio: 1:2  
Recommended size: 96x192px


#### Sides

These will get drawn on top of filler / center sprites.

##### "top", "bot"

Sprites for covering the top and bottom side of the garbage.  
They will get stretched to the (varying) width of the garbage.  
Recommended size: 12px high

##### "left", "right"

Sprites for the left and right side of the garbage.  
They will get stretched to the (varying) height of the garbage  
Recommended size: 48px wide


#### Corners

These will get drawn on top of filler / side sprites  

Aspect Ratio: 8:3
Recommended size: 48x18px  
"topleft", "botleft", "topright", "botright"  
The names say everything.


#### Clear sprites

Sprites that will be on display on each individual garbage panel when garbage is getting cleared.  

Aspect ratio: 1:1 (square)  
Recommended size: 96x96px

##### pop

Appearance for garbage panels after it got cleared but did not reveal the actual panel yet.

##### flash

On display when the garbage gets cleared initially, rapidly alternates with pop for a short time until it stays on pop.


### Other graphic assets

#### portrait

Display of the character ingame on the player 1 side.  

Aspect ratio: 1:2  
Recommended size: 576x1152px

#### portrait2

Display of the character ingame on the player 2 side.  

Aspect ratio: 1:2  
Recommended size: 576x1152px

If not present, portrait will get mirrored instead.  
This exists so that characters with unique asymmetrical features can retain them and appear correctly on both sides.

#### icon

Displays in character selection.  

Aspect ratio: 1:1 (square)  
Recommended size: 168x168px

#### burst

The image atlas used for the burst effects (PopFX)
The image should be 9 equal sized frames in a row, the first frame is used for the animation around the chain and combo cards
The left of the frame will be pointing towards the center of the cards when rotation is on.
Frames 2 to 9 are the animation used for the burst effect coming out of panels when they pop.

Aspect ratio of each individual frame: 1:1 (square)
Recommended size per frame: 96x96px (size of a 2x resolution panel)

#### fade

The image atlas used for the fade pop effects (PopFX)  
The image should be 9 equal sized frames in a row, the first frame is currently unused, frames 2 to 9 are the fade animation.
The fade animation is centered over the panel but smaller than a panel.

Aspect ratio of each individual frame: 1:1 (square)
Recommended size per frame: 64x64px (scaled down to 32 pixels centered on panel center, so gives 2x resolution)

-----------------------------------------------------------


## Sound Effects (SFX)

Allowed formats are .mp3, .ogg, .wav, .it, .flac.

Most SFX allow you to provide multiple variations. If multiple files are present for the same SFX, selection between the available files is random.  

### Attack SFX

SFX played on sending an attack.  
These will interrupt each other.  
If a combo chain is performed, the chain SFX will take priority.  
If a shock combo is performed, the shock SFX will take priority.  
If a shock chain is performed, the shock SFX will take priority.

#### combo

Played on performing combos depending on the combo_style set in the config.json.  
See the explanation of combo_style for details.  
If no combo SFX are provided at all, the default chain sound will be used instead.


#### chain

Played on performing chains, depending on the chain_style set in the config.json.  
See the explanation of chain_style for details.  
All other attack SFX fall back to this if not present.


#### shock

For shock matches and combos, provide a SFX for each match/combo size.  
More than one variation may be provided for each size by appending _# to the filename where # is a number.  
Example:		 
		+3 "shock3"(, "shock3_2, "shock3_3" ...),  
		+4 "shock4"(, "shock4_2, "shock4_3" ...),  
		...,  
		+7 "shock7"(, "shock7_2, ...)  
[DEPRECATED] "combo_echo", ("combo_echo2", "combo_echo3"...) will get used upon a +6 or +7 shock combo. These files have NO effect if shock files are present.


### Other SFX

All other SFX will randomly select from all variations if additional numbered files are provided such as file, file2, file3, file4.  
Unless written otherwise, these SFX do not have fallback sounds and won't play at all if no files are provided!

#### garbage_match

Played when the character matches a piece of garbage.

#### garbage_land

Played when garbage lands on the character's side.

#### selection

Played when selecting the character in character selection.

#### win

Played when the character wins the game.  
The theme's fanfare1 will play instead if this is missing.

#### "taunt_up"/"taunt_down"

Played when using the respective taunt input.  
This is forwarded to the enemy player.


-----------------------------------------------------------


## Music

Allowed formats are .mp3, .ogg, .wav, .it, .flac.  
.midi files are not supported by the framework Panel Attack uses so please refrain from asking devs to support that.

A character's music may be used depending on Panel Attack's audio settings and game mode.  
See the documentation of the music_style configuration for how this behaves.

### normal_music_start

Music that will play once before the normal_music loop starts to play.  
With classic music_style it plays once again every time the music switches from danger to normal.

### normal_music

Standard music of the character, will seamlessly restart from the beginning upon reaching the end (loop).

### danger_music_start

Music that will play once before the danger_music loop starts to play.  
With classic music_style it plays once again every time the music switches from normal to danger.

### danger_music

Music that will be used when a player is in danger, will restart from the beginning upon reaching the end (loop).
A player is considered as in danger if they have panels in the upper 3 rows of their screen.  
If the client's "danger music change-back delay" (audio configuration) is enabled they will only be considered out of danger if the upper 4 rows of their screen have no panels.  
  
If no danger_music is supplied, the normal_music will loop infinitely.


-----------------------------------------------------------


# Common issues

## Panel Attack doesn't show a certain sprite / play a certain SFX

Mod files are strictly case sensitive.  
They should always be written exactly as in these readmes and the extension should always be lower case.
While a mod that varies case in filenames may work fine on Windows, it won't display correctly on Linux/Unix systems.  

## Character X is too loud/quiet!

As mods are created by the community it is difficult to enforce a standard for volumes of music and SFX.  
A general recommendation for volume of music and voice lines is to normalize the track and then reduce its volume by 6dB.  
An option to adjust volume by character in Panel Attack itself does currently not exist.