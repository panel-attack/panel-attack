local logger = require("logger")
local graphics = require("select_screen.select_screen_graphics")

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
        player.character = table.getRandomElement(characters_ids_for_current_theme)
      end

      if characters[player.character]:is_bundle() then
        player.character = table.getRandomElement(characters[player.character].sub_characters)
      end
  end

  -- Resolve the current stage if it is random
  local function resolveRandomStage()
    if player.selectedStage == random_stage_special_value and stages[player.stage] == nil then
      player.stage = table.getRandomElement(stages_ids_for_current_theme)
    end

    if stages[player.stage]:is_bundle() then
      player.stage = table.getRandomElement(stages[player.stage].sub_stages)
    end
  end

  if player ~= nil then
    -- panels
    if player.panels_dir == nil or panels[player.panels_dir] == nil then
      player.panels_dir = config.panels
    end

    -- stage
    if stages[player.selectedStage] then
      -- selected stage exists and shall be used
      if player.stage ~= player.selectedStage then
        player.stage = player.selectedStage
      end
    else
      if player.selectedStage ~= random_stage_special_value then
        -- don't have the selected stage and it's not random, use the fallback
          player.selectedStage = config.fallbackStage

          if player.selectedStage == random_stage_special_value then
            -- to make sure it gets randomised again
            player.stage = nil
          end
      end
    end

    resolveRandomStage()
    player.stage_display_name = stages[player.stage].stage_display_name
    stage_loader_load(player.stage)

    -- character
    if characters[player.selectedCharacter] then
      if player.character ~= player.selectedCharacter then
        player.character = player.selectedCharacter
      end
    else
      -- when there is no stage or the stage the other player selected, check if there's a character with the same name
      if player.character_display_name and characters_ids_by_display_names[player.character_display_name] and not characters[characters_ids_by_display_names[player.character_display_name][1]]:is_bundle() then
        player.character = characters_ids_by_display_names[player.character_display_name][1]
      elseif player.selectedCharacter ~= random_character_special_value then
        -- don't have the selected character and it's not random, use the fallback
        player.selectedCharacter = config.fallbackCharacter
        if player.selectedCharacter == random_character_special_value then
            -- to make sure it gets randomised again
          player.character = nil
        end
      end
    end

    resolveRandomCharacter()
    player.character_display_name = characters[player.character].character_display_name
    character_loader_load(player.character)
  end
end

-- Updates the ready state for all players
function select_screen.refreshReadyStates(self)
  for playerNumber = 1, #self.players do
    if self:isNetPlay() then
      self.players[playerNumber].ready =
          self.players[playerNumber].wants_ready and
          table.trueForAll(self.players, function(pc) return pc.loaded end)
    else
      self.players[playerNumber].ready = self.players[playerNumber].wants_ready and self.players[playerNumber].loaded
    end
  end
end

-- Leaves the 2p vs match room
function select_screen.do_leave()
  stop_the_music()
  GAME:clearMatch()
  return json_send({leave_room = true})
end

-- Function to tell the select screen to exit
function select_screen.on_quit(self)
  if themes[config.theme].musics.select_screen then
    stop_the_music()
  end
  if select_screen:isNetPlay() then
    -- Tell the server we want to leave, once it disconnects us we will actually leave
    if not select_screen.do_leave() then
      return {main_dumb_transition, {main_select_mode, loc("ss_error_leave"), 60, 300}}
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
-- returns true if a sound should be played
function select_screen.on_select(self, player, super)
  local noisy = false
  local selectable = {__Stage = true, __Panels = true, __Level = true, __Ready = true}
  if selectable[player.cursor.positionId] then
    if player.cursor.selected and player.cursor.positionId == "__Stage" then
      -- load stage even if hidden!
      stage_loader_load(player.stage)
    end
    player.cursor.selected = not player.cursor.selected
  elseif player.cursor.positionId == "__Leave" then
    return self:on_quit()
  elseif player.cursor.positionId == "__Random" then
    player.selectedCharacter = random_character_special_value
    refreshBasedOnOwnMods(player)
    player.cursor.positionId = "__Ready"
    player.cursor.position = shallowcpy(self.name_to_xy_per_page[self.current_page]["__Ready"])
    player.cursor.can_super_select = false
  elseif player.cursor.positionId == "__Mode" then
    player.ranked = not player.ranked
  elseif (player.cursor.positionId ~= "__Empty" and player.cursor.positionId ~= "__Reserved") then
    player.selectedCharacter = player.cursor.positionId
    local character = characters[player.selectedCharacter]
    if character then
      noisy = characters[player.selectedCharacter]:play_selection_sfx()
      if super then
        if character.stage then
          player.selectedStage = character.stage
        end
        if character.panels then
          player.panels_dir = character.panels
        end
      end
      refreshBasedOnOwnMods(player)
    end
    --When we select a character, move cursor to "__Ready"
    player.cursor.positionId = "__Ready"
    player.cursor.position = shallowcpy(self.name_to_xy_per_page[self.current_page]["__Ready"])
    player.cursor.can_super_select = false
  end
  return noisy
end

