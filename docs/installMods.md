You can also find this file with prettier formatting at 
https://github.com/panel-attack/panel-attack/blob/beta/docs/installMods.md  
A video explanation is available at https://youtu.be/_SA1UeLwnSE

# How to install a mod

Panel Attack mods come in various shapes and forms.  
The traditional mods based on image and sound assets consist of theme, characters, stages and panels.  
But there are other files you can "install" in effectively the same way so they become available in Panel Attack:
Puzzles, training mode files and replays.

## Drag and Drop

Panel Attack supports the import of mods via drag and drop for characters, panels, stages and themes.  
Simply drag the .zip file with the mods onto Panel Attack while in a menu.  
This method only works on Windows, MacOS and Linux. It does not work on Android.

## Manual installation

Manual installation is necessary whenever you want to add files not supported by the drag and drop support or if you're on Android.

### Step 1: Find your Panel Attack user data folder 

Panel Attack saves most of its data in (somewhat hidden) user data folder so that multiple users of the same PC don't interfere with each other.  
Depending on your operating system the location is different.  
You can always find out about the save location by going to Options -> About -> System Info 

#### Windows

Press the Windows key then type "%appdata%" without quotes and hit enter.  
or  
Open the Windows explorer and change the explorer settings to show hidden files and directory (normally found under "View")  
After that you can find a directory "AppData" in your user directory (normally located at C:\Users\yourUserName).   
This folder will contain a directory called "Roaming" that holds application data for many applications.  
  
Regardless of which method you used, you should be able to find a Panel Attack directory in that location if you ever started Panel Attack before.

#### MacOS

In your Finder, navigate to  
  /Users/user/Library/Application Support/Panel Attack

#### Linux

Depending on whether your $XDG_DATA_HOME environment variable is set or not, the Panel Attack folder will be located in either  
  $XDG_DATA_HOME/love/  
  or  
  ~/.local/share/love/  

Note that running a panel.exe through wine and running a panel.love through a native love installation on the same machine may result in different save locations.

### Android

Android is a special case as it is very protective of its internal data and usually does not let users edit the Panel Attack save directory on non-rooted devices.  
That save data usually looks like this:
  /data/data/org.love2d.android/files/save/  

In early 2023 we changed Panel Attack to save its data in external (user-visible) storage:
  /Android/data/org.love2d.android/files/save/

This automatically applies for new installations but old installations may go through a migration process.  
Please ask in the discord for help with this.  

Due to the restrictiveness on Android it is recommended to connect the device to a computer and install mods via the computer's file browser.

### Step 2: Unpacking your mod and understanding where it belongs

#### Unpacking a package

This guide cannot know which exact mode you are trying to install but it is going to assume the "worst" case:  
You are trying to install a big package with a theme, various characters, stages, panels and maybe even puzzles.

Normally you will download such packs in a zip file and your first task is to unpack it.  
Inside you may find one or multiple folders. A good mod package will mimic the folder structure inside the Panel Attack directory, meaning you will at one point hopefully encounter a directory that contains one or multiple folders of these:
  - characters
  - panels
  - puzzles
  - replays (very uncommon but possible)
  - stages
  - themes
  - training

Inside of each of these folders you will find the mod folders that need to be in the directory with the same name inside the Panel Attack folder.  
Once you copied everything into its correct subfolder, you will have to restart Panel Attack in order for your new mods to show up!

#### Unpacking a single mod

For reference, still read the part about packages above.  
The way in which single mods are different is that they may not follow the folder structure above but instead you have to know based on where you got the link from what kind of mod it is.  
For single file mods (puzzles, training files, replays), you can just directly drop them into the respective folder.  
For asset type mods (characters, panels, stages, themes), make sure the folder you're copying directly contains the files for the mod and not another subfolder.  
Once you copied the mod into its correct subfolder, you will have to restart Panel Attack in order for your new mods to show up!


# How to manage your installed mods

If you don't want to use an installed mod anymore you have two options:  
  1. You can straight up delete its folder/files.
  2. You can disable the mod.

## Disabling mods

Panel Attack uses a universal convention:  
Directories and files that start with two underscores (__) will be ignored.  

So all you need to do to disable a character or stage is to rename its folder.  
You can also hide single replay, puzzle and training files by renaming them and adding __ in front.

## How to get the default mods back

You might have deleted the default mods that came with the game at some point and want to get them back. But how?  
There are two possibilities:  
  1. Download them again
  2. Let Panel Attack reinstall them

### Download them again

You can find all default assets of Panel Attack in the default_data folder at https://github.com/panel-attack/panel-attack/tree/beta/  
You can download the Panel Attack source code including the default mods from there any time and reinstall them via the instructions in this document.

### Let Panel Attack reinstall them

Panel Attack cannot function properly if you have no panels, no character or no stage available.  
For that reason it will always install the default characters again on start-up if no mods are available at all.  
That means to get the default characters/stages/panels back, you can simply temporarily disable all your installed mods by renaming them and then start Panel Attack.