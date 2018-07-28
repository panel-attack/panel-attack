PA sound loading rules to implement (draft)

Music directory priority:
1. Sounds/chosen sounds dir/characters/character name/
2. Sounds/chosen sounds dir/music/
3. sounds/default sounds dir/music/

If a "normal" music file is found in a folder, only use music from that folder, 
don't try to fail back to a default folder.
(we don't want to use danger music that has nothing to do with what the user specified
as the normal music)

We'll use a similar rule for character SFX.  If the user specified a "chain" sound file, and 
nothing else in that character's folder, we won't want to use other sound effects from default characters
for SFX like "garbage_match".  (Some characters won't have a "garbage_match" sound effect).
An exception to this is if a user specified a "chain" sound file, and no "combo" sound file,
we'll use their "chain" file for "combo" events.



