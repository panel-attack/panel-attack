-- this file is an attempt to sanitize the somewhat crazy messages the server sends during match setup
local ServerMessages = {}

function ServerMessages.sanitizeMenuState(menuState)
  --[[
    "b_menu_state": {
        "character_is_random": "__RandomCharacter",
        "stage_is_random": "__RandomStage",
        "character_display_name": "",
        "cursor": "__Ready",
        "panels_dir": "panelhd_basic_mizunoketsuban",
        "ranked": true,
        "stage": "__RandomStage",
        "character": "__RandomCharacter",
        "level": 5,
        "inputMethod": "controller"
    },

    or 

    "character_is_random": "__RandomCharacter",
    "stage_is_random": "__RandomStage",
    "character_display_name": "Dragon",
    "cursor": "__Ready",
    "ready": true,
    "level": 5,
    "wants_ready": true,
    "ranked": true,
    "panels_dir": "panelhd_basic_mizunoketsuban",
    "character": "pa_characters_dragon",
    "stage": "pa_stages_wind",
    "loaded": true
  --]]

  local sanitized = { sanitized = true}
  sanitized.panelId = menuState.panels_dir
  sanitized.characterId = menuState.character
  if menuState.character_is_random ~= random_character_special_value then
    sanitized.selectedCharacterId = menuState.character_is_random
  end
  sanitized.stageId = menuState.stage
  if menuState.stage_is_random ~= random_stage_special_value then
    sanitized.selectedStageId = menuState.stage_is_random
  end
  sanitized.level = menuState.level
  sanitized.wantsRanked = menuState.ranked

  sanitized.wantsReady = menuState.wants_ready
  sanitized.hasLoaded = menuState.loaded
  sanitized.ready = menuState.ready

  -- ignoring cursor for now
  --sanitized.cursorPosCode = menuState.cursor
  -- categorically ignoring character display name


  return sanitized
end

function ServerMessages.sanitizeCreateRoom(message)
  -- how these messages look
  --[[
  "a_menu_state": {
        see sanitizeMenuState
    },
    "b_menu_state": {
        see sanitizeMenuState
    },
    "create_room": true,
    "your_player_number": 2,
    "op_player_number": 1,
    "ratings": [{
            "new": 1391,
            "league": "Silver",
            "old": 1391,
            "difference": 0
        }, {
            "league": "Newcomer",
            "placement_match_progress": "0/30 placement matches played.",
            "new": 0,
            "old": 0,
            "difference": 0
        }
    ],
    "opponent": "oh69fermerchan",
    "rating_updates": true
}
  ]]--
  local players = {}
  players[1] = ServerMessages.sanitizeMenuState(message.a_menu_state)
  -- the recipient is "you"!
  players[1].playerNumber = message.your_player_number
  players[1].name = config.name

  players[2] = ServerMessages.sanitizeMenuState(message.b_menu_state)
  players[2].name = message.opponent
  players[2].playerNumber = message.op_player_number

  if message.rating_updates then
    players[1].ratingInfo = message.ratings[1]
    players[2].ratingInfo = message.ratings[2]
  end

  return { create_room = true, sanitized = true, players = players}
end

function ServerMessages.toServerMenuState(player)

end

return ServerMessages