Adding/modding characters: step by step instructions (Windows example):
1. Press the Windows key then type "%appdata%" without quotes and hit enter.
2. Look at the example folders located in: %appdata%\Panel Attack\characters\ for a reference of where your files should go and how they should be named. 
   Folders starting with "__" will be ignored upon loading.
3. Create a folder with your character. The name of this folder is different from your character id and is kinda meaningless (see config.json below).
4. Place assets, sounds and json file in that folder with the proper names to add your data. Exhaustive list below.
5. Optionally add/update characters.txt file in your theme folder. See the documentation in the themes readme for more details.

~~~~ Exhaustive list of a character folder data! ~~~~
Note: non-optional data that is missing will automatically get replaced by default ones so everything is optional in that sense

~~ [.json] ~~
- "config": this file holds data for the configuration of your character. The inside should look like that:
	Minimum options:
	- id: 
	  unique identifier of this character. IF MISSING YOUR CHARACTER MAY BE IGNORED!
	  your id should be long and unique so that the game can properly distinguish between different character mods of potentially the same character
	  it is generally recommended to add your username to the id to ensure its uniqueness, e.g. "Sil_Paper_Mario" for a character mod of Mario by user Sil based on the Paper Mario games
	- name: 
	  display name of this character, this value will be displayed in the lobby and will also serve as a fallback when trying to match your opponent's character
	  the folder name will be displayed if this value is missing
	Super select options:
	- (stage): this specifies which stage to select along the character when 'super selecting' it
	- (panels): this specifies which panels to select along the character when 'super selecting' it
	Bundle options:
	- (sub_ids): identifiers for other characters, this allows you to define a character bundle that encompasses multiple other characters (picked at random)
	Music and SFX options:
	- (music_style): The style of music to use, options: 
	  "normal" (default, music restarts between normal and danger upon getting into/out of danger)
	  "dynamic" (normal music and danger music will maintain the same play time stamp and crossfade seamlessly)
	- (chain_style): "classic"/"per_chain", change the way the chain sfx are being used (see sound SFX section for details)
	- (combo_style): "classic"/"per_combo", change the way the combo sfx are being used (see sound SFX section for details)
	Display options:
	- (visible): true/false, make it so the character is automatically hidden in the select screen (useful for character bundles)
	- (flag): originally intended for flags, anicon may be displayed in the select screen if a file with the same name is found in the flags folder of your theme
	PopFX options:
	- (popfx_style): The style of popfx to use, options: "burst" (default), "fade", "fadeburst"
	- (popfx_rotation): If this option set to true, the burst popfx up, down, left, and right particles rotate to point to the direction they are moving in. Default is false.
	- (burst_scale): The scale of the burst popfx, default is 1, 2 means twice the size, 0.5 half the size, etc.
	- (fade_scale): The scale of the fade popfx, default is 1, 2 means twice the size, 0.5 half the size, etc.

~~ IMAGE ASSETS ~~
~~ [.png, .jpg] ~~
Assets will get scaled and stretched if they don't match the recommended size/ratio.
The per-file recommendations below are given for a resolution of 1280x720. Using whole-number multiples of the size may look better at higher resolutions.

Garbage assets:
See https://cdn.discordapp.com/attachments/417706389813592068/874106744392007680/garbage_ref.png for an arrangement overview.
- corners, recommended size: 24x9px
	- "topleft", "botleft", "topright", "botright", the names say everything
- sides
	- "top", "bot": 
	  sprites for covering the top and bottom side of the garbage
	  get stretched to the width of the garbage
	  recommended size: 6px high
	- "left", "right": 
	  sprites for the left and right side of the garbage
	  get stretched to the height of the garbage
	  recommended size: 24px wide
- center icon
	- "face": 
	  sprite for the center of garbage pieces of odd-numbered height (1, 3, ...)
	  recommended size: 48x48px
	- "face2": 
	  optional sprite that replaces face on garbage pieces of odd-numbered width
	  recommended size: 48x48px
	- "doubleface": 
	  sprite for the center of garbage pieces of even-numbered height (2, 4, ...)
	  recommended size: 48x96px
- filler sprites, recommended size: 48x48px
  Filler sprites are drawn first, then everything else is getting drawn on top, potentially obscuring the left/right/edge of a filler sprite.
  Putting things too close to the edge or the middle may cause unsightly cutoffs.
  Good use of face/face2 may alleviate these issues for the center.
	- "filler1": filling up the garbage blocks
	- "filler2": filling up the garbage blocks for blocks with height 3 and up, alternating with filler1
- clear sprites, recommendded size: 48x48px
	- "pop": appearance for garbage panels after it got cleared but did not reveal the actual panel yet
	- "flash": sprite for when the garbage gets cleared, rapidly alternates with pop for a short time

Other image assets:
- "portrait", "portrait2": 
  display of your character ingame on the player 1/2 side, recommended size: 288x576
  if portrait2 is not provided a mirrored version of portrait will be used instead
- "icon": display in the lobby, recommended size: 84x84
- "burst" or "fade": The image used for popfx. The image should be 9 equal sized frames in a row, first frame is the telegraph, frames 2 to 9 are the burst or fade animation

