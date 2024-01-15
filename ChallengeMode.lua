local logger = require("logger")
local class = require("class")
local ChallengeModePlayer = require("ChallengeModePlayer")
local GameModes = require("GameModes")
local sceneManager = require("scenes.sceneManager")
local MessageTransition = require("scenes.Transitions.MessageTransition")
local levelPresets = require("LevelPresets")
local consts = require("consts")

-- Challenge Mode is a particular play through of the challenge mode in the game, it contains all the settings for the mode.
local ChallengeMode =
  class(
  function(self, difficulty, stageIndex)
    self.mode = GameModes.getPreset("ONE_PLAYER_CHALLENGE")
    self.stages = self:createStages(difficulty)
    self.difficulty = difficulty
    self.difficultyName = loc("challenge_difficulty_" .. difficulty)
    self.continues = 0
    self.expendedTime = 0

    self:addPlayer(GAME.localPlayer)
    self.player = ChallengeModePlayer(#self.players + 1)
    self.player.settings.difficulty = difficulty
    self:addPlayer(self.player)
    self:assignInputConfigurations()
    self:setStage(stageIndex or 1)
  end,
  BattleRoom
)

ChallengeMode.numDifficulties = 6

function ChallengeMode:createStages(difficulty)
  local stages = {}

  local stageCount
  local framesToppedOutToLoseBase
  local framesToppedOutToLoseIncrement
  local lineClearGPMBase
  local lineClearGPMIncrement
  local lineHeightToKill
  local panelLevel

  if difficulty == 1 then
    stageCount = 10
    framesToppedOutToLoseBase = 60
    framesToppedOutToLoseIncrement = 3
    lineClearGPMBase = 3.3
    lineClearGPMIncrement = 0.45
    panelLevel = 2
    lineHeightToKill = 6
  elseif difficulty == 2 then
    stageCount = 11
    framesToppedOutToLoseBase = 66
    framesToppedOutToLoseIncrement = 6
    lineClearGPMBase = 5
    lineClearGPMIncrement = 0.7
    panelLevel = 4
    lineHeightToKill = 6
  elseif difficulty == 3 then
    stageCount = 12
    framesToppedOutToLoseBase = 72
    framesToppedOutToLoseIncrement = 12
    lineClearGPMBase = 15.5
    lineClearGPMIncrement = 0.7
    panelLevel = 6
    lineHeightToKill = 6
  elseif difficulty == 4 then
    stageCount = 12
    framesToppedOutToLoseBase = 72
    framesToppedOutToLoseIncrement = 30
    lineClearGPMBase = 15.5
    lineClearGPMIncrement = 1.5
    panelLevel = 6
    lineHeightToKill = 6
  elseif difficulty == 5 then
    stageCount = 12
    framesToppedOutToLoseBase = 72
    framesToppedOutToLoseIncrement = 240
    lineClearGPMBase = 30
    lineClearGPMIncrement = 1.5
    panelLevel = 8
    lineHeightToKill = 6
  elseif difficulty == 6 then
    stageCount = 12
    framesToppedOutToLoseBase = 72
    framesToppedOutToLoseIncrement = 240
    lineClearGPMBase = 35
    lineClearGPMIncrement = 1.5
    panelLevel = 10
    lineHeightToKill = 6
  else
    error("Invalid challenge mode difficulty level of " .. difficulty)
  end

  for stageIndex = 1, stageCount, 1 do
    local incrementMultiplier = stageIndex - 1
    local stage = {}
    stage.attackSettings = self:getAttackSettings(difficulty, stageIndex)
    stage.healthSettings = {
      framesToppedOutToLose = framesToppedOutToLoseBase + framesToppedOutToLoseIncrement * incrementMultiplier,
      lineClearGPM = lineClearGPMBase + lineClearGPMIncrement * incrementMultiplier,
      lineHeightToKill = lineHeightToKill,
      riseSpeed = levelPresets.getModern(panelLevel).startingSpeed
    }
    stage.playerLevel = panelLevel
    stage.expendedTime = 0
    stage.index = stageIndex

    stages[stageIndex] = stage
  end

  return stages
end

function ChallengeMode:attackFilePath(difficulty, stageIndex)
  for i = stageIndex, 1, -1 do
    local path = "default_data/training/challenge-" .. difficulty .. "-" .. i .. ".json"
    if love.filesystem.getInfo(path) then
      return path
    end
  end

  return nil
end

function ChallengeMode:getAttackSettings(difficulty, stageIndex)
  local attackFile = readAttackFile(self:attackFilePath(difficulty, stageIndex))
  assert(attackFile ~= nil, "could not find attack file for challenge mode")
  return attackFile
end

function ChallengeMode:recordStageResult(winners, gameLength)
  local stage = self.stages[self.stageIndex]
  stage.expendedTime = stage.expendedTime + gameLength
  self.expendedTime = self.expendedTime + gameLength

  if #winners == 1 then
    -- increment win count on winning player if there is only one
    winners[1]:incrementWinCount()

    if winners[1] == self.player then
      self.continues = self.continues + 1
    else
      if self.stages[self.stageIndex + 1] then
        self:setStage(self.stageIndex + 1)
      else
        -- completed!
        local scene = sceneManager:createScene("MainMenu")
        local message = "Congratulations!\n You cleared " .. self.difficultyName .. " in " .. frames_to_time_string(self.expendedTime, true)
        local transition = MessageTransition(GAME.timer, 7, sceneManager.activeScene, scene, message)
        sceneManager:switchToScene(scene, transition)
      end
    end
  elseif #winners == 2 then
    -- tie, stay on the same stage
    -- but since the player didn't lose, they shouldn't have to pay the timer
    stage.expendedTime = stage.expendedTime - gameLength
    self.expendedTime = self.expendedTime - gameLength
  elseif #winners == 0 then
    -- this means an abort which is a LOSS because it's a local game and only manual abort is possible
    self.continues = self.continues + 1
  end
end

function ChallengeMode:onMatchEnded(match)
  -- TODO: call recordStageResult on top of what the regular BattleRoom does
  self.matchesPlayed = self.matchesPlayed + 1

  local winners = match:getWinners()
  -- an abort is always the responsibility of the local player in challenge mode
  -- so always record the result, even if it may have been an abort
  local gameTime = match.clock
  if match.doCountdown then
    gameTime = gameTime - (consts.COUNTDOWN_START  + consts.COUNTDOWN_LENGTH)
  end
  self:recordStageResult(winners, gameTime)
  if self.online and match:hasLocalPlayer() then
    self:reportLocalGameResult(winners)
  end

  for _, player in ipairs(self.players) do
    if player.human then
      player:setWantsReady(false)
    end
  end

  if match.aborted then
  -- match:deinit is the responsibility of the one switching out of the game scene
    match:deinit()

    -- in challenge mode, an abort is always a manual pause and leave by the local player
    local setupScene = sceneManager:createScene(self.mode.setupScene)
    sceneManager:switchToScene(setupScene)

    -- when challenge mode becomes spectatable, there needs to be a network abort that isn't leave_room for spectators
  end

  -- nilling the match here doesn't keep the game scene from rendering it as it has its own reference
  self.match = nil
  self.state = BattleRoom.states.Setup
end

function ChallengeMode:setStage(index)
  self.stageIndex = index
  GAME.localPlayer:setLevel(self.stages[index].playerLevel)

  local stageSettings = self.stages[self.stageIndex]
  self.player.settings.attackEngineSettings = stageSettings.attackSettings
  self.player.settings.healthSettings = stageSettings.healthSettings
  -- for replay display
  self.player.settings.stageIndex = self.stageIndex
  if stageSettings.characterId then
    self.player:setCharacter(stageSettings.characterId)
  else
    self.player:setCharacterForStage(self.stageIndex)
  end
  self.player:setStage("")
end

return ChallengeMode