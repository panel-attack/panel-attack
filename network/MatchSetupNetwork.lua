local tableUtils = require("tableUtils")
local MatchSetup = require("MatchSetup")
local GameModes = require("GameModes")

local MatchSetupNetwork = class(
  function(self)
  end
)

function MatchSetupNetwork:hasActiveMatchSetup()
  return self.matchSetup ~= nil
end

function MatchSetupNetwork:createMatchSetup(message)
  -- for future online modes, the server communication should be rewritten
  -- the message should then contain game mode and a more generic array for transmitting player information
  self.matchSetup = MatchSetup(GameModes.TwoPlayerVersus, true, message.your_player_number)
  self:applyMenuState(1, message.a_menu_state)
  self:applyMenuState(2, message.b_menu_state)

  if message.rating_updates then
    self.matchSetup.setRating(1, message.rating[1].new)
    self.matchSetup.setRating(2, message.rating[2].new)
  end
end

function MatchSetupNetwork:enterMatchAsSpectator(message)
  self.matchSetup = MatchSetup(GameModes.TwoPlayerVersus, true)
  self:applyMenuState(1, message.a_menu_state)
  self:applyMenuState(2, message.b_menu_state)

  if message.rating_updates then
    self.matchSetup.setRating(1, message.rating[1].new)
    self.matchSetup.setRating(2, message.rating[2].new)
  end

  if message.win_counts then
    self:applyWinCounts(message.win_counts)
  end

  if message.replay_of_match_so_far then
    --TODO maybe we can manage to get this out of mainloop this time around to unglobal it
    replay_of_match_so_far = message.replay_of_match_so_far
    self.matchSetup:start(message.stage, replay_of_match_so_far.vs.seed)
  end
end

function MatchSetupNetwork:update()
  if not self.matchSetup then
    local roomCreationMessages = self:getRoomCreationMessages()
    -- not sure but I assume order *could* be important
    for _, message in ipairs(roomCreationMessages) do
      self:applyByMessageType(message)
    end
  else
    local updateMessages = self:getUpdateMessages()
    -- order likely important for menu updates
    for _, message in ipairs(updateMessages) do
      self:applyByMessageType(message)
    end
  end
end

function MatchSetupNetwork:getRoomCreationMessages()
  return server_queue:pop_next_with("create_room", "spectate_request_granted")
end

function MatchSetupNetwork:getUpdateMessages()
  return server_queue:pop_all_with(
    "win_counts",
    "menu_state",
    "ranked_match_approved",
    "leave_room",
    "match_start",
    "ranked_match_denied"
  )
end

--helper function to get the player number of the opponent if there is a local player in the room
local function getOpponentPlayerNumber(matchSetup)
  local players = {1, 2}
  table.remove(players, matchSetup.localPlayerNumber)
  -- after removing the player number, only the opponent number remains...
  return players[1]
end

function MatchSetupNetwork:applyByMessageType(message)
  if message.win_counts then
    self:applyWinCounts(message.win_counts)
  elseif message.menu_state then
    -- the server sends this in at least 2 different variants depending on if we're spectating or not
    if not message.player_number then
      -- if there is no player number this implicitly means it's the menu state of our opponent!
      message.player_number = getOpponentPlayerNumber(self.matchSetup)
    end
    self:applyMenuState(message.player_number, message.menu_state)
  elseif message.ranked_match_approved or message.ranked_match_denied then
    self:applyRankedStatus(message)
  elseif message.leave_room then
    self.matchSetup:leave()
  elseif message.match_start then
    self:startMatch(message)
  elseif message.create_room then
    self:createMatchSetup(message)
  elseif message.spectate_request_granted then
    self:enterMatchAsSpectator(message)
  end
end

function MatchSetupNetwork:applyMenuState(player, menuState)
  self.matchSetup:setRanked(player, menuState.ranked)
  self.matchSetup:setStage(player, menuState.stage)
  self.matchSetup:setCharacter(player, menuState.character)
  self.matchSetup:setLevel(player, menuState.level)
  self.matchSetup:setPanels(player, menuState.panels_dir)
  self.matchSetup:setReady(player, menuState.ready)
  self.matchSetup:setWantsReady(player, menuState.wants_ready)
  self.matchSetup:setCursorPositionId(player, menuState.cursor)
end

function MatchSetupNetwork:applyWinCounts(winCounts)
  for playerId = 1, #winCounts do
    self.matchSetup.setWinCount(playerId, winCounts[playerId])
  end
  -- maybe matchSetup and battleRoom should actually be the same
  GAME.battleRoom:updateWinCounts(winCounts)
end

function MatchSetupNetwork:applyRankedStatus(message)
  local comments = nil
  if message.reasons then
    comments = message.reasons
  elseif message.caveats then
    comments = message.caveats
  end

  self.matchSetup:updateRankedStatus(message.ranked_match_approved, comments)
end

function MatchSetupNetwork:leaveMatchSetup()
  self.matchSetup.abort()
end

function MatchSetupNetwork:startMatch(message)
  local seed = nil
  if message.seed then
    seed = message.seed
  elseif replay_of_match_so_far and replay_of_match_so_far.vs and replay_of_match_so_far.vs.seed then
    seed = replay_of_match_so_far.vs.seed
  end

  self.matchSetup:start(message.stage, seed)
end

function MatchSetupNetwork:sendMenuState()
  local menuState = {}
  local mS = self.matchSetup
  local playerNumber = mS.localPlayerNumber
  menuState.character = mS.players[playerNumber].characterId
  menuState.character_display_name = characters[mS.players[playerNumber].characterId].display_name
  menuState.loaded = mS.players[playerNumber].hasLoaded
  menuState.cursor = mS.players[playerNumber].cursorPositionId
  menuState.panels_dir = mS.players[playerNumber].panels
  menuState.ranked = mS.players[playerNumber].wantsRanked
  menuState.stage = mS.players[playerNumber].stageId
  menuState.wants_ready = mS.players[playerNumber].wantsReady
  menuState.ready = menuState.wants_ready and menuState.loaded
  menuState.level = mS.players[playerNumber].level

  json_send({menu_state = menuState})
end
