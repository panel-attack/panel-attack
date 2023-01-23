local class = require("class")
local util = require("util")
local tableUtil = require("tableUtil")
local logger = require("logger")
local characterLoader = require("character_loader")
local stageLoader = require("stage_loader")
local GameModes = require("GameModes")

local players = {}
-- stage
-- character
-- level
-- panels
-- ranked
-- ready
-- playerNumber
-- rating

local MatchSetup = class(
  function(match, playerCount, mode, online)
    match.playerCount = playerCount
    match.mode = mode
    match.online = online
    for i = 1, playerCount do
      players[i] = {}
      players[i].rating = {}
      if not online then
        players[i].isLocal = true
      end
    end

    if mode.style == GameModes.Styles.Choose then
      -- default mode to classic
      match.style = GameModes.Styles.Classic
    else
      match.style = mode.style
    end

  end
)

function MatchSetup.setStage(player, stageId)
  if stageId ~= players[player].stageId then
    stageId = stageLoader.resolveStageSelection(stageId)
    players[player].stageId = stageId
    stageLoader.load(stageId)
  end
end

function MatchSetup.setCharacter(player, characterId)
  if characterId ~= players[player].characterId then
    characterId = characterLoader.resolveCharacterSelection(characterId)
    players[player].characterId = characterId
    characterLoader.load(characterId)
  end
end

-- panels don't have an id although they should have one
function MatchSetup.setPanels(player, panelId)
  -- panels are always loaded
  if panels[panelId] then
    players[player].panelId = panelId
  else
    -- default back to player panels always
    players[player].panelId = config.panels
  end
end

function MatchSetup.setRanked(player, wantsRanked)
  players[player].wantsRanked = wantsRanked
end

function MatchSetup.setWantsReady(player, wantsReady)
  players[player].wantsReady = wantsReady
end

function MatchSetup.setLoaded(player, hasLoaded)
  players[player].hasLoaded = hasLoaded
end

function MatchSetup.setRating(player, rating)
  if players[player].rating.new then
    players[player].rating.old = players[player].rating.new
  end
  players[player].rating.new = rating
end

function MatchSetup.setPuzzleFile(player, puzzleFile)
  players[player].puzzleFile = puzzleFile
end

function MatchSetup.setTrainingFile(player, trainingFile)
  players[player].trainingFile = trainingFile
end

function MatchSetup.setStyle(styleChoice)
  style = styleChoice
end

function MatchSetup:setSpeed(speed)
  self.speed = speed
end

function MatchSetup:setWinCount(player, winCount)
  players[player].winCount = winCount
end

function MatchSetup:setLevel(player, level)
  players[player].level = level
end

function MatchSetup:setReady(player, ready)
  players[player].ready = ready
end

function MatchSetup:setCursorPositionId(player, cursorPositionId)
  players[player].cursorPositionId = cursorPositionId
end

function MatchSetup:updateRankedStatus(rankedStatus, comments)
  self.ranked = rankedStatus
  self.rankedComments = comments
end

function MatchSetup:abort()
  self.abort = true
end

function MatchSetup:start(stageId, seed)
  self.stage = stageLoader.resolveStageSelection(stageId)
  current_stage = self.stage

  GAME.match = Match("vs", GAME.battleRoom)
  if seed then
    GAME.match.seed = seed
  elseif self.online and #players > 1 then
    GAME.match.seed = self:generateSeed()
  else
    -- calling the Match constructor automatically creates a seed on it
  end
  
  if match_type == "Ranked" then
    GAME.match.room_ratings = self.currentRoomRatings
    GAME.match.my_player_number = self.my_player_number
    GAME.match.op_player_number = self.op_player_number
  end

  characterLoader.wait()
  stageLoader.wait()

  for playerId = 1, #players do
    if playerId == 1 then
      P1 = Stack{which = 1, match = GAME.match, is_local = true, panels_dir = self.players[self.my_player_number].panels_dir, level = self.players[self.my_player_number].level, character = self.players[self.my_player_number].character, player_number = 1}
  GAME.match.P1 = P1
  P2 = Stack{which = 2, match = GAME.match, is_local = true, panels_dir = self.players[self.op_player_number].panels_dir, level = self.players[self.op_player_number].level, character = self.players[self.op_player_number].character, player_number = 2}
  GAME.match.P2 = P2
    end
  end
end

function MatchSetup:generateSeed()
  local seed = 17
  seed = seed * 37 + players[1].rating
  seed = seed * 37 + players[2].rating;
  seed = seed * 37 + GAME.battleRoom.playerWinCounts[1];
  seed = seed * 37 + GAME.battleRoom.playerWinCounts[2];

  return seed
end


return MatchSetup