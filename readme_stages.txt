Adding/modding stages: step by step instructions (Windows example):

1. Press the Windows key then type "%appdata%" without quotes and hit enter.
2. Look at the example folders located in: %appdata%\Panel Attack\stages\ for a reference of where your files should go and how they should be named. 
   Folders starting with "__" will be ignored upon loading.
Note: inner folders are also supported.
3. Create a folder with your stage. The name of this folder is different from your stage id and is kinda meaningless (see config.json below).
Note: while playing online, stages will be looked up by id, meaning you'll get to see your opponent's stages as long as you have one with the same id
4. Place assets and json file in that folder with the proper names to add your data. Exhaustive list below.
5. Optionally add/update stages.txt file in your theme folder. See the documentation in the themes readme for more details.

~~~~ Exhaustive list of a stage folder data! ~~~~

Note: non-optional data that are missing will automatically get replaced by default ones so they are kinda optional in that sense

~~ [.json] ~~

- "config": this file holds data for the configuration of your stage. The inside should look like that:
	- name: display name of this stage, this value will be displayed in the select screen
	- id: unique identifier of this stage, this id should be specific (see note). [IF MISSING YOUR STAGE WILL BE IGNORED!] 
	- (sub_ids): identifiers for other stages, this allows you to define a stage bundle that encompasses multiple other stages (picked at random)
	- (visible): true/false, make it so the stage is automatically hidden in the select screen (useful for stage bundles)
	- (music_style): The style of music to use, options: "normal"(default), "dynamic"(normal music and dynamic music will maintain the same play time stamp and fade seamlessly)

Note: providing a specific, long enough id is a very good idea so that people renaming your mods folders still get properly match with other users regarding your mods
e.g. "mystage_myname"

~~ [.png, .jpg] ~~

- "background": background for your stage, to be displayed while playing, should be 1280x720 px
- "thumbnail": thumbnail, to be displayed in the select screen, should be 80x45 px

~~ [.mp3, .ogg, .wav, .it, .flac] optional sounds are in parenthesis ~~

- "normal_music": music that will be played while playing on this stage if the option use_music_from's value is stage
- ("danger_music"): music that will be used when a player is in danger (top of the screen) if the option use_music_from's value is stage

Note: if your music has an intro, cut it from the main music file, and name it "normal_music_start" or "danger_music_start"