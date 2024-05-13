local GameModes = require("GameModes")
--local Replay = require("replay")
local levelPresets = require("LevelPresets")
local consts = require("consts")
local util = require("util")
local CharacterLoader = require("mods.CharacterLoader")


local ReplayV1 = {}

function ReplayV1.transform(legacyReplay)
  local r = {}
  local mode
  local gameMode
  if legacyReplay.vs then
    mode = "vs"
    if legacyReplay.vs.P2_char then
      gameMode = GameModes.getPreset("TWO_PLAYER_VS")
    else
      gameMode = GameModes.getPreset("ONE_PLAYER_VS_SELF")
    end
  elseif legacyReplay.time then
    mode = "time"
    gameMode = GameModes.getPreset("ONE_PLAYER_TIME_ATTACK")
  elseif legacyReplay.endless then
    mode = "endless"
    gameMode = GameModes.getPreset("ONE_PLAYER_ENDLESS")
  end
  local v1r = legacyReplay[mode]
  r.engineVersion = legacyReplay.engineVersion
  -- not saved in v1
  r.replayVersion = 1
  r.seed = v1r.seed
  r.ranked = v1r.match_type == "Ranked"
  r.stageId = v1r.stage or consts.RANDOM_STAGE_SPECIAL_VALUE
  r.gameMode = {
    stackInteraction = gameMode.stackInteraction,
    winConditions = gameMode.winConditions,
    gameOverConditions = gameMode.gameOverConditions,
    doCountdown = v1r.do_countdown,
  }

  if mode == "time" then
    r.gameMode.timeLimit = GameModes.getPreset("ONE_PLAYER_TIME_ATTACK").timeLimit
  end

  r.players = {}
  r.players[1] = {
    human = true,
    name = v1r.P1_name,
    -- win count only started to be saved sometime in v046
    wins = v1r.P1_win_count or 0,
    -- not saved in v1
    publicId = 1,
    settings = {
      characterId = CharacterLoader.fullyResolveCharacterSelection(v1r.P1_char),
      -- not saved in v1
      panelId = config.panels,
      -- not saved for engine version v046
      inputs = uncompress_input_string(v1r.in_buf),
    }
  }

  -- for some reason these are saved in different fields depending on game mode
  if gameMode.playerCount == 2 then
    r.players[1].settings.inputMethod = v1r.P1_inputMethod or "controller"
  else
    r.players[1].settings.inputMethod = v1r.inputMethod or "controller"
  end

  if v1r.P1_level then
    r.players[1].settings.level = v1r.P1_level
    r.players[1].settings.style = GameModes.Styles.MODERN
    -- suffices because modern endless/timeattack never had replays
    r.players[1].allowAdjacentColors = v1r.P1_level < 8
    r.players[1].settings.levelData = levelPresets.getModern(v1r.P1_level)
  else
    r.players[1].settings.difficulty = v1r.difficulty
    r.players[1].settings.style = GameModes.Styles.CLASSIC
    r.players[1].allowAdjacentColors = true
    r.players[1].settings.levelData = levelPresets.getClassic(v1r.difficulty)
    r.players[1].settings.levelData.startingSpeed = v1r.speed
    if v1r.difficulty == 1 and mode == "endless" then
      r.players[1].settings.levelData.colors = 5
    end
  end

  if v1r.P2_char then
    r.players[2] = {
      human = true,
      name = v1r.P2_name,
    -- win count only started to be saved sometime in v046
      wins = v1r.P2_win_count or 0,
      -- not saved in v1
      publicId = 2,
      settings = {
        characterId = CharacterLoader.fullyResolveCharacterSelection(v1r.P2_char),
        -- not saved in v1
        panelId = config.panels,
        -- not saved for engine version v046
        inputMethod = v1r.P2_inputMethod or "controller",
        inputs = uncompress_input_string(v1r.I),
        level = v1r.P2_level,
        style = GameModes.Styles.MODERN,
        levelData = levelPresets.getModern(v1r.P2_level)
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

  return r
end

return ReplayV1