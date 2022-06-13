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

-- Grabs character / panel / stage settings based on our own mods if they are not set
function refresh_based_on_own_mods(refreshed, ask_change_fallback)
  patch_is_random(refreshed)
  ask_change_fallback = ask_change_fallback or false
  if refreshed ~= nil then
    -- panels
    if refreshed.panels_dir == nil or panels[refreshed.panels_dir] == nil then
      refreshed.panels_dir = config.panels
    end

    -- stage
    if refreshed.stage == nil or (refreshed.stage ~= random_stage_special_value and stages[refreshed.stage] == nil) then
      if not select_screen.fallback_when_missing[1] or ask_change_fallback then
        select_screen.fallback_when_missing[1] = table.getRandomElement(stages_ids_for_current_theme)
        if stages[select_screen.fallback_when_missing[1]]:is_bundle() then -- may pick a bundle!
          select_screen.fallback_when_missing[1] = table.getRandomElement(stages[select_screen.fallback_when_missing[1]].sub_stages)
        end
      end
      refreshed.stage = select_screen.fallback_when_missing[1]
    end

    -- character
    if refreshed.character == nil or (refreshed.character ~= random_character_special_value and characters[refreshed.character] == nil) then
      if refreshed.character_display_name and characters_ids_by_display_names[refreshed.character_display_name] and not characters[characters_ids_by_display_names[refreshed.character_display_name][1]]:is_bundle() then
        refreshed.character = characters_ids_by_display_names[refreshed.character_display_name][1]
      else
        if not select_screen.fallback_when_missing[2] or ask_change_fallback then
          select_screen.fallback_when_missing[2] = table.getRandomElement(characters_ids_for_current_theme)
          if characters[select_screen.fallback_when_missing[2]]:is_bundle() then -- may pick a bundle
            select_screen.fallback_when_missing[2] = table.getRandomElement(characters[select_screen.fallback_when_missing[2]].sub_characters)
          end
        end
        refreshed.character = select_screen.fallback_when_missing[2]
      end
    end
  end
end



-- Updates the loaded and ready state for both states
function select_screen.refreshReadyStates(self)
  for _, playerConfig in pairs(self.roomState.players) do
    if self:isNetPlay() then
      playerConfig.ready =
          playerConfig.wants_ready and
          table.trueForAll(self.roomState.players, function(pc) return pc.loaded end)
    else
      print("wants ready: " .. tostring(playerConfig.wants_ready) .. ", loaded: " .. tostring(playerConfig.loaded))
      print("posId: " .. tostring(playerConfig.cursor.positionId) .. ", selected: " .. tostring(playerConfig.cursor.selected))
      playerConfig.ready = playerConfig.wants_ready and playerConfig.loaded
    end
  end
end

-- Leaves the 2p vs match room
function select_screen.do_leave()
  stop_the_music()
  GAME:clearMatch()
  return json_send({leave_room = true})
end

--#region entry point and leave point
-- Function to tell the select screen to exit
function select_screen.on_quit()
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
--#endregion


--#region asset loading

--#endregion


--#region handling cursor input
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
    player.character_is_random = random_character_special_value
    player.character = table.getRandomElement(characters_ids_for_current_theme)
    if characters[player.character]:is_bundle() then -- may pick a bundle
      player.cursor.state.character = table.getRandomElement(characters[player.character].sub_characters)
    end
    player.character_display_name = characters[player.character].display_name
    character_loader_load(player.character)
    player.cursor.positionId = "__Ready"
    player.cursor.position = shallowcpy(self.name_to_xy_per_page[self.current_page]["__Ready"])
    player.cursor.can_super_select = false
  elseif player.cursor.positionId == "__Mode" then
    player.ranked = not player.ranked
  elseif (player.cursor.positionId ~= "__Empty" and player.cursor.positionId ~= "__Reserved") then
    player.character_is_random = nil
    player.character = player.cursor.positionId
    if characters[player.character]:is_bundle() then -- may pick a bundle
      player.character_is_random = player.character
      player.character = table.getRandomElement(characters[player.character_is_random].sub_characters)
    end
    player.character_display_name = characters[player.character].display_name
    local character = characters[player.character]
    if not player.character_is_random then
      noisy = character:play_selection_sfx()
    elseif characters[player.character_is_random] then
      noisy = characters[player.character_is_random]:play_selection_sfx()
    end
    character_loader_load(player.character)
    if super then
      if character.stage then
        player.stage = character.stage
        stage_loader_load(player.stage)
        player.stage_is_random = false
      end
      if character.panels then
        player.panels_dir = character.panels
      end
    end
    --When we select a character, move cursor to "__Ready"
    player.cursor.positionId = "__Ready"
    player.cursor.position = shallowcpy(self.name_to_xy_per_page[self.current_page]["__Ready"])
    player.cursor.can_super_select = false
  end
  return noisy