function select_screen.isNetPlay(self)
  return select_screen.character_select_mode == "2p_net_vs"
end

function select_screen.isMultiplayer(self)
  return select_screen.character_select_mode == "2p_net_vs" or select_screen.character_select_mode == "2p_local_vs"
end

-- Makes sure all the client data is up to date and ready
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
  local stages = stages_ids_for_current_theme
  stages[#stages + 1] = random_stage_special_value
  local currentId = table.indexOf(stages, player.selectedStage)
  currentId = wrap(1, currentId + increment, #stages)
  player.selectedStage = stages[currentId]
  refreshBasedOnOwnMods(player)
  logger.trace("stage and selectedStage: " .. player.stage .. " / " .. (player.selectedStage or "nil"))
end

-- returns the navigable grid layout of the select screen before loading characters
function select_screen.getTemplateMap(self)
  logger.trace("current_server_supports_ranking: " .. tostring(current_server_supports_ranking))
  if self:isNetPlay() and current_server_supports_ranking then
    return {
      {"__Panels", "__Panels", "__Mode", "__Mode", "__Stage", "__Stage", "__Level", "__Level", "__Ready"},
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
      return main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}
    end
    retries = retries + 1
  end

  -- If we never got the room setup message, bail
  if not self.roomInitializationMessage then
    -- abort due to timeout
    logger.warn(loc("ss_init_fail") .. "\n")
    return main_dumb_transition, {main_select_mode, loc("ss_init_fail") .. "\n\n" .. loc("ss_return"), 60, 300}
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
  self.players[playerNumber].character = config.character
  self.players[playerNumber].selectedCharacter = config.character
  self.players[playerNumber].level = config.level
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
  self.players[playerNumber].panels_dir = menuState.panels_dir
  self.players[playerNumber].ready = false
  self.players[playerNumber].wants_ready = menuState.wants_ready or false
  self.players[playerNumber].ranked = menuState.ranked
  self.players[playerNumber].cursor.positionId = menuState.cursor
  self.players[playerNumber].cursor.position = self.name_to_xy_per_page[self.current_page][menuState.cursor]
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
  config.ranked = myPlayer.ranked
  config.panels = myPlayer.panels_dir
end

function select_screen.sendMenuState(self)
  local menuState = {}
  menuState.character = self.players[self.my_player_number].character
  menuState.character_is_random = self.players[self.my_player_number].selectedCharacter
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
      else
        -- code below is bit hard to read: basically we are storing the default sfx callbacks until it's needed (or not!) based on the on_select method
        local long_enter, long_enter_callback = menu_long_enter(i, true)
        local normal_enter, normal_enter_callback = menu_enter(i, true)
        if long_enter then
          if not self:on_select(player, true) then
            long_enter_callback()
          end
        elseif normal_enter and (not cursor.can_super_select or select_being_pressed_ratio(i) < super_selection_enable_ratio) then
          if not self:on_select(player, false) then
            normal_enter_callback()
          end
        elseif menu_escape() then
          if cursor.positionId == "__Leave" then
            return self:on_quit()
          end
          cursor.selected = false
          cursor.position = shallowcpy(self.name_to_xy_per_page[self.current_page]["__Leave"])
          cursor.positionId = "__Leave"
          cursor.can_super_select = false
        end
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
      self.do_leave()
      return {main_net_vs_lobby} -- we left the select screen as a spectator
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
      return {main_dumb_transition, {main_net_vs_lobby, "", 0, 0}} -- opponent left the select screen
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
  refreshBasedOnOwnMods(msg) -- for stage only, other data are meaningless to us
  -- mainly for spectator mode, those characters have already been loaded otherwise
  current_stage = msg.stage
  character_loader_wait()
  stage_loader_wait()
  GAME.match = Match("vs", GAME.battleRoom)

  GAME.match.seed = self:getSeed(msg)
  if match_type == "Ranked" then
    GAME.match.room_ratings = self.currentRoomRatings
    GAME.match.my_player_number = self.my_player_number
    GAME.match.op_player_number = self.op_player_number
  end

  local is_local = true
  if GAME.battleRoom.spectating then
    is_local = false
  end
  P1 = Stack{which = 1, match = GAME.match, is_local = is_local, panels_dir = msg.player_settings.panels_dir, level = msg.player_settings.level, character = msg.player_settings.character, player_number = msg.player_settings.player_number}
  GAME.match.P1 = P1
  P1.cur_wait_time = default_input_repeat_delay -- this enforces default cur_wait_time for online games.  It is yet to be decided if we want to allow this to be custom online.
  P2 = Stack{which = 2, match = GAME.match, is_local = false, panels_dir = msg.opponent_settings.panels_dir, level = msg.opponent_settings.level, character = msg.opponent_settings.character, player_number = msg.opponent_settings.player_number}
  GAME.match.P2 = P2
  P2.cur_wait_time = default_input_repeat_delay -- this enforces default cur_wait_time for online games.  It is yet to be decided if we want to allow this to be custom online.
  
  P1:set_garbage_target(P2)
  P2:set_garbage_target(P1)
  P2:moveForPlayerNumber(2)
  replay = createNewReplay(GAME.match)

  if GAME.battleRoom.spectating and replay_of_match_so_far then --we joined a match in progress
    for k, v in pairs(replay_of_match_so_far.vs) do
      replay.vs[k] = v
    end
    P1:receiveConfirmedInput(replay_of_match_so_far.vs.in_buf)
    P2:receiveConfirmedInput(replay_of_match_so_far.vs.I)
    
    replay_of_match_so_far = nil
    --this makes non local stacks run until caught up
    P1.play_to_end = true
    P2.play_to_end = true
  end

  -- Proceed to the game screen and start the game
  P1:starting_state()
  P2:starting_state()

  local to_print = loc("pl_game_start") .. "\n" .. loc("level") .. ": " .. P1.level .. "\n" .. loc("opponent_level") .. ": " .. P2.level
  if P1.play_to_end or P2.play_to_end then
    to_print = loc("pl_spectate_join")
  end
  return {main_dumb_transition, {main_net_vs, to_print, 60, 0}}
end

-- returns transition to local vs screen
function select_screen.start2pLocalMatch(self)
  GAME.match = Match("vs", GAME.battleRoom)
  P1 = Stack{which = 1, match = GAME.match, is_local = true, panels_dir = self.players[self.my_player_number].panels_dir, level = self.players[self.my_player_number].level, character = self.players[self.my_player_number].character, player_number = 1}
  GAME.match.P1 = P1
  P2 = Stack{which = 2, match = GAME.match, is_local = true, panels_dir = self.players[self.op_player_number].panels_dir, level = self.players[self.op_player_number].level, character = self.players[self.op_player_number].character, player_number = 2}
  GAME.match.P2 = P2
  P1:set_garbage_target(P2)
  P2:set_garbage_target(P1)
  current_stage = self.players[math.random(1, #self.players)].stage
  stage_loader_load(current_stage)
  stage_loader_wait()
  P2:moveForPlayerNumber(2)

  P1:starting_state()
  P2:starting_state()
  return main_dumb_transition, {main_local_vs, "", 0, 0}
end

-- returns transition to local_vs_yourself screen
function select_screen.start1pLocalMatch(self)
  GAME.match = Match("vs", GAME.battleRoom)
  P1 = Stack{which = 1, match = GAME.match, is_local = true, panels_dir = self.players[self.my_player_number].panels_dir, level = self.players[self.my_player_number].level, character = self.players[self.my_player_number].character, player_number = 1}
  if GAME.battleRoom.trainingModeSettings then
    self:initializeAttackEngine()
  end
  GAME.match.P1 = P1
  if not GAME.battleRoom.trainingModeSettings then
    P1:set_garbage_target(P1)
  end
  P2 = nil
  current_stage = self.players[self.my_player_number].stage
  stage_loader_load(current_stage)
  stage_loader_wait()
  P1:starting_state()
  return main_dumb_transition, {main_local_vs_yourself, "", 0, 0}
end

function select_screen.initializeAttackEngine(self)
  local trainingModeSettings = GAME.battleRoom.trainingModeSettings
  local delayBeforeStart = trainingModeSettings.delayBeforeStart or 0
  local delayBeforeRepeat = trainingModeSettings.delayBeforeRepeat or 0
  local disableQueueLimit = trainingModeSettings.disableQueueLimit or false
  GAME.match.attackEngine = AttackEngine(P1, delayBeforeStart, delayBeforeRepeat, disableQueueLimit)
  for _, values in ipairs(trainingModeSettings.attackPatterns) do
    if values.chain then
      if type(values.chain) == "number" then
        for i = 1, values.height do
          GAME.match.attackEngine:addAttackPattern(6, i, values.startTime + ((i-1) * values.chain), false, true)
        end
        GAME.match.attackEngine:addEndChainPattern(values.startTime + ((values.height - 1) * values.chain) + values.chainEndDelta)
      elseif type(values.chain) == "table" then
        for i, chainTime in ipairs(values.chain) do
          GAME.match.attackEngine:addAttackPattern(6, i, chainTime, false, true)
        end
        GAME.match.attackEngine:addEndChainPattern(values.chainEndTime)
      else
        error("The 'chain' field in your attack file is invalid. It should either be a number or a list of numbers.")
      end
    else
      GAME.match.attackEngine:addAttackPattern(values.width, values.height or 1, values.startTime, values.metal or false, false)
    end
  end
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
  self:loadThemeAssets()

  self:prepareDrawMap()
  self:drawMapToPageIdMapTransform()
  self:setInitialCursors()

  -- Setup settings for Main Character Select for 2 Player over Network
  if select_screen:isNetPlay() then
    local abort = self:setupForNetPlay()
    if abort then
      -- abort due to connection loss or timeout
      return abort
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
    graphics:draw(self)

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

        character_loader_update()
        stage_loader_update()
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
    -- Fetch the next network messages for 2p vs. When we get a start message we will transition there.
    elseif select_screen:isNetPlay() then
      if not do_messages() then
        return main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}
      end
    end
  end
end

return select_screen