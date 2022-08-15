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
	- name: display name of this character, this value will be displayed in the lobby and will also serve as a fallback when trying to match your opponent's character
	- id: unique identifier of this character, this id should be specific (see note). [IF MISSING YOUR CHARACTER WILL BE IGNORED!]
	- (stage): this specifies which stage to select along the character when 'super selecting' it
	- (panels): this specifies which panels to select along the character when 'super selecting' it
	- (sub_ids): identifiers for other characters, this allows you to define a character bundle that encompasses multiple other characters (picked at random)
	- (visible): true/false, make it so the character is automatically hidden in the select screen (useful for character bundles)
	- (chain_style): "classic"/"per_chain", change the way the chain sfx are being used (classic mode refers to PPL style while per_chain is puyo puyo)
	- (flag): a flag may be displayed in the select screen based on that parameter, values are lowercase country codes from https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2, not all flags are available. 
	- (popfx_style): The style of popfx to use, options: "burst"(default), "fade", "fadeburst"
	- (popfx_rotation): If this option set to true, the burst popfx up, down, left, and right particles rotate to point to the direction they are moving in. Default is false.
	- (burst_scale): The scale of the burst popfx, default is 1, 2 means twice the size, 0.5 half the size, etc.
	- (fade_scale): The scale of the fade popfx, default is 1, 2 means twice the size, 0.5 half the size, etc.
	- (music_style): The style of music to use, options: "normal"(default), "dynamic"(normal music and dynamic music will maintain the same play time stamp and fade seamlessly)
Note: providing a specific, long enough id is a very good idea so that people renaming your mods folders still get properly match with other users regarding your mods. e.g. "mycharacter_myname"

~~ [.png, .jpg] ~~
Assets will get scaled and stretched if they don't match the recommended size/ratio. Using double the size may look better at higher resolutions.

Garbage assets:
See https://cdn.discordapp.com/attachments/417706389813592068/874106744392007680/garbage_ref.png for an arrangement overview.
- "topleft", "botleft", "topright", "botright": corner sprites, recommended size: 24x9
- "top", "bot": sprites for covering the top and bottom side of the garbage, gets stretched to the width of the garbage; recommended size: 6px high
- "left", "right": sprites for the left and right side of the garbage, gets stretched to the height of the garbage, recommended size: 24px wide
- "face": sprite for the center of garbage pieces of odd-numbered height (1, 3, ...), recommended size: 48x48
- "face2": optional sprite that can replace face on garbage pieces of odd-numbered width for tiling purposes, recommended size: 48x48
- "doubleface": sprite for the center of garbage pieces of even-numbered height (2, 4, ...), recommended size: 48x96
- "pop": appearance for garbage panels after it got cleared but did not reveal the actual panel yet, recommended size: 48x48
- "flash": sprite for when the garbage gets cleared, rapidly alternates with pop for a short time, recommended size: 48x48
- "filler1": filling up the garbage blocks, recommended to be 48x48
- "filler2": filling up the garbage blocks for blocks with height 3 and up, alternating with filler1, recommended size: 48x48

Other image assets:
- "portrait", "portrait2": display of your character ingame on the player 1/2 side, portrait2 is optional, recommended size: 288x576
- "icon": display in the lobby, recommended size: 84x84
- "burst" or "fade": The image used for popfx. The image should be 9 equal sized frames in a row, first frame is the telegraph, frames 2 to 9 are the burst or fade animation

~~ [.mp3, .ogg, .wav, .it, .flac] optional sounds are in parenthesis ~~
- "combo" (,"combo2", "combo3"...): combo [selected at random if more than one]
- ("combo_echo", ("combo_echo2", "combo_echo3"...)): six metal blocks combo [selected at random if more than one]
- Chain: depending on the current chain length and the defined mode, the appopriate sound file will be played:
    classic system: x2/3 plays "chain",  x4 plays "chain2", x5 plays "chain_echo", x6+ plays "chain2_echo"
    per_chain system: x2 "chain2"(, "chain2_2", "chain2_3"...), x3 "chain3"(, "chain3_2", "chain3_3"...), ..., x13 "chain13"(, "chain13_2", ...), x13+ "chain0"(, ...) [selected at random if more than one]
- ("garbage_match" (,"garbage_match2", "garbage_match3"...)): played when clearing garbage [selected at random if more than one]
- ("garbage_land" (,"garbage_land2", "garbage_land3"...)): played when garbage lands on your side [selected at random if more than one]
- ("selection", ("selection2", "selection3"...)): upon selection [selected at random if more than one]
- ("win"(, "win2", "win3"...)): upon winning in 2P [selected at random if more than one]
- ("taunt_up"(, "taunt_up2", "taunt_up3"...)), ("taunt_down"(, "taunt_down2", "taunt_down3"...)): upon taunting with either inputs [selected at random if more than one]
- "normal_music": music that will be played while playing with this character if the option use_music_from's value is characters and your character gets picked
- ("danger_music"): music that will be used when a player is in danger (top of the screen) if the option use_music_from's value is characters and your character gets picked

Note: providing just a "chain" or just a "combo" SFX is OK. It would get used for all combos and chains.
Note: if your music has an intro, cut it from the main music file, and name it "normal_music_start" or "danger_music_start"