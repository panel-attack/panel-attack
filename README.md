# Panel Attack Development

## Development Setup

Install the **32-bit** version of love (http://love2d.org/)

Clone a copy of the repository  
```
git clone https://github.com/panel-attack/panel-attack.git
```  
We recommend using [GitHub Desktop](https://desktop.github.com) as it manages login for you and makes working with git easier.
  
We recommend developing and running the game using [Visual Studio Code](https://code.visualstudio.com/).  
You can setup VSCode with a debugger and more [following this tutorial](https://sheepolution.com/learn/book/bonus/vscode).

Alternatively, you can edit with your own favorite text editor and run love from the command line

```
cd Panel-Attack
love ./
```

or via drag and drop with the repository folder (not recommended).


## Repository

The beta branch is where we do all main development.  

All pull requests require a review by a maintainer (or 1 review and written by a maintainer).  
Feature and bug commits are done by maintainers using squash merges.  
Merges are done by the maintainers as merge commits.  

Please check the [contribution guidelines](CONTRIBUTING.md) for further information.

## Release schedule

### Main releases

**Beginning of the month:**  
beta feature development followed by a release

**Mid month:**  
Stop landing new features and only add bug fixes

**After last tournament of the month:**  
Merge beta into stable and release
Hot fix stable as needed

Release notes are posted in #panel-attack-updates on the discord when updates go out.

### Canary releases

Canary releases are temporarily available via https://github.com/Endaris/panel-attack/releases, automatically generated with each push to the sceneRefactor development branch.  
We may adopt this for future releases on the main repository.

## Useful Lua Programming Tips

**Big comment**  
```Lua
--[[
--]]
```

**Comment parameter names inline**
```Lua
  return self:pop_all_ready_garbage(frame, true--[[just_peeking]])
```

Lua Manual  
https://www.lua.org/pil/contents.html  

Love2d Tutorial  
https://sheepolution.com/learn/book/contents



# For Maintainers

## Releasing

To make a release we create a love file and put it on the server. Change the name of the love file to the output of a command like this:  
    Stable:  
        `echo "panel-$(date -u "+%Y-%m-%d_%H-%M-%S").love"`  
    Beta:  
        `echo "panel-beta-$(date -u "+%Y-%m-%d_%H-%M-%S").love"`  

Secure copy the file to the server in correct folder on the server.  
    Stable:  
        `scp -i privatekey.pem panel-2022-06-25_03-50-14.love username@panelattack.com:updates`  
    Beta:  
        `scp -i privatekey.pem panel-2022-06-25_03-50-14.love username@panelattack.com:beta-updates`  

Test that the game updates properly.  

Post release notes in #panel-attack-updates on the discord.

### Releasing a new full release with auto updating

First make a love file, then copy that all into the auto updater folder and make that a love file.  
Then copy the windows files in to your release folder.  
Tack the autoupdater love file on the end of the exe.  
Release a zip of the whole release directory.  

More details and scripts to follow.

