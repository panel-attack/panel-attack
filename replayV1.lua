local GameModes = require("GameModes")
--local Replay = require("replay")
require("util")

local ReplayV1 = {}

function ReplayV1.loadFromFile(legacyReplay)
  local r = {}
  local mode
  local gameMode
  if legacyReplay.vs then
    mode = "vs"
    if legacyReplay.vs.P2_char then
      gameMode = GameModes.TWO_PLAYER_VS
    else
      gameMode = GameModes.ONE_PLAYER_VS_SELF
    end
  elseif legacyReplay.time then
    mode = "time"
    gameMode = GameModes.ONE_PLAYER_TIME_ATTACK
  elseif legacyReplay.endless then
    mode = "endless"
    gameMode = GameModes.ONE_PLAYER_ENDLESS
  end
  local v1r = legacyReplay[mode]
  r.engineVersion = legacyReplay.engineVersion
  -- not saved in v1
  r.replayVersion = 1
  r.seed = v1r.seed
  r.ranked = v1r.match_type == "Ranked"
  r.doCountdown = v1r.do_countdown
  r.stage = v1r.stage
  r.gameMode = {
    stackInteraction = gameMode.stackInteraction,
    winCondition = gameMode.winCondition,
    disallowAdjacentColors = gameMode.disallowAdjacentColors
  }

  if mode == "time" then
    r.gameMode.timeLimit = 120
  end

  r.players = {}
  r.players[1] = {
    name = v1r.P1_name,
    wins = v1r.P1_win_count,
    -- not saved in v1
    publicId = 1,
    settings = {
      characterId = v1r.P1_char,
      -- not saved in v1
      panelId = config.panels,
      -- not saved for engine version v046
      inputMethod = v1r.P1_inputMethod or "controller",
      inputs = uncompress_input_string(v1r.in_buf)
    }
  }

  if v1r.P1_level then
    r.players[1].settings.level = v1r.P1_level
    r.players[1].settings.style = GameModes.Styles.MODERN
    --r.players[1].settings.levelData = levelPresets.getModern(v1r.P1_level)
  else
    r.players[1].settings.difficulty = v1r.difficulty
    r.players[1].settings.speed = v1r.speed
    r.players[1].settings.style = GameModes.Styles.CLASSIC
    --r.players[1].settings.levelData = levelPresets.getClassic(v1r.difficulty)
    --r.players[1].settings.levelData.startingSpeed = v1r.speed
  end

  if v1r.P2_char then
    r.players[2] = {
      name = v1r.P2_name,
      wins = v1r.P2_win_count,
      -- not saved in v1
      publicId = 2,
      settings = {
        characterId = v1r.P2_char,
        -- not saved in v1
        panelId = config.panels,
        -- not saved for engine version v046
        inputMethod = v1r.P2_inputMethod or "controller",
        inputs = uncompress_input_string(v1r.I),
        level = v1r.P2_level,
        -- levelData = levelPresets.getModern(v1r.P2_level)
      }
    }
  end

  if v1r.duration then
    r.duration = v1r.duration
  else
    if #r.players == 1 then
      r.duration = string.len(r.players[1].settings.inputs)
    elseif #r.players == 2 then
      r.duration = math.min(string.len(r.players[1].settings.inputs), string.len(r.players[2].settings.inputs))
    end
  end

  -- done, overwrite the global so none has to deal with the old format!
  replay = r

  return r
end

return ReplayV1