~~ Sound Effects (SFX)
~~ [.mp3, .ogg, .wav, .it, .flac] ~~
Most SFX allow you to provide multiple variations. If multiple files are present for the same SFX, selection between the available files is random.
- Attack SFX
	- combo: 
		You may select one of two combo_styles, to be specified in the config.json of your character.

		classic system [DEFAULT]: 
			"combo" (,"combo2", "combo3"...): combo [selected at random if more than one]
		per_combo system: 
			Provide a sfx for each combo size. More than one variation may be provided for each size by appending _# to the filename where # is a number.
			If no file is provided for a certain combo size the first available lower combo sfx will be played instead. This means the minimum of per_combo style sfx consists of only a single "combo4" sfx.
			Example: 	
					+4 "combo4"(, "combo4_2", "combo4_3"...), 
					+5 "combo5"(, "combo5_2, "combo5_3"...), 
					...,
					+20 "combo20"(, "combo20_2", ...)
					+27 "combo27"(, "combo27_2", ...)
			While the combo size you may provide files for is not limited, combos above +27 will not send any more garbage, having no added value as a sound cue.
		If no combo sfx are provided at all, the default chain sound will be used instead.

	- chain: 
		You may select one of two systems, to be specified in the config.json of your character, per_chain is strongly suggested.

		per_chain system: 
			Provide a sfx for each chain length. More than one variation may be provided for each length by appending _# to the filename where # is a number.
			If no file is provided for a certain chain length the first available lower chain sfx will be played instead. This means the minimum of per_chain style sfx consists of only a single "chain" or "chain2" sfx.
			Example: 	
					x2 "chain2"(, "chain2_2", "chain2_3"...), 
					x3 "chain3"(, "chain3_2", "chain3_3"...), 
					..., 
					x13 "chain13"(, "chain13_2", ...), 
					x13+ "chain0"(, ...)
		classic system [DEPRECATED][DEFAULT]: 
			x2/3 plays "chain",  
			x4 plays "chain2", 
			x5 plays "chain_echo", 
			x6+ plays "chain2_echo"
		Due to backwards compatibility reason the classic system remains as the default.
		If you wish to use classic style chain sounds, you can use the per_chain system and add "chain" as "chain2", "chain2" as "chain4", "chain_echo" as "chain5" and "chain2_echo" as "chain6".

	- shock: 
		For shock matches and combos, provide a sfx for each match/combo size. 
		More than one variation may be provided for each size by appending _# to the filename where # is a number.
		Example:		
				+3 "shock3"(, "shock3_2, "shock3_3" ...),
				+4 "shock4"(, "shock4_2, "shock4_3" ...),
				...,
				+7 "shock7"(, "shock7_2, ...)
		[DEPRECATED] "combo_echo", ("combo_echo2", "combo_echo3"...) will get used upon a +6 or +7 shock combo. These files have no effect if shock files are present.
- Other SFX
  all other SFX will randomly select from all variations if additional numbered files are provided such as file, file2, file3, file4
  unless specified differently, other SFX do not have fallback sounds and won't play at all if no files are provided
  all other SFX are optional
	- "garbage_match": played when clearing garbage
	- "garbage_land": played when garbage lands on your side
	- "selection": upon character selection
	- "win": upon winning, the theme's fanfare1 will play instead if this is missing
	- "taunt_up"/"taunt_down": upon taunting with either inputs, this is forwarded to the enemy player

Note: The minimum SFX a character needs consists of only a "chain" SFX. It would get used for all attack SFX in that case.

~~ Music ~~
~~ [.mp3, .ogg, .wav, .it, .flac] ~~
A character's music may be used depending on Panel Attack's audio settings and game mode.
- "normal_music": 
  standard music of the character, will restart from the beginning upon reaching the end (loop)
- "normal_music_start" [optional]:
  music that will play once before the normal_music loop starts to play
  with classic music_style it plays once again every time the music switches from danger to normal
- "danger_music" [optional]: 
  music that will be used when a player is in danger (top of the screen), will restart from the beginning upon reaching the end (loop)
- "danger_music_start" [optional, only used if danger_music is present as well]:
  music that will play once before the danger_music loop starts to play
  with classic music_style it plays once again every time the music switches from normal to danger


~~~~ Brief description of character features ~~~~

~~ Super Select ~~
Super select is a mechanism that aims to provide a cohesive visual experience to the user by making it possible to automatically select a stage and/or panels upon character selection.
Upon holding the selection on a character in character select, a SUPER text will appear above. 
If the selection is held long enough for it to fill up, the stage/panels stated in the config.json will automatically be selected.
The player can always opt out of super selection by only short tapping a character selection.
Example:
{
	"id":"PPL_Bruno",
	"name":"Bruno",
	"stage":"ppl_fire3"
}
Upon super selecting Bruno, the stage with the id "ppl_fire3" would automatically get picked as well if available.

~~ Bundles ~~
By providing more than one id in the sub_ids field of the config.json, the game will randomly pick one of the sub_ids as your character instead.
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
