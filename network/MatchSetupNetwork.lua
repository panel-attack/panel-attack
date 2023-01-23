local tableUtils = require("tableUtils")

local MatchSetupNetwork = class(
  function(self, matchSetup)
    self.matchSetup = matchSetup
  end
)

function MatchSetupNetwork:createMatchSetup()
  
end

function MatchSetupNetwork:update()
  if not self.matchSetup then
    local roomCreationMessages = self:getRoomCreationMessages()
    -- not sure but I assume order *could* be important
    for _, message in ipairs(roomCreationMessages) do
      
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
  local roomStartMessages = server_queue:pop_next_with("create_room", "character_select", "spectate_request_granted")

  return roomStartMessages
end

function MatchSetupNetwork:getUpdateMessages()
  local updateMessages = server_queue:pop_all_with(
    "win_counts",
    "menu_state",
    "ranked_match_approved",
    "leave_room",
    "match_start",
    "ranked_match_denied"
  )

  return updateMessages
end

function MatchSetupNetwork:applyByMessageType(message)
  if message.win_counts then
    self:applyWinCounts(message.win_counts)
  elseif message.menu_state then
    self:applyMenuState(message.menu_state)
  elseif message.ranked_match_approved or message.ranked_match_denied then
    self:applyRankedStatus(message)
  end
end

function MatchSetupNetwork:applyMenuState(menuState)
  local player = menuState.player_number
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

--[[ if msg.menu_state then
  self:updatePlayerFromMenuStateMessage(msg)
end

if msg.ranked_match_approved or msg.ranked_match_denied then
  self:updateRankedStatusFromMessage(msg)
end

if msg.leave_room then
  -- opponent left the select screen or server sent confirmation for our leave
  return {main_dumb_transition, {main_net_vs_lobby, "", 0, 0}}
end

if (msg.match_start or replay_of_match_so_far) and msg.player_settings and msg.opponent_settings then
  return self:startNetPlayMatch(msg)
end ]]