end
--#endregion


--#region handling server messages

--#endregion


--#region battleroom state
function select_screen.isNetPlay(self)
  return select_screen.character_select_mode == "2p_net_vs"
end

function select_screen.isMultiplayer(self)
  return select_screen.character_select_mode == "2p_net_vs" or select_screen.character_select_mode == "2p_local_vs"
end

-- Makes sure all the client data is up to date and ready
function select_screen.refreshLoadingState(self, playerNumber)
  self.roomState.players[playerNumber].loaded = characters[self.roomState.players[playerNumber].character] and characters[self.roomState.players[playerNumber].character].fully_loaded and stages[self.roomState.players[playerNumber].stage] and stages[self.roomState.players[playerNumber].stage].fully_loaded
end
--#endregion

--#region business functions altering the state

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
function select_screen.change_stage(state, increment)
  -- random_stage_special_value is placed at the end of the list and is 'replaced' by a random pick and stage_is_random=true
  local current = nil
  for k, v in ipairs(stages_ids_for_current_theme) do
    if (not state.stage_is_random and v == state.stage) or (state.stage_is_random and v == state.stage_is_random) then
      current = k
      break
    end
  end
  if state.stage == nil or state.stage_is_random == random_stage_special_value then
    current = #stages_ids_for_current_theme + 1
  end
  if current == nil then -- stage belonged to another set of stages, it's no more in the list
    current = 0
  end
  local dir_count = #stages_ids_for_current_theme + 1
  local new_stage_idx = ((current - 1 + increment) % dir_count) + 1
  if new_stage_idx <= #stages_ids_for_current_theme then
    local new_stage = stages_ids_for_current_theme[new_stage_idx]
    if stages[new_stage]:is_bundle() then
      state.stage_is_random = new_stage
      state.stage = table.getRandomElement(stages[new_stage].sub_stages)
    else
      state.stage_is_random = nil
      state.stage = new_stage
    end
  else
    state.stage_is_random = random_stage_special_value
    state.stage = table.getRandomElement(stages_ids_for_current_theme)
    if stages[state.stage]:is_bundle() then -- may pick a bundle!
      state.stage = table.getRandomElement(stages[state.stage].sub_stages)
    end
  end
  logger.trace("stage and stage_is_random: " .. state.stage .. " / " .. (state.stage_is_random or "nil"))
end
--#endregion





--#region randomisation
-- Randomizes the settings if they are set to random
function patch_is_random(refreshed) -- retrocompatibility
  if refreshed ~= nil then
    if refreshed.stage_is_random == true then
      refreshed.stage_is_random = random_stage_special_value
    elseif refreshed.stage_is_random == false then
      refreshed.stage_is_random = nil
    elseif refreshed.stage_is_random ~= nil and refreshed.stage_is_random ~= random_stage_special_value and stages[refreshed.stage_is_random] == nil then
      refreshed.stage_is_random = random_stage_special_value
    end
    if refreshed.character_is_random == true then
      refreshed.character_is_random = random_character_special_value
    elseif refreshed.character_is_random == false then
      refreshed.character_is_random = nil
    elseif refreshed.character_is_random ~= nil and refreshed.character_is_random ~= random_character_special_value and characters[refreshed.character_is_random] == nil then
      refreshed.character_is_random = random_character_special_value
    end
  end
end

