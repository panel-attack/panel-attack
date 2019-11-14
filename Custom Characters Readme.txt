Adding/modding characters:

Step by step instructions for adding/modding characters (Windows example):

1. Press the Windows key then type "%appdata%" without quotes hit enter.

2. See the folders located in: %appdata%\Panel Attack\characters\__Stock PdP_TA\ for a reference of where your assets should go and what files should be named.
   
Note: folders starting with "__" will be ignored upon loading. You may choose to remove those "__" to mod existing characters

3. Create a folder with your character id. That id should be specific enough so that people downloading your character don't struggle with merge. We recommend using a short suffix. e.g. pichu_gbc

Note: while playing online, characters will be looked up by id then by display name as a fallback

4. Place assets, sounds and txt file in that folder with the proper names to add your data. Exhaustive list below.

5. Set the "Use default characters" option to Off. 

6. Add/update characters.txt file in the assets folder. All characters will be loaded. This file specifies which ones get to be displayed in the lobby.

~~~~ Exhaustive list of a character folder data! ~~~~

- name.txt: display name of this character, this value will be displayed in the lobby and will also serve as a fallback when trying to match your opponent's character
- stage.txt: stage for this character, this feature is currently being improved, please wait a bit more!
- topleft.png, botleft.png, topright.png, botright.png, top.png, bot.png, left.png, right.png, face.png, pop.png, doubleface.png, filler1.png, filler2.png, flash.png: assets for garbages
- portrait.png, icon.png: display of your character ingame and in the lobby

Note: The following extensions are supported for all sound files: .mp3, .ogg, .it. Optional SFX are in parenthesis

- Combo: "combo" (,"combo2", "combo3"...): [selected at random if more than one]
- Six metal blocks combo: ("combo_echo", ("combo_echo2", "combo_echo3"...)) [selected at random if more than one]
- Chain: depending on the current chain length, the appopriate sound file will be played:
    x2/3 plays "chain",  x4 plays ("chain2"), x5 plays ("chain_echo"), x6+ plays ("chain2_echo")
- Clear garbage: ("garbage_match" (,"garbage_match2", "garbage_match3"...))  [selected at random if more than one]
- Selection: ("selection", ("selection2", "selection3"...)) [selected at random if more than one]
- Win: ("win"(, "win2", "win3"...)) [selected at random if more than one]

Note: providing just a "chain" or just a "combo" SFX is OK. It would get used for all combos and chains.

Music files should be named "normal_music" and "danger_music"
If your music has an intro, cut it from the main music file, and name it "normal_music_start" or "danger_music_start"
The game looks for music in the following folders, in this order:
    1. "%appdata%/Panel Attack/characters/[character id]"
    2. "%appdata%/Panel Attack/sounds/[chosen sound pack]/music/[character's stage name]"
    3. "[built-in sounds directory]/music/[character's stage name]"
 
 Note: when searching for a sound file, it will stop at the first folder containing the searched file.