# Creating archives for drag+drop import

## Folder structure 
Archives always need to replicate the root folder structure of Panel Attack's save directory.  
This structure does not need to be complete but may only contain the folders you want to provide mods for. Other folders are ignored.

## Requirements

All non-puzzle mods need to at least contain a config.json file. Non-theme mods need this config.json to specify their id, otherwise they cannot be imported by drag and drop.

## Limitations

Attack pattern file import is currently not supported.

## Examples

### Valid package example

```
├── Mod Package
│   ├── characters
│   │   ├── Pikachu
│   │   |   ├── config.json
│   │   |   ├── more files
│   │   ├── Charizard
│   │   |   ├── config.json
│   │   |   ├── more files
│   ├── puzzles
│   │   ├── transition practice #1.json
│   │   ├── transition practice #2.json
│   ├── stages
│   ├── themes
│   │   ├── PPL
│   │   |   ├── config.json
│   │   |   ├── more files
```

### Invalid package example

```
├── Pikachu
|   ├── config.json
|   ├── more files
```

#### Correct

```
├── Pikachu
│   ├── characters
│   │   ├── Pikachu
│   │   |   ├── config.json
│   │   |   ├── more files
```