-- Resolve the current character if it is random
function select_screen.resolve_character_random(playerConfig)
  if playerConfig.character_is_random then
    if playerConfig.character_is_random == random_character_special_value then
      playerConfig.character = table.getRandomElement(characters_ids_for_current_theme)
      if characters[playerConfig.character]:is_bundle() then -- may pick a bundle
        playerConfig.character = table.getRandomElement(characters[playerConfig.character].sub_characters)
      end
    else
      playerConfig.character = table.getRandomElement(characters[playerConfig.character_is_random].sub_characters)
    end
    return true
  end
  return false
end

-- Resolve the current stage if it is random
function select_screen.resolve_stage_random(playerConfig)
  if playerConfig.stage_is_random ~= nil then
    if playerConfig.stage_is_random == random_stage_special_value then
      playerConfig.stage = table.getRandomElement(stages_ids_for_current_theme)
      if stages[playerConfig.stage]:is_bundle() then
        playerConfig.stage = table.getRandomElement(stages[playerConfig.stage].sub_stages)
      end
    else
      playerConfig.stage = table.getRandomElement(stages[playerConfig.stage_is_random].sub_stages)
    end
  end
end
--#endregion

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

-- returns the room initialization message
function select_screen.awaitRoomInitializationMessage(self)
  -- Wait till we have the room setup messages from the server
  local retries, retry_limit = 0, 250
  local msg
  while not global_initialize_room_msg and retries < retry_limit do
    msg = server_queue:pop_next_with("create_room", "character_select", "spectate_request_granted")
    print("try "..retries.."; server_queue.first is "..server_queue.first.."; sevrer_queue.last is "..server_queue.last)
    if msg then
      global_initialize_room_msg = msg
    end
    gprint(loc("ss_init"), unpack(themes[config.theme].main_menu_screen_pos))
    wait()
    if not do_messages() then
      return main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}
    end
    retries = retries + 1
  end

  -- If we never got the room setup message, bail
  if not global_initialize_room_msg then
    -- abort due to timeout
    logger.warn(loc("ss_init_fail") .. "\n")
    return main_dumb_transition, {main_select_mode, loc("ss_init_fail") .. "\n\n" .. loc("ss_return"), 60, 300}
  end

  return nil
end

function select_screen.initializeNetPlayRoom(self)
  self:setPlayerRatings(global_initialize_room_msg)
  self:setPlayerNumbers(global_initialize_room_msg)
  self:setPlayerStates(global_initialize_room_msg)
  self:updateWinCountsFromMessage(global_initialize_room_msg)
  self:updateReplayInfoFromMessage(global_initialize_room_msg)
  self:setMatchType(global_initialize_room_msg)
  self:setExpectedWinRatios()
end

function select_screen.setPlayerRatings(self, msg)
  if msg.ratings then
    self.currentRoomRatings = msg.ratings
  end
end

function select_screen.setPlayerNumbers(self, msg)
  -- player_settings exists for spectate_request_granted but not for create_room or character_select
  -- on second runthrough we should still have data from the old select_screen, including player_numbers
  if msg.player_settings and msg.player_settings.player_number then
    self.my_player_number = msg.player_settings.player_number
  elseif GAME.battleRoom.spectating then
    self.my_player_number = 1
  elseif self.my_player_number and self.my_player_number ~= 0 then
    logger.debug("We assumed our player number is still " .. self.my_player_number)
  else
    error(loc("nt_player_err"))
    logger.error("The server never told us our player number.  Assuming it is 1")
    self.my_player_number = 1
  end

  -- same for opponent_settings, read above
  if msg.opponent_settings and msg.opponent_settings.player_number then
    self.op_player_number = msg.opponent_settings.player_number or self.op_player_number
  elseif GAME.battleRoom.spectating then
    self.op_player_number = 2
  elseif self.op_player_number and self.op_player_number ~= 0 then
    logger.debug("We assumed op player number is still " .. self.op_player_number)
  else
    error("We never heard from the server as to what player number we are")
    logger.error("The server never told us our player number.  Assuming it is 2")
    self.op_player_number = 2
  end
end

