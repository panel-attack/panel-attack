
local logger = require("logger")
local Player = require("Player")
local tableUtils = require("tableUtils")
local sceneManager = require("scenes.sceneManager")
local GameModes = require("GameModes")

-- A Battle Room is a session of vs battles, keeping track of the room number, wins / losses etc
BattleRoom =
  class(
  function(self, mode, roomData)
    assert(mode)
    self.mode = mode
    self.players = {}
    self.spectators = {}
    self.spectating = false
    self.trainingModeSettings = nil
    self.allAssetsLoaded = false
    self.ranked = false
    if roomData then
      -- this could come from online or replay
      if roomData.replayVersion then
        -- coming from a replay
        for i = 1, #roomData.players do
          local rpp = roomData.players[i]
          local player = Player(rpp.name, rpp.publicId)
          player.playerNumber = i
          player.wins = rpp.wins
          player.settings.panelId = rpp.settings.panelId
          player.settings.characterId = CharacterLoader.resolveCharacterSelection(rpp.settings.characterId)
          player.settings.inputMethod = rpp.settings.inputMethod
          player.settings.level = rpp.settings.level
          player.settings.difficulty = rpp.settings.difficulty
          --player.settings.levelData = rpp.settings.levelData
          self:addPlayer(player)
        end
      elseif roomData.create_room then
        -- coming from online
        if self.spectating then
          -- just initialize from message

        else
          self:addPlayer(LocalPlayer)
          -- find out which player in the message is not the local player
          -- create a Player for them
          -- apply their settings
          -- add to players table
        end
      end
    else
      -- no room creation data means we're exclusively local
      -- always use the global local player
      self:addPlayer(LocalPlayer)
      for i = 2, self.mode.playerCount do
        self.addPlayer(Player.getLocalPlayer())
      end
    end

    if self.mode.style ~= GameModes.Styles.CHOOSE then
      for i = 1, #self.players do
        self.players[i]:setStyle(self.mode.style)
      end
    end
  end
)

function BattleRoom.setWinCounts(self, winCounts)
  for i = 1, winCounts do
    self.players[i].wins = winCounts[i]
  end
end

function BattleRoom:setRatings(ratings)
  for i = 1, #self.players do
    self.players[i].rating = ratings[i]
  end
end

function BattleRoom:totalGames()
  local totalGames = 0
  for i = 1, #self.players do
    totalGames = totalGames + self.players[i].wins
  end
  return totalGames
end

-- Returns the player with more win count.
-- TODO handle ties?
function BattleRoom:winningPlayer()
  if #self.players == 1 then
    return self.players[1]
  else
    if self.players[1].wins >= self.players[2].wins then
      return self.players[1]
    else
      return self.players[2]
    end
  end
end

function BattleRoom:createMatch()
  self.match = Match(self)

  for i = 1, #self.players do
    self.match:addPlayer(self.players[i])
  end

  return self.match
end

function BattleRoom:addNewPlayer(name, publicId, isLocal)
  local player = Player(name, publicId, isLocal)
  player.playerNumber = #self.players+1
  self.players[#self.players+1] = player
  return player
end

function BattleRoom:addPlayer(player)
  player.playerNumber = #self.players+1
  self.players[#self.players+1] = player
end

function BattleRoom:updateLoadingState()
  local fullyLoaded = true
  for i = 1, #self.players do
    local player = self.players[i]
    if not characters[player.settings.characterId].fully_loaded or not stages[player.settings.stageId].fully_loaded then
      fullyLoaded = false
    end
  end

  self.allAssetsLoaded = fullyLoaded
end

function BattleRoom:refreshReadyStates()
  -- ready should probably be a battleRoom prop, not a player prop? at least for local player(s)?
  for playerNumber = 1, #self.players do
    self.players[playerNumber].ready = tableUtils.trueForAll(self.players, function(pc)
      return (pc.hasLoaded or pc.isLocal) and pc.settings.wantsReady
    end) and self.allAssetsLoaded
  end
end

function BattleRoom:allReady()
  -- ready should probably be a battleRoom prop, not a player prop? at least for local player(s)?
  for playerNumber = 1, #self.players do
    if not self.players[playerNumber].ready then
      return false
    end
  end

  return true
end

function BattleRoom:updateRankedStatus(rankedStatus, comments)
  if self.online and self.mode.selectRanked and rankedStatus ~= self.ranked then
    self.ranked = rankedStatus
    self.rankedComments = comments
    -- legacy crutches
    if self.ranked then
      match_type = "Ranked"
    else
      match_type = "Casual"
    end
  else
    error("Trying to apply ranked state to the match even though it is either not online or does not support ranked")
  end
end

function BattleRoom:startMatch(stageId, seed, replayOfMatch)
  -- lock down configuration to one per player to avoid macro like abuses via multiple configs
  -- if self.online and self.localPlayerNumber then
  --   GAME.input:requestSingleInputConfigurationForPlayerCount(1)
  -- elseif not self.online then
  --   GAME.input:requestSingleInputConfigurationForPlayerCount(#self.players)
  -- end

  local match = self:createMatch()

  match:setStage(stageId)
  match:setSeed(seed)

  if match_type == "Ranked" and not match.room_ratings then
    match.room_ratings = {}
  end

  match:start(replayOfMatch, true)

  replay = Replay.createNewReplay(match)
  GAME.match = match
  -- game dies when using the fade transition for unclear reasons
  sceneManager:switchToScene(self.mode.scene, {match = self.match}, "none")

  -- to prevent the game from instantly restarting, unready all players
  for i = 1, #self.players do
    self.players[i]:setWantsReady(false)
  end
end

function BattleRoom:abortMatch()
  --tbd
end

function BattleRoom:setStyle(styleChoice)
  -- style could be configurable per play instead but let's not for now
  if self.mode.style == GameModes.Styles.CHOOSE then
    self.style = styleChoice
    self.onStyleChanged(styleChoice)
  else
    error("Trying to set difficulty style in a game mode that doesn't support style selection")
  end
end

-- not player specific, so this gets a separate callback that can only be overwritten once
-- so the UI can update and load up the different controls for it
function BattleRoom.onStyleChanged(style, player)
end

function BattleRoom:update()
  -- here we fetch network updates and update the match setup if applicable

  -- if there are still unloaded assets, we can load them 1 asset a frame in the background
  StageLoader.update()
  CharacterLoader.update()

  if not self.match or not self.match.ready then
    -- the setup phase of the room
    self:updateLoadingState()
    self:refreshReadyStates()
    if self:allReady() then
      self:startMatch()
    end
  else
    -- the game phase of the room
  end
end

return BattleRoom