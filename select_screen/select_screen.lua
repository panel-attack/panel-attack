local logger = require("logger")
local Replay = require("replay")
local tableUtils = require("tableUtils")
local graphics = require("select_screen.select_screen_graphics")
require("SimulatedOpponent")

local select_screen = {}

local wait = coroutine.yield

-- fills the provided map based on the provided template and return the amount of pages. __Empty values will be replaced by character_ids
local function fill_map(template_map, map)
  local X, Y = 5, 9
  local pages_amount = 0
  local character_id_index = 1
  while true do
    -- new page handling
    pages_amount = pages_amount + 1
    map[pages_amount] = deepcpy(template_map)

    -- go through the page and replace __Empty with characters_ids_for_current_theme
    for i = 1, X do
      for j = 1, Y do
        if map[pages_amount][i][j] == "__Empty" then
          map[pages_amount][i][j] = characters_ids_for_current_theme[character_id_index]
          character_id_index = character_id_index + 1
          -- end case: no more characters_ids_for_current_theme to add
          if character_id_index == #characters_ids_for_current_theme + 1 then
            logger.trace("filled " .. #characters_ids_for_current_theme .. " characters across " .. pages_amount .. " page(s)")
            return pages_amount
          end
        end
      end
    end
  end
end

-- sets player.panels_dir / player.character / player.stage based on the respective selection values player.panels_dir, player.selectedCharacter and player.selectedStage
-- Automatically goes to a fallback or random mod if the selected one is not found
function refreshBasedOnOwnMods(player)
  -- Resolve the current character if it is random
  local function resolveRandomCharacter()
      if characters[player.character] == nil and player.selectedCharacter == random_character_special_value then
        player.character = tableUtils.getRandomElement(characters_ids_for_current_theme)
      end

      if characters[player.character]:is_bundle() then
        player.character = tableUtils.getRandomElement(characters[player.character].sub_characters)
      end
  end

  -- Resolve the current stage if it is random
  local function resolveRandomStage()
    if player.selectedStage == random_stage_special_value and stages[player.stage] == nil then
      player.stage = tableUtils.getRandomElement(stages_ids_for_current_theme)
    end

    if stages[player.stage]:is_bundle() then
      player.stage = tableUtils.getRandomElement(stages[player.stage].sub_stages)
    end
  end

  if player ~= nil then
    -- panels
    if player.panels_dir == nil or panels[player.panels_dir] == nil then
      player.panels_dir = config.panels
    end

    -- stage
    if player.selectedStage or player.stage then
      if player.selectedStage == nil and player.stage ~= nil then
        -- converting to the expected format:
        -- selectedStage is tentative and unconfirmed, needs to be rechecked against available stages
        -- stage is confirmed and is definitely available
        player.selectedStage = player.stage
        player.stage = nil
      end
      if stages[player.selectedStage] then
        -- selected stage exists and shall be used
        if player.stage ~= player.selectedStage then
          player.stage = player.selectedStage
        end
      else
        if player.selectedStage ~= random_stage_special_value then
          -- don't have the selected stage and it's not random, use a random stage
            player.selectedStage = random_stage_special_value
            player.stage = nil
        end
      end

      resolveRandomStage()
      player.stage_display_name = stages[player.stage].stage_display_name
      StageLoader.load(player.stage)
    end

    -- character
    if player.selectedCharacter or player.character then
      if player.selectedCharacter == nil and player.character ~= nil then
        -- converting to the expected format:
        -- selectedCharacter is tentative and unconfirmed, needs to be rechecked against available characters
        -- character is confirmed and is definitely available
        player.selectedCharacter = player.character
        player.character = nil
      end
      if characters[player.selectedCharacter] then
        if player.character ~= player.selectedCharacter then
          player.character = player.selectedCharacter
        end
      else
        -- when there is no stage or the stage the other player selected, check if there's a character with the same name
        if player.character_display_name and characters_ids_by_display_names[player.character_display_name] and not characters[characters_ids_by_display_names[player.character_display_name][1]]:is_bundle() then
          player.character = characters_ids_by_display_names[player.character_display_name][1]
        elseif player.selectedCharacter ~= random_character_special_value then
          -- don't have the selected character and it's not random, use a random character
          player.selectedCharacter = random_character_special_value
          player.character = nil
        end
      end

      resolveRandomCharacter()
      player.character_display_name = characters[player.character].character_display_name
      CharacterLoader.load(player.character)
    end
  end
end

-- Each player sends "wants_ready" when they have selected the ready button.
-- Each player is "loaded" when the character and stage are fully loaded
-- The player isn't actually ready to start though until both players have selected "wants_ready" and are loaded.
-- After that happens each player sends "ready"
-- When the server gets the "ready" it tells both players to start the game.
-- Its important to not send "ready" before both players want ready and are loaded so the server doesn't tell you 
-- to start before everything is for sure not going to change and everything is loaded.
function select_screen.refreshReadyStates(self)
  for playerNumber = 1, #self.players do
    self.players[playerNumber].ready = tableUtils.trueForAll(self.players, function(pc) return pc.loaded and pc.wants_ready end)
  end
end

-- Leaves the 2p vs match room
function select_screen.sendLeave()
  return json_send({leave_room = true})
end

-- Function to tell the select screen to exit
function select_screen.on_quit(self)
  if themes[config.theme].musics.select_screen then
    stop_the_music()
  end
  if select_screen:isNetPlay() then
    GAME:clearMatch()
    if not select_screen.sendLeave() then
      return {main_dumb_transition, {main_select_mode, loc("ss_error_leave"), 60, 300}}
    else
      -- don't immediately transition out, wait for the server to confirm our leave via handleServerMessages and quit from there
    end
  else
    return {main_select_mode}
  end
end

-- Moves the given cursor in the given direction
function select_screen.move_cursor(self, cursor, direction)
  local cursor_pos = cursor.position
  local dx, dy = unpack(direction)
  local can_x, can_y = wrap(1, cursor_pos[1] + dx, self.ROWS), wrap(1, cursor_pos[2] + dy, self.COLUMNS)
  while can_x ~= cursor_pos[1] or can_y ~= cursor_pos[2] do
    if self.drawMap[self.current_page][can_x][can_y] and (self.drawMap[self.current_page][can_x][can_y] ~= self.drawMap[self.current_page][cursor_pos[1]][cursor_pos[2]] or self.drawMap[self.current_page][can_x][can_y] == "__Empty" or self.drawMap[self.current_page][can_x][can_y] == "__Reserved") then
      break
    end
    can_x, can_y = wrap(1, can_x + dx, self.ROWS), wrap(1, can_y + dy, self.COLUMNS)
  end
  cursor_pos[1], cursor_pos[2] = can_x, can_y
  local character = characters[self.drawMap[self.current_page][can_x][can_y]]
  cursor.can_super_select = character and (character.stage or character.panels)
end

-- Function to know what to do when you press select on your current cursor
-- returns true if the player desires to quit the room, nil otherwise
function select_screen.on_select(self, player, super)
  local characterSelectionSoundHasBeenPlayed = false
  local selectable = {__Stage = true, __Panels = true, __Level = true, __Ready = true}
  if selectable[player.cursor.positionId] then
    if player.cursor.selected and player.cursor.positionId == "__Stage" then
      -- load stage even if hidden!
      StageLoader.load(player.stage)
    end
    -- Don't let the player stop ready if both players have already told the server to start the game
    if player.cursor.positionId ~= "__Ready" or player.ready == false then 
      player.cursor.selected = not player.cursor.selected
    end
  elseif player.cursor.positionId == "__Leave" then
    return true
  elseif player.cursor.positionId == "__Random" then
    player.selectedCharacter = random_character_special_value
    player.character = CharacterLoader.resolveCharacterSelection(player.selectedCharacter)
    CharacterLoader.load(player.character)
    player.cursor.positionId = "__Ready"
    player.cursor.position = shallowcpy(self.name_to_xy_per_page[self.current_page]["__Ready"])
    player.cursor.can_super_select = false
  elseif player.cursor.positionId == "__Mode" then
    player.ranked = not player.ranked
  elseif (player.cursor.positionId ~= "__Empty" and player.cursor.positionId ~= "__Reserved") then
    player.selectedCharacter = player.cursor.positionId
    local character = characters[player.selectedCharacter]
    if character then
      player.character = CharacterLoader.resolveCharacterSelection(character.id)
      CharacterLoader.load(player.character)
      characterSelectionSoundHasBeenPlayed = character:play_selection_sfx()
      if super then
        if character.stage then
          player.selectedStage = character.stage
          player.stage = StageLoader.resolveStageSelection(player.selectedStage)
          StageLoader.load(player.stage)
        end
        if character.panels and panels[character.panels] then
          player.panels_dir = character.panels
        end
      end
    end
    
    --When we select a character, move cursor to "__Ready"
    player.cursor.positionId = "__Ready"
    player.cursor.position = shallowcpy(self.name_to_xy_per_page[self.current_page]["__Ready"])
    player.cursor.can_super_select = false
  end

  if not characterSelectionSoundHasBeenPlayed then
    -- play menu sfx
    play_optional_sfx(themes[config.theme].sounds.menu_validate)
  end
end

function select_screen.isNetPlay(self)
  return select_screen.character_select_mode == "2p_net_vs"
end

function select_screen.isMultiplayer(self)
  return select_screen.character_select_mode == "2p_net_vs"
  or select_screen.character_select_mode == "2p_local_vs"
  or select_screen.character_select_mode == "2p_local_computer_vs"
  -- vs cpu is not really multiplayer but it has 2 stacks so we need to set both "players" up
end

-- Marks when the player's stage and character are loaded
function select_screen.refreshLoadingState(self, playerNumber)
  self.players[playerNumber].loaded = characters[self.players[playerNumber].character] and characters[self.players[playerNumber].character].fully_loaded and stages[self.players[playerNumber].stage] and stages[self.players[playerNumber].stage].fully_loaded
end

-- Returns the panel dir for the given increment
function select_screen.change_panels_dir(panels_dir, increment)
  local current = 0
  for k, v in ipairs(panels_ids) do
    if v == panels_dir then
      current = k
      break
    end
  end
  local dir_count = #panels_ids
  local new_theme_idx = ((current - 1 + increment) % dir_count) + 1
  for k, v in ipairs(panels_ids) do
    if k == new_theme_idx then
      return v
    end
  end
  return panels_dir
end

-- Sets the state object to a new stage based on the increment
function select_screen.change_stage(player, increment)
  -- random_stage_special_value is placed at the end of the list and is 'replaced' by a random pick and selectedStage=true
  local stages = shallowcpy(stages_ids_for_current_theme)
  stages[#stages + 1] = random_stage_special_value
  local currentId = tableUtils.indexOf(stages, player.selectedStage)
  currentId = wrap(1, currentId + increment, #stages)
  player.selectedStage = stages[currentId]
  player.stage = StageLoader.resolveStageSelection(player.selectedStage)
  StageLoader.load(player.stage)
  logger.trace("stage and selectedStage: " .. player.stage .. " / " .. (player.selectedStage or "nil"))
end

-- returns the navigable grid layout of the select screen before loading characters
function select_screen.getTemplateMap(self)
  if self:isNetPlay() then
    return {
      {"__Panels", "__Panels", "__Mode", "__Mode", "__Stage", "__Stage", "__Level", "__Level", "__Ready"},
      {"__Random", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
      {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
      {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
      {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Leave"}
    }
  else
    local challengeMode = GAME.battleRoom.trainingModeSettings and GAME.battleRoom.trainingModeSettings.challengeMode
    if challengeMode then
      return {
        {"__Panels", "__Panels", "__Stage", "__Stage", "__Ready", "__Ready", "__Ready", "__Ready", "__Ready"},
        {"__Random", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
        {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
        {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
        {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Leave"}
      }
    else
      return {
        {"__Panels", "__Panels", "__Stage", "__Stage", "__Stage", "__Level", "__Level", "__Level", "__Ready"},
        {"__Random", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
        {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
        {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
        {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Leave"}
      }
    end
  end
end

-- sets self.roomInitializationMessage
-- if a roomInitializationMessage is not received it returns a function to transition out of the room, otherwise returns nil
function select_screen.awaitRoomInitializationMessage(self)
  -- Wait till we have the room setup messages from the server
  local retries, retry_limit = 0, 250
  local msg
  while not self.roomInitializationMessage and retries < retry_limit do
    msg = server_queue:pop_next_with("create_room", "character_select", "spectate_request_granted")
    if msg then
      self.roomInitializationMessage = msg
    end
    gprint(loc("ss_init"), unpack(themes[config.theme].main_menu_screen_pos))
    wait()
    if not do_messages() then
      return {main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}}
    end
    retries = retries + 1
  end

  -- If we never got the room setup message, bail
  if not self.roomInitializationMessage then
    -- abort due to timeout
    logger.warn(loc("ss_init_fail") .. "\n")
    return {main_dumb_transition, {main_select_mode, loc("ss_init_fail") .. "\n\n" .. loc("ss_return"), 60, 300}}
  end

  return nil
end

-- initializes information based on the content of the roomInitializationMessage
function select_screen.initializeNetPlayRoom(self)
  self:updatePlayerRatingsFromMessage(self.roomInitializationMessage)
  self:updatePlayerNumbersFromMessage(self.roomInitializationMessage)
  self:updatePlayerStatesFromMessage(self.roomInitializationMessage)
  self:updateWinCountsFromMessage(self.roomInitializationMessage)
  self:updateReplayInfoFromMessage(self.roomInitializationMessage)
  self:updateMatchTypeFromMessage(self.roomInitializationMessage)
  self:updateExpectedWinRatios()
end

function select_screen.updatePlayerRatingsFromMessage(self, msg)
  if msg.ratings then
    self.currentRoomRatings = msg.ratings
  end
end

function select_screen.updatePlayerNumbersFromMessage(self, msg)
  -- player_settings exists for spectate_request_granted but not for create_room or character_select
  -- on second runthrough we should still have data from the old select_screen, including player_numbers
  if msg.player_settings and msg.player_settings.player_number then
    self.my_player_number = msg.player_settings.player_number
  elseif msg.your_player_number then
    self.my_player_number = msg.your_player_number
  elseif self.my_player_number and self.my_player_number ~= 0 then
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
  elseif self.op_player_number and self.op_player_number ~= 0 then
    -- typical case while spectating, player_number is not sent again on consecutive game starts after the first
    logger.debug("We assumed op player number is still " .. self.op_player_number)
  else
    logger.error(loc("nt_player_err"))
    error(loc("nt_player_err"))
  end
end

function select_screen.updatePlayerStatesFromMessage(self, msg)
  if self.my_player_number == 2 and msg.a_menu_state ~= nil
    and msg.b_menu_state ~= nil then
    self:initializeFromMenuState(self.my_player_number, msg.b_menu_state)
    self:initializeFromMenuState(self.op_player_number, msg.a_menu_state)
  else
    self:initializeFromMenuState(self.my_player_number, msg.a_menu_state)
    self:initializeFromMenuState(self.op_player_number, msg.b_menu_state)
  end

  refreshBasedOnOwnMods(self.players[self.my_player_number])
  refreshBasedOnOwnMods(self.players[self.op_player_number])
end

function select_screen.updateReplayInfoFromMessage(self, msg)
  if msg.replay_of_match_so_far then
    replay_of_match_so_far = msg.replay_of_match_so_far
  end
end

function select_screen.updateMatchTypeFromMessage(self, msg)
  if msg.ranked then
    match_type = "Ranked"
    match_type_message = ""
  else
    match_type = "Casual"
  end
end

function select_screen:inPlacementMatches()
  return match_type == "Ranked" and self.currentRoomRatings and
         (self.currentRoomRatings[self.my_player_number].placement_match_progress or 
          self.currentRoomRatings[self.op_player_number].placement_match_progress)
end

function select_screen.updateExpectedWinRatios(self)
  self.currentRoomRatings = self.currentRoomRatings or {{new = 0, old = 0, difference = 0}, {new = 0, old = 0, difference = 0}}
  self.my_expected_win_ratio = nil
  self.op_expected_win_ratio = nil
  logger.trace("my_player_number = " .. self.my_player_number)
  logger.trace("op_player_number = " .. self.op_player_number)
  if self.currentRoomRatings[self.my_player_number].new and self.currentRoomRatings[self.my_player_number].new ~= 0 and self.currentRoomRatings[self.op_player_number] and self.currentRoomRatings[self.op_player_number].new ~= 0 then
    self.my_expected_win_ratio = (100 * round(1 / (1 + 10 ^ ((self.currentRoomRatings[self.op_player_number].new - self.currentRoomRatings[self.my_player_number].new) / RATING_SPREAD_MODIFIER)), 2))
    self.op_expected_win_ratio = (100 * round(1 / (1 + 10 ^ ((self.currentRoomRatings[self.my_player_number].new - self.currentRoomRatings[self.op_player_number].new) / RATING_SPREAD_MODIFIER)), 2))
  end
end

function select_screen.playThemeMusic(self)
  if themes[config.theme].musics.select_screen then
    stop_the_music()
    find_and_add_music(themes[config.theme].musics, "select_screen")
  elseif themes[config.theme].musics.main then
    find_and_add_music(themes[config.theme].musics, "main")
  end
end

function select_screen.loadThemeAssets(self)
  self:playThemeMusic()
  GAME.backgroundImage = themes[config.theme].images.bg_select_screen
  reset_filters()
end

function select_screen.setupForNetPlay(self)
  GAME:clearMatch()
  drop_old_data_messages() -- Starting a new game, clear all old data messages from the previous game

  if not self.roomInitializationMessage then
    return self:awaitRoomInitializationMessage()
  end
end

function select_screen.prepareDrawMap(self)
  local template_map = self:getTemplateMap()
  self.ROWS = #template_map
  self.COLUMNS = #template_map[1]
  self.drawMap = {}
  self.pages_amount = fill_map(template_map, self.drawMap)
  if self.current_page or 0 > self.pages_amount then
    self.current_page = 1
  end
end

function select_screen.setInitialCursors(self)
  for playerNumber = 1, #self.players do
    self:setInitialCursor(playerNumber)
  end
end

function select_screen.setInitialCursor(self, playerNumber)
  local cursor = {}

  cursor.position = shallowcpy(self.name_to_xy_per_page[self.current_page]["__Ready"])
  cursor.positionId = "__Ready"
  cursor.can_super_select = false
  cursor.selected = false

  self.players[playerNumber].cursor = cursor

end

function select_screen.drawMapToPageIdMapTransform(self)
  -- be wary: name_to_xy_per_page is kinda buggy for larger blocks as they span multiple positions (we retain the last one), and is completely broken with __Empty
  self.name_to_xy_per_page = {}
  for page = 1, self.pages_amount do
    self.name_to_xy_per_page[page] = {}
    for row = 1, self.ROWS do
      for column = 1, self.COLUMNS do
        if self.drawMap[page][row][column] then
          self.name_to_xy_per_page[page][self.drawMap[page][row][column]] = {row, column}
        end
      end
    end
  end
end

function select_screen.initializeFromPlayerConfig(self, playerNumber)
  self.players[playerNumber].stage = config.stage
  self.players[playerNumber].selectedStage = config.stage
  self.players[playerNumber].selectedCharacter = config.character
  self.players[playerNumber].character = config.character
  self.players[playerNumber].level = config.level
  self.players[playerNumber].inputMethod = config.inputMethod or "controller"
  self.players[playerNumber].panels_dir = config.panels
  self.players[playerNumber].ready = false
  self.players[playerNumber].ranked = config.ranked
end

function select_screen.initializeFromMenuState(self, playerNumber, menuState)
  self.players[playerNumber].ranked = menuState.ranked
  self.players[playerNumber].stage = menuState.stage
  self.players[playerNumber].selectedStage = menuState.stage_is_random
  self.players[playerNumber].character = characters[menuState.character] and menuState.character or nil
  self.players[playerNumber].selectedCharacter = menuState.character_is_random and menuState.character_is_random or menuState.character
  self.players[playerNumber].level = menuState.level
  self.players[playerNumber].inputMethod = menuState.inputMethod
  self.players[playerNumber].panels_dir = menuState.panels_dir
  self.players[playerNumber].ready = false
  self.players[playerNumber].wants_ready = menuState.wants_ready or false
  self.players[playerNumber].ranked = menuState.ranked
  self.players[playerNumber].cursor.positionId = menuState.cursor
  self.players[playerNumber].cursor.position = shallowcpy(self.name_to_xy_per_page[self.current_page][menuState.cursor])
end

function select_screen.setUpMyPlayer(self)
  -- set up the local player
  if not self:isNetPlay() then
    self.my_player_number = 1
  end

  if not GAME.battleRoom.spectating then
    self:initializeFromPlayerConfig(self.my_player_number)
  end

  refreshBasedOnOwnMods(self.players[self.my_player_number])
  self:refreshLoadingState(self.my_player_number)
end

function select_screen.setUpOpponentPlayer(self)
  if self:isNetPlay() then
    -- player was already initialized through the roomInitializationMessage, don't overwrite stuff!
  else
    self.op_player_number = 2

    self:initializeFromPlayerConfig(self.op_player_number)

    if global_op_state then
      self.players[self.op_player_number].selectedCharacter = global_op_state.character
      self.players[self.op_player_number].character = global_op_state.character
      self.players[self.op_player_number].stage = global_op_state.stage
      self.players[self.op_player_number].level = global_op_state.level
      self.players[self.op_player_number].panels_dir = global_op_state.panels_dir
    end
  end

  refreshBasedOnOwnMods(self.players[self.op_player_number])
  self:refreshLoadingState(self.op_player_number)
end

function select_screen.updateMyConfig(self)
  -- update config, does not redefine it
  local myPlayer = self.players[self.my_player_number]
  config.character = myPlayer.selectedCharacter
  config.stage = myPlayer.selectedStage
  config.level = myPlayer.level
  config.inputMethod = myPlayer.inputMethod
  config.ranked = myPlayer.ranked
  config.panels = myPlayer.panels_dir
end

function select_screen.sendMenuState(self)
  local menuState = {}
  menuState.character = self.players[self.my_player_number].character
  menuState.character_is_random = (self.players[self.my_player_number].selectedCharacter ~= self.players[self.my_player_number].character) and self.players[self.my_player_number].selectedCharacter or nil
  menuState.character_display_name = self.players[self.my_player_number].character_display_name
  menuState.loaded = self.players[self.my_player_number].loaded
  menuState.cursor = self.players[self.my_player_number].cursor.positionId
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

function select_screen.handleInput(self)
  local up, down, left, right = {-1, 0}, {1, 0}, {0, -1}, {0, 1}
  if not GAME.battleRoom.spectating then
    local local_players
    if select_screen.character_select_mode == "2p_local_vs" then
      local_players = { self.my_player_number, self.op_player_number}
    else
      local_players = { self.my_player_number }
    end
    for i = 1, #local_players do
      local player = self.players[local_players[i]]
      local cursor = player.cursor
      if menu_prev_page(i) then
        if not cursor.selected then
          self.current_page = bound(1, self.current_page - 1, self.pages_amount)
        end
      elseif menu_next_page(i) then
        if not cursor.selected then
          self.current_page = bound(1, self.current_page + 1, self.pages_amount)
        end
      elseif menu_up(i) then
        if not cursor.selected then
          self:move_cursor(cursor, up)
        end
      elseif menu_down(i) then
        if not cursor.selected then
          self:move_cursor(cursor, down)
        end
      elseif menu_left(i) then
        if cursor.selected then
          if cursor.positionId == "__Level" then
            player.level = bound(1, player.level - 1, #level_to_starting_speed) --which should equal the number of levels in the game
          elseif cursor.positionId == "__Panels" then
            player.panels_dir = self.change_panels_dir(player.panels_dir, -1)
          elseif cursor.positionId == "__Stage" then
            self.change_stage(player, -1)
          end
        end
        if not cursor.selected then
          self:move_cursor(cursor, left)
        end
      elseif menu_right(i) then
        if cursor.selected then
          if cursor.positionId == "__Level" then
            player.level = bound(1, player.level + 1, #level_to_starting_speed) --which should equal the number of levels in the game
          elseif cursor.positionId == "__Panels" then
            player.panels_dir = self.change_panels_dir(player.panels_dir, 1)
          elseif cursor.positionId == "__Stage" then
            self.change_stage(player, 1)
          end
        end
        if not cursor.selected then
          self:move_cursor(cursor, right)
        end
      -- mute sound to not play the menu sound in parallel to a character selection sfx
      -- this is the enter that was held for long enough to super select
      elseif menu_long_enter(i, true) then
        if self:on_select(player, true) then
          return self:on_quit()
        end
        -- mute sound to not play the menu sound in parallel to a character selection sfx
      elseif menu_enter(i, true) then
        -- don't process the enter yet if enter is still being held and super select is possible
        if (not cursor.can_super_select or select_being_pressed_ratio(i) < super_selection_enable_ratio) then
          if self:on_select(player, false) then
            return self:on_quit()
          end
        end
      elseif menu_escape(i) then
        if cursor.positionId == "__Leave" then
          return self:on_quit()
        end
        cursor.selected = false
        cursor.position = shallowcpy(self.name_to_xy_per_page[self.current_page]["__Leave"])
        cursor.positionId = "__Leave"
        cursor.can_super_select = false
      end

      player.cursor.positionId = self.drawMap[self.current_page][cursor.position[1]][cursor.position[2]]
      player.wants_ready = player.cursor.selected and player.cursor.positionId == "__Ready"
    end

    if select_screen.character_select_mode == "2p_local_vs" then
      self:savePlayer2Config()
    end

    if not deep_content_equal(self.players[self.my_player_number], self.myPreviousConfig) then
      self:updateMyConfig()
      if self:isNetPlay() and not GAME.battleRoom.spectating  then
        self:sendMenuState()
      end
      self.myPreviousConfig = deepcpy(self.players[self.my_player_number])
    end
  else -- (we are spectating)
    if menu_escape() then
      self:on_quit()
      -- we left the select screen as a spectator, there is no need to wait on the server to confirm our leave
      return {main_net_vs_lobby}
    end
  end

  return nil
end

-- this is registered for future entering of the 2p vs local lobby, only preserved per session
function select_screen.savePlayer2Config(self)
  global_op_state = shallowcpy(self.players[self.op_player_number])
  global_op_state.character = global_op_state.selectedCharacter
  global_op_state.stage = global_op_state.selectedStage
  global_op_state.wants_ready = false
end

-- may return a function for transitioning into a different screen if the opponent left or the server confirmed the start of the game
-- returns nil if staying in select_screen
function select_screen.handleServerMessages(self)
  local messages = server_queue:pop_all_with("win_counts", "menu_state", "ranked_match_approved", "leave_room", "match_start", "ranked_match_denied")
  if self.roomInitializationMessage then
    messages[#messages+1] = self.roomInitializationMessage
    self.roomInitializationMessage = nil
  end
  for _, msg in ipairs(messages) do
    if msg.win_counts then
      self:updateWinCountsFromMessage(msg)
    end

    if msg.menu_state then
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
    end
  end

  return nil
end

-- updates one player based on the given menu state
-- different from updatePlayerStatesFromMessage that it only updates one player and works from a different message type
function select_screen.updatePlayerFromMenuStateMessage(self, msg)
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
  refreshBasedOnOwnMods(self.players[player_number])
  self:refreshLoadingState(player_number)
  self:refreshReadyStates()
end

function select_screen.updateRankedStatusFromMessage(self, msg)
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

function select_screen.updateWinCountsFromMessage(self, msg)
  if msg.win_counts then
    GAME.battleRoom:updateWinCounts(msg.win_counts)
  end
end

-- Use the seed the server gives us if it makes one, else generate a basic one off data both clients have.
function select_screen.getSeed(self, msg)
  local seed
  if msg.seed or (replay_of_match_so_far and replay_of_match_so_far.vs and replay_of_match_so_far.vs.seed) then
    seed = msg.seed or (replay_of_match_so_far and replay_of_match_so_far.vs and replay_of_match_so_far.vs.seed)
  else
    seed = 17
    seed = seed * 37 + self.currentRoomRatings[1].new;
    seed = seed * 37 + self.currentRoomRatings[2].new;
    seed = seed * 37 + GAME.battleRoom.playerWinCounts[1];
    seed = seed * 37 + GAME.battleRoom.playerWinCounts[2];
  end

  return seed
end

function select_screen.startNetPlayMatch(self, msg)
  logger.debug("spectating: " .. tostring(GAME.battleRoom.spectating))
  refreshBasedOnOwnMods(msg.opponent_settings)
  refreshBasedOnOwnMods(msg.player_settings)
  current_stage = StageLoader.resolveStageSelection(msg.stage)
  StageLoader.load(current_stage)
  -- mainly for spectator mode, those characters have already been loaded otherwise
  CharacterLoader.wait()
  StageLoader.wait()
  GAME.match = Match("vs", GAME.battleRoom)

  GAME.match.seed = self:getSeed(msg)
  GAME.match.room_ratings = self.currentRoomRatings
  GAME.match.my_player_number = self.my_player_number
  GAME.match.op_player_number = self.op_player_number

  local is_local = true
  if GAME.battleRoom.spectating then
    is_local = false
  end
  P1 = Stack{which = 1, match = GAME.match, is_local = is_local, panels_dir = msg.player_settings.panels_dir, level = msg.player_settings.level, inputMethod = msg.player_settings.inputMethod or "controller", character = msg.player_settings.character, player_number = msg.player_settings.player_number}
  GAME.match:addPlayer(P1)
  P1.cur_wait_time = default_input_repeat_delay -- this enforces default cur_wait_time for online games.  It is yet to be decided if we want to allow this to be custom online.
  P2 = Stack{which = 2, match = GAME.match, is_local = false, panels_dir = msg.opponent_settings.panels_dir, level = msg.opponent_settings.level, inputMethod = msg.opponent_settings.inputMethod or "controller", character = msg.opponent_settings.character, player_number = msg.opponent_settings.player_number}
  GAME.match:addPlayer(P2)
  P2.cur_wait_time = default_input_repeat_delay -- this enforces default cur_wait_time for online games.  It is yet to be decided if we want to allow this to be custom online.
  
  P1:setOpponent(P2)
  P1:setGarbageTarget(P2)
  P2:setOpponent(P1)
  P2:setGarbageTarget(P1)
  P2:moveForPlayerNumber(2)
  replay = Replay.createNewReplay(GAME.match)

  if GAME.battleRoom.spectating and replay_of_match_so_far then --we joined a match in progress
    for k, v in pairs(replay_of_match_so_far.vs) do
      replay.vs[k] = v
    end
    P1:receiveConfirmedInput(uncompress_input_string(replay_of_match_so_far.vs.in_buf))
    P2:receiveConfirmedInput(uncompress_input_string(replay_of_match_so_far.vs.I))
    
    replay_of_match_so_far = nil
    --this makes non local stacks run until caught up
    P1.play_to_end = true
    P2.play_to_end = true
  end

  GAME.input:requestSingleInputConfigurationForPlayerCount(1)

  -- Proceed to the game screen and start the game
  P1:starting_state()
  P2:starting_state()

  local to_print = loc("pl_game_start") .. "\n" .. loc("level") .. ": " .. P1.level .. "\n" .. loc("opponent_level") .. ": " .. P2.level
  if P1.play_to_end or P2.play_to_end then
    to_print = loc("pl_spectate_join")
  end
  return {main_dumb_transition, {main_net_vs, to_print, 10, 0}}
end

-- returns transition to local vs screen
function select_screen.start2pLocalMatch(self)
  GAME.match = Match("vs", GAME.battleRoom)
  P1 = Stack{which = 1, match = GAME.match, is_local = true, panels_dir = self.players[self.my_player_number].panels_dir, level = self.players[self.my_player_number].level, inputMethod = config.inputMethod, character = self.players[self.my_player_number].character, player_number = 1}
  GAME.match:addPlayer(P1)
  P2 = Stack{which = 2, match = GAME.match, is_local = true, panels_dir = self.players[self.op_player_number].panels_dir, level = self.players[self.op_player_number].level, inputMethod = "controller", character = self.players[self.op_player_number].character, player_number = 2}
  --note: local P2 not currently allowed to use "touch" input method
  GAME.match:addPlayer(P2)
  P1:setOpponent(P2)
  P1:setGarbageTarget(P2)
  P2:setOpponent(P1)
  P2:setGarbageTarget(P1)
  current_stage = self.players[math.random(1, #self.players)].stage
  StageLoader.load(current_stage)
  StageLoader.wait()
  P2:moveForPlayerNumber(2)

  P1:starting_state()
  P2:starting_state()
  return main_dumb_transition, {main_local_vs, "", 0, 0}
end

-- returns transition to local_vs_yourself screen
function select_screen.start1pLocalMatch(self)
  local challengeMode = GAME.battleRoom.trainingModeSettings and GAME.battleRoom.trainingModeSettings.challengeMode
  local challengeStage = nil
  GAME.match = Match("vs", GAME.battleRoom)
  local stackLevel = self.players[self.my_player_number].level
  if challengeMode then
    challengeMode:beginStage()
    challengeStage = challengeMode.stages[challengeMode.currentStageIndex]
    stackLevel = challengeStage.riseDifficulty
  end
  P1 = Stack{which = 1, match = GAME.match, is_local = true, panels_dir = self.players[self.my_player_number].panels_dir, level = stackLevel, inputMethod = self.players[self.my_player_number].inputMethod, character = self.players[self.my_player_number].character, player_number = 1}

  if GAME.battleRoom.trainingModeSettings then
    local character = P1.character
    local health = nil
    local attackEngine = nil
    if challengeMode then
      health = challengeStage:createHealth()
      character = challengeStage:characterForStageNumber(P1.character)
      CharacterLoader.load(character)
      CharacterLoader.wait()
    end

    local xPosition = 796
    local yPosition = 120
    local mirror = -1
    local simulatedOpponent = SimulatedOpponent(health, character, xPosition, yPosition, mirror)
    if challengeStage then
      attackEngine = challengeStage:createAttackEngine(P1, simulatedOpponent, character, true)
    else
      attackEngine = AttackEngine.createEngineForTrainingModeSettings(GAME.battleRoom.trainingModeSettings.attackSettings, P1, simulatedOpponent, character, false)
    end
    simulatedOpponent:setAttackEngine(attackEngine)

    GAME.match.simulatedOpponent = simulatedOpponent
  end
  
  GAME.match:addPlayer(P1)
  if not GAME.match.simulatedOpponent then
    P1:setGarbageTarget(P1)
  else
    P1:setGarbageTarget(GAME.match.simulatedOpponent)
  end
  P2 = nil
  current_stage = self.players[self.my_player_number].stage
  StageLoader.load(current_stage)
  StageLoader.wait()

  GAME.input:requestSingleInputConfigurationForPlayerCount(1)

  P1:starting_state()
  return main_dumb_transition, {main_local_vs_yourself, "", 0, 0}
end

function select_screen.start1pCpuMatch(self)
  GAME.match = Match("vs", GAME.battleRoom)
  P1 = Stack{which = 1, match = GAME.match, is_local = true, panels_dir = self.players[self.my_player_number].panels_dir, level = self.players[self.my_player_number].level, character = self.players[self.my_player_number].character, player_number = 1}
  GAME.match:addPlayer(P1)
  P2 = Stack{which = 2, match = GAME.match, is_local = true, panels_dir = self.players[self.op_player_number].panels_dir, level = self.players[self.op_player_number].level, character = self.players[self.op_player_number].character, player_number = 2}
  P2.max_runs_per_frame = 1
  GAME.match:addPlayer(P2)
  GAME.match.P2CPU = ComputerPlayer("DummyCpu", "DummyConfig", P2)

  P1.garbageTarget = P2
  P2.garbageTarget = P1
  current_stage = self.players[self.my_player_number].stage
  StageLoader.load(current_stage)
  StageLoader.wait()
  P2:moveForPlayerNumber(2)

  GAME.input:requestSingleInputConfigurationForPlayerCount(1)

  P1:starting_state()
  P2:starting_state()
  return main_dumb_transition, {main_local_vs, "", 0, 0}
end

function select_screen.initialize(self, character_select_mode)
  self.character_select_mode = character_select_mode
  self.players = {}
  for i=1, tonumber(self.character_select_mode:sub(1, 1)) do
    self.players[i] = {}
  end
  -- everything else gets its field directly on select_screen
  self.current_page = 1
end

-- The main screen for selecting characters and settings for a match
function select_screen.main(self, character_select_mode, roomInitializationMessage)
  self.roomInitializationMessage = roomInitializationMessage
  self:initialize(character_select_mode)

  -- 2p vs local needs to have its input properly divided in select screen already
  -- meaning we do NOT want to reset to player 1 reacting to inputs from all configurations
  -- for all others, the player can hold their decision until game start
  if not self:isMultiplayer() or self:isNetPlay() then
    GAME.input:allowAllInputConfigurations()
  end

  self:loadThemeAssets()

  self:prepareDrawMap()
  self:drawMapToPageIdMapTransform()
  self:setInitialCursors()

  -- Setup settings for Main Character Select for 2 Player over Network
  if self:isNetPlay() then
    local abort = self:setupForNetPlay()
    if abort then
      -- abort due to connection loss or timeout
      return unpack(abort)
    else
      self:initializeNetPlayRoom()
    end
  end

  self:setUpMyPlayer()

  if self:isMultiplayer() then
    self:setUpOpponentPlayer()
  end

  self:refreshReadyStates()

  self.myPreviousConfig = deepcpy(self.players[self.my_player_number])

  self.menu_clock = 0

  -- Main loop for running the select screen and drawing
  while true do
    gfx_q:push({graphics.draw, {graphics, self}})

    if select_screen:isNetPlay() then
      local leaveRoom = self:handleServerMessages()
      if leaveRoom then
        return unpack(leaveRoom)
      end
    end

    local playerNumberWaiting = GAME.input.playerNumberWaitingForInputConfiguration()
    if playerNumberWaiting then
      gprintf(loc("player_press_key", playerNumberWaiting), 0, 30, canvas_width, "center")
    end

    wait()

    local ret = nil

    variable_step(
      function()
        self.menu_clock = self.menu_clock + 1

        CharacterLoader.update()
        StageLoader.update()
        self:refreshLoadingState(self.my_player_number)
        if self:isMultiplayer() then
          self:refreshLoadingState(self.op_player_number)
        end
        ret = self:handleInput()
        self:refreshReadyStates()
      end
    )

    if ret then
      return unpack(ret)
    end

    -- Handle one player vs game setup
    if self.players[self.my_player_number].ready and self.character_select_mode == "1p_vs_yourself" then
      return self:start1pLocalMatch()
    -- Handle two player vs game setup
    elseif select_screen.character_select_mode == "2p_local_vs" and self.players[self.my_player_number].ready and self.players[self.op_player_number].ready then
      return self:start2pLocalMatch()
    elseif select_screen.character_select_mode == "2p_local_computer_vs" and self.players[self.my_player_number].ready then
      return self:start1pCpuMatch()
    -- Fetch the next network messages for 2p vs. When we get a start message we will transition there.
    elseif select_screen:isNetPlay() then
      if not do_messages() then
        return main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}
      end
    end
  end
end

return select_screen