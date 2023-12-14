local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local CharacterSelect = require("scenes.CharacterSelect")
local class = require("class")
local tableUtils = require("tableUtils")
local logger = require("logger")
local input = require("inputManager")
local Label = require("ui.Label")

--@module CharacterSelectOnline
-- 
local CharacterSelectOnline = class(
  function (self, sceneParams)
    
    self.roomInitializationMessage = sceneParams.roomInitializationMessage
    self.players = {{}, {}}
    
    self.transitioning = false
    self.stateParams = {
      maxDisplayTime = nil,
      minDisplayTime = nil,
      sceneName = nil,
      sceneParams = nil,
      switchSceneLabel = nil
    }
    
    self.startTime = love.timer.getTime()
    self.state = nil -- set in customLoad

    self:load(sceneParams)
  end,
  CharacterSelect
)

CharacterSelectOnline.name = "CharacterSelectOnline"
sceneManager:addScene(CharacterSelectOnline)

CharacterSelectOnline.myPlayerNumber = nil
CharacterSelectOnline.opPlayerNumber = nil

local states = {DEFAULT = 1, INITIALIZE_ROOM = 2, SWITCH_SCENE = 3}

-- sets self.roomInitializationMessage
-- if a roomInitializationMessage is not received it returns a function to transition out of the room, otherwise returns nil
function CharacterSelectOnline:pollInitializationMessage()
  -- Poll for the room setup messages from the server
  local msg = server_queue:pop_next_with("create_room", "character_select", "spectate_request_granted")
  if msg then
    self.roomInitializationMessage = msg
  end
  -- gprint(loc("ss_init"), unpack(themes[config.theme].main_menu_screen_pos))
  if not do_messages() then
    self.state = states.SWITCH_SCENE
    self.stateParams = {
      startTime = love.timer.getTime(),
      maxDisplayTime = 5,  
      minDisplayTime = 1,
      sceneName = "MainMenu",
      switchSceneLabel = Label({text = loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), translate = false})
    }
  end
end

function CharacterSelectOnline:updateRankedStatusFromMessage(msg)
  if msg.ranked_match_approved then
    match_type = "Ranked"
    match_type_message = ""
    if msg.caveats then
      match_type_message = match_type_message .. (msg.caveats[1] or "")
    end
  elseif msg.ranked_match_denied then
    match_type = "Casual"
    match_type_message = (loc("ss_not_ranked") or "") .. "  "
    if msg.reasons then
      match_type_message = match_type_message .. (msg.reasons[1] or loc("ss_err_no_reason"))
    end
  end
end

-- updates one player based on the given menu state
-- different from updatePlayerStatesFromMessage that it only updates one player and works from a different message type
function CharacterSelectOnline:updatePlayerFromMenuStateMessage(msg)
  local player_number
  if GAME.battleRoom.spectating then
    -- server makes no distinction for messages sent to spectators between player_number and op_player_number
    -- messages are also always sent separately for both players so this does in fact cover both players
    player_number = msg.player_number
  else
    -- when being a player, server does not make a distinction for player_number as there are no game modes for 2+ players yet
    -- thus automatically assume op_player
    player_number = self.op_player_number
  end

  self:initializeFromMenuState(player_number, msg.menu_state)
  self:refreshBasedOnOwnMods(self.players[player_number])
  self:refreshLoadingState(player_number)
  self:refreshReadyStates()
end

function CharacterSelectOnline:refreshReadyStates()
  for playerNumber = 1, #self.players do
    self.players[playerNumber].ready =
        self.players[playerNumber].wants_ready and
        tableUtils.trueForAll(self.players, function(pc) return pc.loaded end)
  end
end