function select_screen.setPlayerStates(self, msg)
  if self.roomState.my_player_number == 2 and msg.a_menu_state ~= nil
    and msg.b_menu_state ~= nil then
    logger.debug("inverting the states to match player number!")
    self.roomState.myState = msg.b_menu_state
    self.roomState.opState = msg.a_menu_state
  else
    self.roomState.myState = msg.a_menu_state
    self.roomState.opState = msg.b_menu_state
  end

  refresh_based_on_own_mods(self.roomState.myState)
  refresh_based_on_own_mods(self.roomState.opState)
end

function select_screen.updateWinCountsFromMessage(self, msg)
  if msg.win_counts then
    GAME.battleRoom:updateWinCounts(msg.win_counts)
  end
end

function select_screen.updateReplayInfoFromMessage(self, msg)
  if msg.replay_of_match_so_far then
    replay_of_match_so_far = msg.replay_of_match_so_far
  end
end

function select_screen.setMatchType(self, msg)
  if msg.ranked then
    self.roomState.match_type = "Ranked"
    self.roomState.match_type_message = ""
  else
    self.roomState.match_type = "Casual"
  end
end

function select_screen.setExpectedWinRatios(self)
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

function select_screen.setFallbackAssets(self)
  select_screen.fallback_when_missing = {nil, nil}
end

function select_screen.setupForNetPlay(self)
  GAME:clearMatch()

  drop_old_data_messages() -- Starting a new game, clear all old data messages from the previous game
  logger.debug("Reseting player stacks")

  local abort = self:awaitRoomInitializationMessage()
  if abort then
    -- abort due to connection loss or timeout
    return abort
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
  for playerNumber, _ in pairs(self.roomState.players) do
    self:setInitialCursor(playerNumber)
  end
end

function select_screen.setInitialCursor(self, playerNumber)
  local cursor = {}

  cursor.position = shallowcpy(self.name_to_xy_per_page[self.current_page]["__Ready"])
  cursor.positionId = self.drawMap[self.current_page][cursor.position[1]][cursor.position[2]]
  cursor.can_super_select = false
  cursor.selected = false

  self.roomState.players[playerNumber].cursor = cursor

end

function select_screen.drawMapToPageIdMapTransform(self)
  -- be wary: name_to_xy_per_page is kinda buggy for larger blocks as they span multiple positions (we retain the last one), and is completely broken with __Empty
  self.name_to_xy_per_page = {}
  for p = 1, self.pages_amount do
    self.name_to_xy_per_page[p] = {}
    for i = 1, self.ROWS do
      for j = 1, self.COLUMNS do
        if self.drawMap[p][i][j] then
          self.name_to_xy_per_page[p][self.drawMap[p][i][j]] = {i, j}
        end
      end
    end
  end
end

function select_screen.initializeFromPlayerConfig(self, playerNumber)
  self.roomState.players[playerNumber].stage = config.stage
  self.roomState.players[playerNumber].stage_is_random = ((config.stage == random_stage_special_value or stages[config.stage]:is_bundle()) and config.stage or nil)
  self.roomState.players[playerNumber].character = config.character
  self.roomState.players[playerNumber].character_is_random = ((config.character == random_character_special_value or characters[config.character]:is_bundle()) and config.character or nil)
  self.roomState.players[playerNumber].level = config.level
  self.roomState.players[playerNumber].panels_dir = config.panels
  self.roomState.players[playerNumber].ready = false
  self.roomState.players[playerNumber].ranked = config.ranked
end

function select_screen.loadCharacter(self, playerNumber)
  if self.roomState.players[playerNumber].character_is_random then
    select_screen.resolve_character_random(self.roomState.players[playerNumber])
  end
  character_loader_load(self.roomState.players[playerNumber].character)
  self.roomState.players[playerNumber].character_display_name = characters[self.roomState.players[playerNumber].character].display_name
end

function select_screen.loadStage(self, playerNumber)
  if self.roomState.players[playerNumber].stage_is_random then
    select_screen.resolve_stage_random(self.roomState.players[playerNumber])
  end
  stage_loader_load(self.roomState.players[playerNumber].stage)
  self.roomState.players[playerNumber].stage_display_name = stages[self.roomState.players[playerNumber].stage].display_name
end

