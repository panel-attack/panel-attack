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


## Contributing

The best place to coordinate contributions is through the issue tracker and the [official Discord server](http://discord.panelattack.com).

If you have an idea, please reach out in the #pa-development channel of the discord or on github to make sure others agree and coordinate.

After coordinating with others, post pull requests against the `beta` branch. 

Try to follow the following code guidelines when contributing:
- Separate functionality into separate files that only interact with each other as much as needed
- Avoid globals
- Make smaller methods
- Don’t duplicate code, break it into smaller reusable chunks and use that in both spots
- Writing tests for how the code should work is extremely beneficial
- Follow the formatting guidelines below
- Constants should be local to a file / scope unless they need to be shared everywhere
- Avoid the use of shortlived tables and consider pooling if you can't

## Formatting Guidelines

- Constants should be `ALL_CAPS_WITH_UNDERSCORES_BETWEEN_WORDS`
- Class names start with a capital like `BattleRoom`
- All other names use `camelCase`
- You should set your editor to use 2 spaces of identation. (not tabs)
- Set your column width to 1000
- All control flow like if and functions should be on multiple lines, not condensed into a single line. Putting it all on a single line can make it harder to follow the flow.

For those using VSCode we recommend using this [styling extension](https://marketplace.visualstudio.com/items?itemName=Koihik.vscode-lua-format) with the configuration file in the repository named VsCodeStyleConfig.lua-format

## Release schedule

**Beginning of the month:**  
beta feature development followed by a release

**Mid month:**  
Stop landing new features and only add bug fixes

**After last tournament of the month:**  
Merge beta into stable and release
Hot fix stable as needed

Release notes are posted in #panel-attack-updates on the discord when updates go out.


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