function CharacterSelectOnline:sendMenuState()
  local menuState = {}
  menuState.character = self.players[self.my_player_number].character
  menuState.character_is_random = (self.players[self.my_player_number].selectedCharacter ~= self.players[self.my_player_number].character) and self.players[self.my_player_number].selectedCharacter or nil
  menuState.character_display_name = self.players[self.my_player_number].character_display_name
  menuState.loaded = self.players[self.my_player_number].loaded
  -- menuState.cursor = self.players[self.my_player_number].cursor.positionId
  menuState.panels_dir = self.players[self.my_player_number].panels_dir
  menuState.ranked = self.players[self.my_player_number].ranked
  menuState.stage = self.players[self.my_player_number].stage
  menuState.stage_is_random = self.players[self.my_player_number].selectedStage
  menuState.wants_ready = self.players[self.my_player_number].wants_ready
  menuState.ready = self.players[self.my_player_number].ready
  menuState.level = self.players[self.my_player_number].level
  menuState.inputMethod = self.players[self.my_player_number].inputMethod
  for k, v in pairs(menuState) do
    if type(k) == "function" or type(v) == "function" or type(k) == "table" or type(v) == "table" then
      error("Trying to send an illegal object to the server\n" .. table_to_string(menuState))
    end
  end

  json_send({menu_state = menuState})
end

function CharacterSelectOnline:updateConfig()
  if not deep_content_equal(self.players[self.my_player_number], self.myPreviousConfig) then
    self:updateMyConfig()
    self:sendMenuState()
    self.myPreviousConfig = deepcpy(self.players[self.my_player_number])
  end
end