function select_screen.setUpMyPlayer(self)
  -- set up the local player
  if not self:isNetPlay() and not self.my_player_number then
    self.my_player_number = 1
  end
  self:initializeFromPlayerConfig(self.my_player_number)
  self:loadCharacter(self.my_player_number)
  self:loadStage(self.my_player_number)
  self:refreshLoadingState(self.my_player_number)
end

function select_screen.setUpOpponentPlayer(self)
  if self.roomState.opState ~= nil then
    self.roomState.players[self.op_player_number] = shallowcpy(self.roomState.opState)
    if self:isNetPlay() then
      self.roomState.opState = nil -- retains state of the second player, also: don't unload its character when going back and forth
    else
      self:loadCharacter(self.op_player_number)
      self:loadStage(self.op_player_number)
    end
  else
    self:initializeFromPlayerConfig(self.op_player_number)
    self:loadCharacter(self.op_player_number)
    self:loadStage(self.op_player_number)
  end

  self:refreshLoadingState(self.op_player_number)
end

function select_screen.updateMyConfig(self)
  -- update config, does not redefine it
  local myPlayer = self.roomState.players[self.my_player_number]
  config.character = myPlayer.character_is_random or myPlayer.character
  config.stage = myPlayer.stage_is_random or myPlayer.stage
  config.level = myPlayer.level
  config.ranked = myPlayer.ranked
  config.panels = myPlayer.panels_dir
end

function select_screen.handleInput(self)
  local up, down, left, right = {-1, 0}, {1, 0}, {0, -1}, {0, 1}
  if not GAME.battleRoom.spectating then
    local KMax = 1
    if select_screen.character_select_mode == "2p_local_vs" then
      KMax = 2
    end
    for i = 1, KMax do
      local player = self.roomState.players[i]
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
            return self.on_quit()
          end
          cursor.selected = false
          cursor.position = shallowcpy(self.name_to_xy_per_page[self.current_page]["__Leave"])
          cursor.positionId = "__Leave"
          cursor.can_super_select = false
        end
      end
      if player ~= nil then
        player.cursor.positionId = self.drawMap[self.current_page][cursor.position[1]][cursor.position[2]]
        player.wants_ready = player.cursor.selected and player.cursor.positionId == "__Ready"
      end
    end
    self:updateMyConfig()

    if select_screen.character_select_mode == "2p_local_vs" then -- this is registered for future entering of the lobby
      global_op_state = shallowcpy(self.roomState.players[self.op_player_number])
      global_op_state.character = global_op_state.character_is_random or global_op_state.character
      global_op_state.stage = global_op_state.stage_is_random or global_op_state.stage
      global_op_state.wants_ready = false
    end

    if self:isNetPlay() and not content_equal(self.roomState.players[self.my_player_number], self.myPreviousConfig) and not GAME.battleRoom.spectating then
      json_send({menu_state = self.roomState.players[self.my_player_number]})
    end
    self.myPreviousConfig = shallowcpy(self.roomState.players[self.my_player_number])
  else -- (we are spectating)
    if menu_escape() then
      self.do_leave()
      return {main_net_vs_lobby} -- we left the select screen as a spectator
    end
  end

  return nil
end

