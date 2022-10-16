require("util")

local dirtyCharacterJson = "{\n\t\"id\":\"Giana\",\n\t\"name\":\"Giana\"\n\t\"chain_style\":\"per_chain\"\n\t\"music_style\":\"dynamic\"\n}"
local puzzleJson = "{\n  \"Version\": 2,\n  \"Puzzle Sets\": [\n    [\n      \"Set Name\": \"clear puzzle test\",\n      \"Puzzles\": [\n\t\t[\n          \"Puzzle Type\": \"clear\",\n          \"Do Countdown\": false,\n          \"Moves\": 1,\n          \"Stack\": \n           \"\n\t\t   [====]\n\t\t   [====]\n\t\t   [====]\n\t\t   [====]\n\t\t   [====]\n\t\t   [====]\n\t\t   [====]\n\t\t   [====]\n\t\t   [====]\n\t\t   920000\n\t\t   290000\n\t\t   920000\",\n        ],\n\t\t[\n          \"Puzzle Type\": \"clear\",\n          \"Do Countdown\": false,\n          \"Moves\": 0,\n          \"Stack\": \n           \"\n\t\t   [====]\n\t\t   [====]\n\t\t   [====]\n\t\t   [====]\n\t\t   [====]\n\t\t   [====]\n\t\t   [====]\n\t\t   [====]\n\t\t   020000\n\t\t   122[=]\n\t\t   245156\n\t\t   325363\",\n\t\t   \"Stop\": 60\n        ],\n      ]\n    ],\n  ]\n}"
local themeJson = "{\n\"healthbar_frame_Pos\": [-17, -4],\n\"healthbar_frame_Scale\": 3,\n\"healthbar_Pos\": [-13, 148],\n\"healthbar_Scale\": 1,\n\"healthbar_Rotate\": 0,\n\"prestop_frame_Pos\": [100, 1090],\n\"prestop_frame_Scale\": 1,\n\"prestop_bar_Pos\": [110, 1097],\n\"prestop_bar_Scale\": 1,\n\"prestop_bar_Rotate\": 0,\n\"prestop_Pos\": [120, 1105],\n\"prestop_Scale\": 1,\n\"stop_frame_Pos\": [100, 1120],\n\"stop_frame_Scale\": 1,\n\"stop_bar_Pos\": [110, 1127],\n\"stop_bar_Scale\": 1,\n\"stop_bar_Rotate\": 0,\n\"stop_Pos\": [120, 1135],\n\"stop_Scale\": 1,\n\"shake_frame_Pos\": [100, 1150],\n\"shake_frame_Scale\": 1,\n\"shake_bar_Pos\": [110, 1157],\n\"shake_bar_Scale\": 1,\n\"shake_bar_Rotate\": 0,\n\"shake_Pos\": [120, 1165],\n\"shake_Scale\": 1,\n\"multibar_frame_Pos\": [110, 1100],\n\"multibar_frame_Scale\": 1,\n\"multibar_Pos\": [-13, 96],\n\"multibar_Scale\": 1\n}"
local squareBracketJson = "[\n\t\"id\":\"pokemon_trainer_kurtupo\"\n\t\"name\":\"Kurtupo\"\n\t\"chain_style\":\"per_chain\"\n\t\"music_style\":\"dynamic\"\n]"
local noWhiteSpaceJson = "[\"id\":\"pokemon_trainer_kurtupo\",\"name\":\"Kurtupo\",\"chain_style\":\"per_chain\",\"music_style\":\"dynamic\"]"
local singleLineCommentJson = "{\n\t\"id\":\"pokemon_trainer_kurtupo\",\n\t// make this with comments if you really want to\n\t\"name\":\"Kurtupo\",\n\t\"chain_style\":\"per_chain\",\n\t\"music_style\":\"dynamic\"\n}"
local multiLineCommentJson = "{\n\t\"id\":\"pokemon_trainer_kurtupo\",\n\t/* make even more\n\telaborate\n\tcomments */\n\t\"name\":\"Kurtupo\",\n\t\"chain_style\":\"per_chain\",\n\t\"music_style\":\"dynamic\"\n}"

local invalidPuzzleJson = "{\"Version\":2,\"PuzzleSets\":[[\"SetName\":\"colour_thief\",\"Puzzles\":[[\"PuzzleType\":\"moves\",\"DoCountdown\":false,\"Moves\":3,\"Stack\":\"000010000010000040000020004420002240004420004410\",},]],]}"
local bracketlessYaml = "\"id\":\"pokemon_trainer_kurtupo\"\n\"name\":\"Kurtupo\"\n\"chain_style\":\"per_chain\"\n\"music_style\":\"dynamic\""

assert(json.isValid(dirtyCharacterJson))
assert(json.isValid(puzzleJson))
assert(json.isValid(themeJson))
assert(json.isValid(squareBracketJson))
assert(json.isValid(noWhiteSpaceJson))
assert(json.isValid(singleLineCommentJson))
assert(json.isValid(multiLineCommentJson))
assert(not json.isValid(invalidPuzzleJson))
assert(not json.isValid(bracketlessYaml))