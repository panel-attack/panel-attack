# Contributing Code

The best place to coordinate contributions is through the issue tracker and the [official Discord server](http://discord.panelattack.com).

If you have an idea, please reach out in the #pa-development channel of the discord or on github to make sure others agree and coordinate.  

Try to follow the following code guidelines when contributing:
- Separate functionality into separate files that only interact with each other as much as needed
- Avoid globals
- Make smaller methods
- Don’t duplicate code, break it into smaller reusable chunks and use that in both spots
- Writing tests for how the code should work is extremely beneficial
- Follow the formatting guidelines below
- Constants should be local to a file / scope unless they need to be shared everywhere
- Avoid the use of shortlived tables and consider pooling if you can't
- No use of luajit's ffi module

Pull requests are to be pulled against the `beta` branch.  

## Formatting Guidelines

- Constants should be `ALL_CAPS_WITH_UNDERSCORES_BETWEEN_WORDS`
- Class names start with a capital like `BattleRoom`
- All other names use `camelCase`
- You should set your editor to use 2 spaces of identation. (not tabs)
- Avoid lines longer than 140 characters
- All control flow like if and functions should be on multiple lines, not condensed into a single line. Putting it all on a single line can make it harder to follow the flow.

For those using VSCode we recommend using this [styling extension](https://marketplace.visualstudio.com/items?itemName=Koihik.vscode-lua-format) with the configuration file in the repository named VsCodeStyleConfig.lua-format

# Contributing Assets

## Legal concerns and licensing

There is no formal organization behind Panel Attack and there is none who possesses Panel Attack, it is the collective work of many individual contributors. This has legal implications when it comes to using assets in Panel Attack:  
We aren't lawyers but to our current understanding there are potential problems with the project not being able to act as a juridical person for the purpose of holding or buying copyright of assets or even being legally competent to sign any contracts.

Additionally Panel Attack is a project in the spirit of free open source software and no asset added to the project should make future users and contributors liable to consequences from using assets with unclear license status.  

Thus, in order to protect the project and its contributors, all new assets must be licensed under the [CC BY-SA](https://creativecommons.org/licenses/by-sa/4.0/) or other CC licenses. Excluded are CC licenses using the ND (no derivatives) clause as we feel this restriction to be too limiting for the nature of the project.

## Technicalities

Please ensure the following requirements are met for submitting pull requests containing assets:
- All assets are mentioned by filepath and name in the repository's license file with the correct license and copyright holder
- All assets additionally have the license and copyright notice stored in their metadata
  - If the copyright holder provided a link to their web presence, it has to be included in the metadata as well
  - For music only:
    - Music should additionally include a title and artist in the respective metadata fields
    - If music was created specifically for use in Panel Attack the metadata should also contain link to the Panel Attack website

Project files with the purpose to facilitate the creation of future derivatives are to be submitted to the [panel-attack/panel-attack-resources](https://github.com/panel-attack/panel-attack-resources) repository.

## Coordination

Cohesiveness is a difficult task in a community of voluntary contributors but a much desired quality in a video game.

Please use the [official Discord server](http://discord.panelattack.com) to coordinate with others in the #pacci channel in advance if you wish to contribute.  
