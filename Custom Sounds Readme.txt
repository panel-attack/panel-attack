About Custom Sounds in Panel Attack

Currently, sound files with the following extensions are supported:  .mp3, .ogg, .it.  

NOTE: File and folder names are Case-SeNsItIvE.  It's mostly all lower-case, except "SFX"
**IMPORTANT: Keep the default character folder names!**  You may place a txt file with your character's name
to help you remember which character it is. (For example: sounds/pokemon/characters/blargg/charmander.txt)

About Sound Effects (SFX):
-Game SFX go in:  "%appdata%/Panel Attack/sounds/[sound_pack_name_here]/SFX" and file names should be:
    Game SFX: "countdown" "go" "move", "swap", "land", "game_over"  Fanfares: "fanfare1", "fanfare2", "fanfare3" 
    Garbage Thuds: "thud_1", "thud_2", "thud_3"
    Panel pops: "pop1-1", "pop1-2", "pop1-3", ..., "pop1-10", "pop2-1", ..., "pop2-10", ..., "pop4-10"
-**Don't change character folder names!** Use the default character's name. Character SFX go in:  
  "%appdata%/Panel Attack/sounds/[sound_pack_name_here]/[character_name_here]"
-Note:  Providing just a "chain" or just a "combo" sound effect for a character is OK. It would 
  get used for all combos and chains.
-A character's combo sound effect should be named "combo"
-Depending on the current chain length, the chain SFX file with the appopriate file name will be played:
    x2/3 plays "chain",  x4 plays "chain2", x5 plays "chain_echo", x6+ plays "chain2_echo"
-If your character should make a sound when you clear garbage, include a sound file named "garbage_match"
-If you would like matching six metal blocks have a different sound effect, provide a "combo_echo" file.

About Music:
-Music files should be named "normal_music" and "danger_music"
-If your music has an intro (and for looping purposes, the intro should not be played again when the song ends),
   cut it from the main music file, and name it "normal_music_start" or "danger_music_start"
-Here is the order of folders in which the game looks for music.
    1. "%appdata%/Panel Attack/sounds/[chosen sound pack]/characters/[character name]" (**use default character name!**)
    2. "%appdata%/Panel Attack/sounds/[chosen sound pack]/music/[stage name]"
    3. "[built-in sounds directory]/music/[stage name]"

Note: If you include a "normal_music" file in a character or stage folder, 
  the game will not look for that character's music in other folders.


