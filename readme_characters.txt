Adding/modding characters: step by step instructions (Windows example):

1. Press the Windows key then type "%appdata%" without quotes and hit enter.
2. Look at the folders starting with "__" located in: %appdata%\Panel Attack\characters\ for a reference of where your files should go and how they should be named. 
   Folders starting with "__" will be ignored upon loading. You may choose to remove those "__" to mod the default characters
3. Create a folder with your character. The name of this folder is different from your character id and is kinda meaningless (see config.json below).
4. Place assets, sounds and json file in that folder with the proper names to add your data. Exhaustive list below.
5. Add/update characters.txt file in your theme folder. All characters will be loaded. This file specifies which ones get to be displayed in the lobby.

~~~~ Exhaustive list of a character folder data! ~~~~

Note: non-optional data that are missing will automatically get replaced by default ones so everything is optional in that sense

~~ [.json] ~~

- "config": this file holds data for the configuration of your character. The inside should look like that:
	- name: display name of this character, this value will be displayed in the lobby and will also serve as a fallback when trying to match your opponent's character
	- id: unique identifier of this character, this id should be specific (see note). [IF MISSING YOUR CHARACTER WILL BE IGNORED!]
	- (stage): this specifies which stage to select along the character when 'super selecting' it
	- (panels): this specifies which panels to select along the character when 'super selecting' it
	- (sub_ids): identifiers for other characters, this allows you to define a character bundle that encompasses multiple other characters (picked at random)
	- (visible): true/false, make it so the character is automatically hidden in the select screen (useful for character bundles)
	- (chain_style): "classic"/"per_chain", change the way the chain sfx are being used (classic mode refers to PPL style while per_chain is puyo puyo)
	- (flag): a flag may be displayed in the select screen based on that parameter, values are lowercase versions of the country codes from https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2, not all flags are available. 

Note: providing a specific, long enough id is a very good idea so that people renaming your mods folders still get properly match with other users regarding your mods. e.g. "mycharacter_myname"

~~ [.png, .jpg] ~~

- "topleft", "botleft", "topright", "botright", "top", "bot", "left", "right", "face", "pop", "doubleface", "filler1", "filler2", "flash": assets for garbages
- "portrait", "icon": display of your character ingame and in the lobby

~~ [.mp3, .ogg, .wav, .it, .flac] optional sounds are in parenthesis ~~

- "combo" (,"combo2", "combo3"...): combo [selected at random if more than one]
- ("combo_echo", ("combo_echo2", "combo_echo3"...)): six metal blocks combo [selected at random if more than one]
- Chain: depending on the current chain length and the defined mode, the appopriate sound file will be played:
    classic system: x2/3 plays "chain",  x4 plays "chain2", x5 plays "chain_echo", x6+ plays "chain2_echo"
    per_chain system: x2 "chain2"(, "chain2_2", "chain2_3"...), x3 "chain3"(, "chain3_2", "chain3_3"...), ..., x13 "chain13"(, "chain13_2", "chain13_3"...), x13+ "chain0"(, "chain0_2", "chain0_3"...) [selected at random if more than one]
- ("garbage_match" (,"garbage_match2", "garbage_match3"...)): played when clearing garbage [selected at random if more than one]
- ("garbage_land" (,"garbage_land2", "garbage_land3"...)): played when garbage lands on your side [selected at random if more than one]
- ("selection", ("selection2", "selection3"...)): upon selection [selected at random if more than one]
- ("win"(, "win2", "win3"...)): upon winning in 2P [selected at random if more than one]
- ("taunt_up"(, "taunt_up2", "taunt_up3"...)), ("taunt_down"(, "taunt_down2", "taunt_down3"...)): upon taunting with either inputs [selected at random if more than one]
- "normal_music": music that will be played while playing with this character if the option use_music_from's value is characters and your character gets picked
- ("danger_music"): music that will be used when a player is in danger (top of the screen) if the option use_music_from's value is characters and your character gets picked

Note: providing just a "chain" or just a "combo" SFX is OK. It would get used for all combos and chains.
Note: if your music has an intro, cut it from the main music file, and name it "normal_music_start" or "danger_music_start"