function select_screen.handleServerMessages(self)
  local messages = server_queue:pop_all_with("win_counts", "menu_state", "ranked_match_approved", "leave_room", "match_start", "ranked_match_denied")
  if global_initialize_room_msg then
    messages[#messages+1] = global_initialize_room_msg
    global_initialize_room_msg = nil
  end
  for _, msg in ipairs(messages) do
    self:updateWinCountsFromMessage(msg)
    if msg.menu_state then
      if GAME.battleRoom.spectating then
        if msg.player_number == 1 or msg.player_number == 2 then
          self.roomState.players[msg.player_number] = msg.menu_state
          refresh_based_on_own_mods(self.roomState.players[msg.player_number])
          character_loader_load(self.roomState.players[msg.player_number].character)
          stage_loader_load(self.roomState.players[msg.player_number].stage)
          self:refreshLoadingState(msg.player_number)
        end
      else
        self.roomState.players[self.op_player_number] = msg.menu_state
        refresh_based_on_own_mods(self.roomState.players[self.op_player_number])
        character_loader_load(self.roomState.players[self.op_player_number].character)
        stage_loader_load(self.roomState.players[self.op_player_number].stage)
        self:refreshLoadingState(self.op_player_number)
      end
      self:refreshReadyStates()
    end
    if msg.ranked_match_approved then
      self.roomState.match_type = "Ranked"
      self.roomState.match_type_message = ""
      if msg.caveats then
        self.roomState.match_type_message = self.roomState.match_type_message .. (msg.caveats[1] or "")
      end
    elseif msg.ranked_match_denied then
      self.roomState.match_type = "Casual"
      self.roomState.match_type_message = (loc("ss_not_ranked") or "") .. "  "
      if msg.reasons then
        self.roomState.match_type_message = self.roomState.match_type_message .. (msg.reasons[1] or loc("ss_err_no_reason"))
      end
    end
    if msg.leave_room then
      return main_dumb_transition, {main_net_vs_lobby, "", 0, 0} -- opponent left the select screen
    end
    if (msg.match_start or replay_of_match_so_far) and msg.player_settings and msg.opponent_settings then
      return self:startMatch(msg)
    end
  end

  return nil
end

function select_screen.getSeed(self, msg)
  -- Use the seed the server gives us if it makes one, else generate a basic one off data both clients have.
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

function select_screen.startMatch(self, msg)
  logger.debug("spectating: " .. tostring(GAME.battleRoom.spectating))
  local fake_P1 = {panel_buffer = "", gpanel_buffer = ""}
  local fake_P2 = {panel_buffer = "", gpanel_buffer = ""}
  refresh_based_on_own_mods(msg.opponent_settings)
  refresh_based_on_own_mods(msg.player_settings, true)
  refresh_based_on_own_mods(msg) -- for stage only, other data are meaningless to us
  -- mainly for spectator mode, those characters have already been loaded otherwise
  character_loader_load(msg.player_settings.character)
  character_loader_load(msg.opponent_settings.character)
  self.current_stage = msg.stage
  stage_loader_load(msg.stage)
  character_loader_wait()
  stage_loader_wait()
  GAME.match = Match("vs", GAME.battleRoom)

  GAME.match.seed = self:getSeed(msg)
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
  if GAME.battleRoom.spectating then
    P1.panel_buffer = fake_P1.panel_buffer
    P1.gpanel_buffer = fake_P1.gpanel_buffer
  end
  P2.panel_buffer = fake_P2.panel_buffer
  P2.gpanel_buffer = fake_P2.gpanel_buffer
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
    if replay.vs.ranked then
      -- this doesn't really make sense
      self.match_type = "Ranked"
      self.match_type_message = ""
    else
      self.match_type = "Casual"
    end
    replay_of_match_so_far = nil
    P1.play_to_end = true --this makes non local stacks run until caught up
    P2.play_to_end = true
  end

  replay.vs.ranked = msg.ranked

  to_print = loc("pl_game_start") .. "\n" .. loc("level") .. ": " .. P1.level .. "\n" .. loc("opponent_level") .. ": " .. P2.level
  if P1.play_to_end or P2.play_to_end then
    to_print = loc("pl_spectate_join")
  end

  local abort = self:showGameStartMessage()
  if abort then
    return abort
  end

  -- Proceed to the game screen and start the game
  P1:starting_state()
  P2:starting_state()
  return {main_dumb_transition, {main_net_vs, "", 0, 0}}
end

function select_screen.showGameStartMessage(self)
  -- For a short time, show the game start / spectate message
  for i = 1, 30 do
    gprint(to_print, unpack(themes[config.theme].main_menu_screen_pos))
    if not do_messages() then
      return {main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}}
    end
    process_all_data_messages() -- process data to get initial panel stacks setup
    wait()
  end
end

function select_screen.initialize(self, character_select_mode)
  self.character_select_mode = character_select_mode
  self.fallback_when_missing = {nil, nil}
  -- in roomstate goes everything that can change through player inputs
  self.roomState = {}
  self.roomState.players = {}
  for i=1, tonumber(self.character_select_mode:sub(1, 1)) do
    self.roomState.players[i] = {}
  end
  -- everything else gets its field directly on select_screen
  self.current_page = 1
