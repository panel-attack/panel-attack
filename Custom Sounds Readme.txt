About Custom Sounds in Panel Attack

About sound files
The following extensions are supported: .mp3, .ogg, .it.  
File and folder names are Case-SeNsItIvE [it's mostly all lower-case, except "SFX"]
**IMPORTANT: Keep the default character folder names!**  You may place a txt file with your character's name
to help you remember which character it is [e.g. sounds/pokemon/characters/blargg/charmander.txt].

About Sound Effects (aka SFX) [optional SFX are in parenthesis]:
-Game SFX go in:  "%appdata%/Panel Attack/sounds/[sound_pack_name_here]/SFX" and file names should be:
  Game SFX: "countdown" "go" "move", "swap", "land", "game_over"  Fanfares: "fanfare1", "fanfare2", "fanfare3" 
  Garbage Thuds: "thud_1", "thud_2", "thud_3"  Menu: ("menu_move", "menu_validate", "menu_cancel") 
  Panel pops: "pop1-1", "pop1-2", ..., "pop1-10", "pop2-1", ..., "pop2-10", ..., "pop4-10"
-Character SFX go in:  "%appdata%/Panel Attack/sounds/[sound_pack_name_here]/[character_name_here]"
  *Note: providing just a "chain" or just a "combo" SFX is OK. It would get used for all combos and chains.
  Combo: "combo" (,"combo2", "combo3"...) [selected at random if more than one]
  Six metal blocks combo: ("combo_echo", ("combo_echo2", "combo_echo3"...)) [selected at random if more than one]
  Chain: depending on the current chain length, the appopriate sound file will be played:
    x2/3 plays "chain",  x4 plays ("chain2"), x5 plays ("chain_echo"), x6+ plays ("chain2_echo")
  Clear garbage: ("garbage_match")
  Selection: ("selection", ("selection2", "selection3"...)) [selected at random if more than one]
  Win: ("win"(, "win2", "win3"...)) [selected at random if more than one]

About Music:
-Music files should be named "normal_music" and "danger_music"
-If your music has an intro, cut it from the main music file, and name it "normal_music_start" or "danger_music_start"
-The game looks for music in the following folders order:
    1. "%appdata%/Panel Attack/sounds/[chosen sound pack]/characters/[character name]" (**use default character name!**)
    2. "%appdata%/Panel Attack/sounds/[chosen sound pack]/music/[stage name]"
    3. "[built-in sounds directory]/music/[stage name]"
 *Note: when searching for a sound file, it will stop at the first folder containing the searched file.