-- may return a function for transitioning into a different screen if the opponent left or the server confirmed the start of the game
-- returns nil if staying in select_screen
function CharacterSelectOnline:handleServerMessages()
  local messages = server_queue:pop_all_with("win_counts", "menu_state", "ranked_match_approved", "leave_room", "match_start", "ranked_match_denied")
  if self.roomInitializationMessage then
    messages[#messages+1] = self.roomInitializationMessage
    self.roomInitializationMessage = nil
  end
  for _, msg in ipairs(messages) do
    if msg.win_counts then
        GAME.battleRoom:updateWinCounts(msg.win_counts)
    end

    if msg.menu_state then
      self:updatePlayerFromMenuStateMessage(msg)
    end

    if msg.ranked_match_approved or msg.ranked_match_denied then
      self:updateRankedStatusFromMessage(msg)
    end

    if msg.leave_room then
      -- opponent left the select screen or server sent confirmation for our leave
      sceneManager:switchToScene("Lobby")
    end

    if (msg.match_start or replay_of_match_so_far) and msg.player_settings and msg.opponent_settings then
      -- update opponent character & stage with the resolved one
      msg.opponent_settings.character = self.players[self.op_player_number].character
      sceneManager:switchToScene("OnlineVsGame", {msg = msg})
    end
  end
end

function CharacterSelectOnline:updatePlayerNumbersFromMessage(msg)
  -- player_settings exists for spectate_request_granted but not for create_room or character_select
  -- on second runthrough we should still have data from the old select_screen, including player_numbers
  if msg.player_settings and msg.player_settings.player_number then
    self.my_player_number = msg.player_settings.player_number
  elseif msg.your_player_number then
    self.my_player_number = msg.your_player_number
  elseif CharacterSelectOnline.myPlayerNumber then
    self.my_player_number = CharacterSelectOnline.myPlayerNumber
    -- typical case while spectating, player_number is not sent again on consecutive game starts after the first
    logger.debug("We assumed our player number is still " .. self.my_player_number)
  else
    logger.error(loc("nt_player_err"))
    error(loc("nt_player_err"))
  end

  -- same for opponent_settings, read above
  if msg.opponent_settings and msg.opponent_settings.player_number then
    self.op_player_number = msg.opponent_settings.player_number
  elseif msg.op_player_number then
    self.op_player_number = msg.op_player_number
  elseif CharacterSelectOnline.opPlayerNumber then
    self.op_player_number = CharacterSelectOnline.opPlayerNumber
    -- typical case while spectating, player_number is not sent again on consecutive game starts after the first
    logger.debug("We assumed op player number is still " .. self.op_player_number)
  else
    logger.error(loc("nt_player_err"))
    error(loc("nt_player_err"))
  end

  CharacterSelectOnline.myPlayerNumber = self.my_player_number 
  CharacterSelectOnline.opPlayerNumber = self.op_player_number
end

function CharacterSelectOnline:updatePlayerStatesFromMessage(msg)
  if self.my_player_number == 2 and msg.a_menu_state ~= nil
    and msg.b_menu_state ~= nil then
    self:initializeFromMenuState(self.my_player_number, msg.b_menu_state)
    self:initializeFromMenuState(self.op_player_number, msg.a_menu_state)
  else
    self:initializeFromMenuState(self.my_player_number, msg.a_menu_state)
    self:initializeFromMenuState(self.op_player_number, msg.b_menu_state)
  end
  self:refreshBasedOnOwnMods(self.players[self.my_player_number])
  self:refreshBasedOnOwnMods(self.players[self.op_player_number])
end

function CharacterSelectOnline:customLoad(sceneParams)
  drop_old_data_messages() -- Starting a new game, clear all old data messages from the previous game
  self.state = states.INITIALIZE_ROOM
end

function CharacterSelectOnline:initializeRoom()
  self:pollInitializationMessage()
  if not self.roomInitializationMessage then
    return
  end
  
  local msg = self.roomInitializationMessage
  if msg.ratings then
    self.currentRoomRatings = msg.ratings
  end
  
  if msg.win_counts then
    GAME.battleRoom:updateWinCounts(msg.win_counts)
  end
  
  if msg.replay_of_match_so_far then
    replay_of_match_so_far = msg.replay_of_match_so_far
  end
  
  if msg.ranked then
    match_type = "Ranked"
    match_type_message = ""
  else
    match_type = "Casual"
  end
  self:updatePlayerNumbersFromMessage(self.roomInitializationMessage)
  self:updatePlayerStatesFromMessage(self.roomInitializationMessage)
  self:updateExpectedWinRatios()
  self.state = states.DEFAULT
end

function CharacterSelectOnline:customUpdate()
  if self.state == states.INITIALIZE_ROOM then
    self:initializeRoom()
    -- If we never got the room setup message in time, bail
    if love.timer.getTime() - self.startTime >= 6 then
      -- abort due to timeout
      logger.warn(loc("ss_init_fail") .. "\n")
      self.state = states.SWITCH_SCENE
      self.stateParams = {
        startTime = love.timer.getTime(),
        maxDisplayTime = 5,  
        minDisplayTime = 1,
        sceneName = "MainMenu",
        switchSceneLabel = Label({text = loc("ss_init_fail") .. "\n\n" .. loc("ss_return"), translate = false})
      }
    end
  elseif self.state == states.SWITCH_SCENE then
    local stateDuration = love.timer.getTime() - self.stateParams.startTime
    if not self.transitioning and
       stateDuration >= self.stateParams.maxDisplayTime or 
       (stateDuration <= self.stateParams.minDisplayTime and (input.isDown["MenuEsc"] or input.isDown["MenuPause"])) then
      sceneManager:switchToScene(self.stateParams.sceneName, self.stateParams.sceneParams)
      self.transitioning = true
    end
    self.stateParams.switchSceneLabel:draw()
    return true
  elseif self.state == states.DEFAULT then
    self:handleServerMessages()
    
    self:refreshLoadingState(self.op_player_number)
    
    -- Fetch the next network messages for 2p vs. When we get a start message we will transition there.
    if not do_messages() then
      self.state = states.SWITCH_SCENE
      self.stateParams = {
        startTime = love.timer.getTime(),
        maxDisplayTime = 5,  
        minDisplayTime = 1,
        sceneName = "MainMenu",
        switchSceneLabel = Label({text = loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), translate = false})
      }
    end
  end
end

return CharacterSelectOnline