end

-- The main screen for selecting characters and settings for a match
function select_screen.main(self, character_select_mode)
  self:initialize(character_select_mode)
  self:loadThemeAssets()
  self:setFallbackAssets()

  -- Setup settings for Main Character Select for 2 Player over Network
  if select_screen:isNetPlay() then
    local abort = self:setupForNetPlay()
    if abort then
      return abort
    else
      self:initializeNetPlayRoom()
    end
  end

  self:prepareDrawMap()
  self:drawMapToPageIdMapTransform()
  self:setInitialCursors()

  self:setUpMyPlayer()

  if self:isMultiplayer() then
    self:setUpOpponentPlayer()
  end
  self:refreshReadyStates()

  self.myPreviousConfig = shallowcpy(self.roomState.players[self.my_player_number])

  logger.trace("got to lines of code before net_vs_room character select loop")
  self.menu_clock = 0

  -- Main loop for running the select screen and drawing
  while true do
    graphics:draw(self)

    if select_screen:isNetPlay() then
      local func = self:handleServerMessages()
      if func then
        return unpack(func)
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
    if self.roomState.players[self.my_player_number].ready and self.character_select_mode == "1p_vs_yourself" then
      GAME.match = Match("vs", GAME.battleRoom)
      P1 = Stack{which = 1, match = GAME.match, is_local = true, panels_dir = self.roomState.players[self.my_player_number].panels_dir, level = self.roomState.players[self.my_player_number].level, character = self.roomState.players[self.my_player_number].character, player_number = 1}
      if GAME.battleRoom.trainingModeSettings then
        GAME.match.attackEngine = AttackEngine(P1)
        local startTime = 150
        local delayPerAttack = 6
        local attackCountPerDelay = 15
        local delay = GARBAGE_TRANSIT_TIME + GARBAGE_DELAY + (attackCountPerDelay * delayPerAttack) + 1
        for i = 1, attackCountPerDelay, 1 do
          GAME.match.attackEngine:addAttackPattern(GAME.battleRoom.trainingModeSettings.width, GAME.battleRoom.trainingModeSettings.height, startTime + (i * delayPerAttack) --[[start time]], delay--[[repeat]], nil--[[attack count]], false--[[metal]],  false--[[chain]])  
        end
      end
      GAME.match.P1 = P1
      if not GAME.battleRoom.trainingModeSettings then
        P1:set_garbage_target(P1)
      end
      P2 = nil
      self.current_stage = self.roomState.players[self.my_player_number].stage
      stage_loader_load(current_stage)
      stage_loader_wait()
      P1:starting_state()
      return main_dumb_transition, {main_local_vs_yourself, "", 0, 0}
    -- Handle two player vs game setup
    elseif self.roomState.players[self.my_player_number].ready and select_screen.character_select_mode == "2p_local_vs" and self.roomState.players[self.op_player_number].ready then
      GAME.match = Match("vs", GAME.battleRoom)
      P1 = Stack{which = 1, match = GAME.match, is_local = true, panels_dir = self.roomState.players[self.my_player_number].panels_dir, level = self.roomState.players[self.my_player_number].level, character = self.roomState.players[self.my_player_number].character, player_number = 1}
      GAME.match.P1 = P1
      P2 = Stack{which = 2, match = GAME.match, is_local = true, panels_dir = self.roomState.players[self.op_player_number].panels_dir, level = self.roomState.players[self.op_player_number].level, character = self.roomState.players[self.op_player_number].character, player_number = 2}
      GAME.match.P2 = P2
      P1:set_garbage_target(P2)
      P2:set_garbage_target(P1)
      self.current_stage = self.roomState.players[self.my_player_number][math.random(1, #self.roomState.players)].stage
      stage_loader_load(current_stage)
      stage_loader_wait()
      P2:moveForPlayerNumber(2)

      P1:starting_state()
      P2:starting_state()
      return main_dumb_transition, {main_local_vs, "", 0, 0}

    -- Fetch the next network messages for 2p vs. When we get a start message we will transition there.
    elseif select_screen:isNetPlay() then
      if not do_messages() then
        return main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}
      end
    end
  end
end

return select_screen