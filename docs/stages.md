You can also find this file with prettier formatting at https://github.com/panel-attack/panel-attack/blob/beta/docs/stages.md  

This README consists of 3 parts.  
In part 1 some general thoughts on stage creation are discussed.  
In part 2 you can find an exhaustive list of all assets used for stages.  
In part 3 you can learn how to make your mod support different resolutions.

# How to approach stage creation

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

In the graphic assets reference for stages you will find specific pixel size recommendation for each asset.  
These recommendations are based on a window size of 2560x1440.  
You CAN choose to make your assets smaller, consider however that it is quite easy to reduce the size of your assets later on if you don't get a satisfying result on your own (lower resolution) machine.  
On the other hand, increasing resolution later later on is near impossible without a noticeable drop in quality.  

If you're unsure what this is all supposed to mean, try to follow the recommendations as closely as possible. 
If you can't manage to follow the recommended size for an asset, make sure its aspect ratio of your asset is correct as it will get stretched otherwise.

## Planning

The minimum stage consists of merely a single configuration file that records the unique identifier of the stage.  
You can play with it but it will be like playing without a stage at all.  

A stage mainly consists of three elements:  
- Background during gameplay
- Icon during character selection
- Music during gameplay
  
On top of that a configuration file.  

### Music

Generally it is strongly recommended for every stage to have music.  
If neither the selected character nor the picked stage have music, it can happen that no music will play at all!
  
In general it is completely fine to only add a normal_music.  
In high level gameplay, people will be "in danger" for the majority of the time, so that the switch between danger and normal is actually not very common in the first place.  

If you not supply a danger_music, there is no point in selecting a music_style as it steers the interaction between normal and danger music.  
Dynamic music is generally the preferred option as the seamless change between normal and danger music is more pleasing to the ear.  
It is however much more difficult for most songs to get them to work with dynamic music. 


# Stage configuration and asset list

## config.json

This file holds data for the configuration of your stage.

### Minimum configuration

Every config.json should specify the stage's id and its name.

#### id

The unique identifier of the stage. IF MISSING THE STAGE MAY BE IGNORED!  
The id should be long and unique so that the game can properly distinguish between different stage mods of potentially the same music/background.  
It is generally recommended to add your username to the id to ensure its uniqueness.  
For example "endaris_umineko_dir" for a stage mod of the song "dir" by user Endaris based on the Umineko no Naku Koro Ni games.

#### name

The display name of the stage.  
This value will be displayed in character selection and will also serve as a fallback when trying to load your opponent's stage if chosen by the server.  
The folder name will be displayed if this value is missing.

### Bundle options

#### sub_ids

Identifiers for other stages, this allows you to define a stage bundle that encompasses multiple other stages (picked at random).  

By providing more than one id in the sub_ids field, the game will randomly pick one of the sub_ids as your stage instead.  
Example:  
{  
	"id":"endaris_umineko_pack",  
	"name":"Umineko",  
	"sub_ids":["endaris_umineko_dir","endaris_umineko_nighteyes","endaris_umineko_goldenslaughterer"],  
}  
Commonly the stages in the sub_ids are made invisible by setting visible = false in their respective config.json:  
{  
	"id":"endaris_umineko_dir",  
	"name":"dir",  
	"visible":false  
}  

### Music options

#### music_style

Defines which music style should be used.  
Available options are "normal" and "dynamic".

##### normal

The default option that is used if music_style is not specified in the configuration.  
Music will restart the normal/danger music track upon getting into/out of danger.

##### dynamic

Normal music and danger music will maintain the same play time stamp and crossfade seamlessly.

### Display options

#### visible

Possible values are true or false.  
If set to false, the stage is hidden in character selection but may still get used if the opponent picks it.  
Visibility may also be controlled by the theme's stages.txt

-----------------------------------------------------------

## Graphic assets

You may use .png or .jpg for these.
.gif files are not supported by the framework Panel Attack uses so please refrain from asking devs to support that.  
Support for animated backgrounds is on the table but not available yet.  

Assets will get scaled and stretched if they don't match the recommended size or aspect ratio.  
The per-file recommendations below are given for a resolution of 2560x1440. Using 1.5x/2x the size may look better at higher resolutions while 0.5x the size may look better on lower resolutions.  

You can use the Ctrl+Shift+Alt+S shortcut to reload stage graphics in the game.

### thumbnail

The thumbnail that displays in the stage selection carousel inside of character selection.  
  
Aspect ratio: 16:9  
Recommended size: 160x90px

### background

The background of your stage that is displayed during gameplay.
    
Aspect ratio: 16:9  
Recommended size: 2560x1440px

-----------------------------------------------------------

## Music assets

Allowed formats are .mp3, .ogg, .wav, .it, .flac.  
.midi files are not supported by the framework Panel Attack uses so please refrain from asking devs to support that.

A stage's music may be used depending on Panel Attack's audio settings and game mode.  
See the documentation of the music_style configuration for how this behaves.

### normal_music_start

Music that will play once before the normal_music loop starts to play.  
With classic music_style it plays once again every time the music switches from danger to normal.

### normal_music

Standard music of the stage, will seamlessly restart from the beginning upon reaching the end (loop).

### danger_music_start

Music that will play once before the danger_music loop starts to play.  
With classic music_style it plays once again every time the music switches from normal to danger.

### danger_music

Music that will be used when a player is in danger, will restart from the beginning upon reaching the end (loop).
A player is considered as in danger if they have panels in the upper 3 rows of their screen.  
If the client's "danger music change-back delay" (audio configuration) is enabled they will only be considered out of danger if the upper 4 rows of their screen have no panels.  
  
If no danger_music is supplied, the normal_music will loop infinitely.