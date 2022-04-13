local logger = require("logger")
require("select_screen.select_screen_graphics")

select_screen = class(function(self, character_select_mode)
  self.graphics = select_screen_graphics()
  self.character_select_mode = character_select_mode
  self.fallback_when_missing = {nil, nil}
  -- in roomstate goes everything that can change through player inputs
  self.roomState = {}
  -- everything else gets its field directly on select_screen
  
end)

function select_screen.draw(self)
  self.graphics:draw(self)
end

local wait = coroutine.yield
local current_page = 1

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
function select_screen.refresh_ready_states(self)
  for _, playerConfig in pairs(self.roomState.players) do
    if self:isNetPlay() then
      playerConfig.ready =
          playerConfig.wants_ready and
          table.trueForAll(self.roomState.players, function(pc) return pc.loaded end)
    else
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
function select_screen.on_quit(self)
  if themes[config.theme].musics.select_screen then
    stop_the_music()
  end
  if select_screen:isNetPlay() then
    -- Tell the server we want to leave, once it disconnects us we will actually leave
    if not do_leave() then
      ret = {main_dumb_transition, {main_select_mode, loc("ss_error_leave"), 60, 300}}
    end
  else
    ret = {main_select_mode}
  end
end
--#endregion


--#region asset loading

--#endregion


--#region handling cursor input
-- Moves the given cursor in the given direction
function select_screen.move_cursor(cursor, direction)
  local cursor_pos = cursor.position
  local dx, dy = unpack(direction)
  local can_x, can_y = wrap(1, cursor_pos[1] + dx, X), wrap(1, cursor_pos[2] + dy, Y)
  while can_x ~= cursor_pos[1] or can_y ~= cursor_pos[2] do
    if map[current_page][can_x][can_y] and (map[current_page][can_x][can_y] ~= map[current_page][cursor_pos[1]][cursor_pos[2]] or map[current_page][can_x][can_y] == "__Empty" or map[current_page][can_x][can_y] == "__Reserved") then
      break
    end
    can_x, can_y = wrap(1, can_x + dx, X), wrap(1, can_y + dy, Y)
  end
  cursor_pos[1], cursor_pos[2] = can_x, can_y
  local character = characters[map[current_page][can_x][can_y]]
  cursor.can_super_select = character and (character.stage or character.panels)
end


-- Function to know what to do when you press select on your current cursor
-- returns true if a sound should be played
function select_screen.on_select(cursor, super)
  local noisy = false
  local selectable = {__Stage = true, __Panels = true, __Level = true, __Ready = true}
  if selectable[cursor.state.cursor] then
    if cursor.selected and cursor.state.cursor == "__Stage" then
      -- load stage even if hidden!
      stage_loader_load(cursor.state.stage)
    end
    cursor.selected = not cursor.selected
  elseif cursor.state.cursor == "__Leave" then
    on_quit()
  elseif cursor.state.cursor == "__Random" then
    cursor.state.character_is_random = random_character_special_value
    cursor.state.character = table.getRandomElement(characters_ids_for_current_theme)
    if characters[cursor.state.character]:is_bundle() then -- may pick a bundle
      cursor.state.character = table.getRandomElement(characters[cursor.state.character].sub_characters)
    end
    cursor.state.character_display_name = characters[cursor.state.character].display_name
    character_loader_load(cursor.state.character)
    cursor.state.cursor = "__Ready"
    cursor.position = shallowcpy(name_to_xy_per_page[current_page]["__Ready"])
    cursor.can_super_select = false
  elseif cursor.state.cursor == "__Mode" then
    cursor.state.ranked = not cursor.state.ranked
  elseif (cursor.state.cursor ~= "__Empty" and cursor.state.cursor ~= "__Reserved") then
    cursor.state.character_is_random = nil
    cursor.state.character = cursor.state.cursor
    if characters[cursor.state.character]:is_bundle() then -- may pick a bundle
      cursor.state.character_is_random = cursor.state.character
      cursor.state.character = table.getRandomElement(characters[cursor.state.character_is_random].sub_characters)
    end
    cursor.state.character_display_name = characters[cursor.state.character].display_name
    local character = characters[cursor.state.character]
    if not cursor.state.character_is_random then
      noisy = character:play_selection_sfx()
    elseif characters[cursor.state.character_is_random] then
      noisy = characters[cursor.state.character_is_random]:play_selection_sfx()
    end
    character_loader_load(cursor.state.character)
    if super then
      if character.stage then
        cursor.state.stage = character.stage
        stage_loader_load(cursor.state.stage)
        cursor.state.stage_is_random = false
      end
      if character.panels then
        cursor.state.panels_dir = character.panels
      end
    end
    --When we select a character, move cursor to "__Ready"
    cursor.state.cursor = "__Ready"
    cursor.position = shallowcpy(name_to_xy_per_page[current_page]["__Ready"])
    cursor.can_super_select = false
  end
  return noisy
end
--#endregion


--#region handling server messages
-- Returns a string with the players rating, win rate, and expected rating
function select_screen.get_player_state_str(player_number, rating_difference, win_count, op_win_count, expected_win_ratio)
  local state = ""
  if current_server_supports_ranking then
    state = state .. loc("ss_rating") .. " " .. (global_current_room_ratings[player_number].league or "")
    if not global_current_room_ratings[player_number].placement_match_progress then
      state = state .. "\n" .. rating_difference .. global_current_room_ratings[player_number].new
    elseif global_current_room_ratings[player_number].placement_match_progress and global_current_room_ratings[player_number].new and global_current_room_ratings[player_number].new == 0 then
      state = state .. "\n" .. global_current_room_ratings[player_number].placement_match_progress
    end
  end
  if select_screen:isMultiplayer() then
    if current_server_supports_ranking then
      state = state .. "\n"
    end
    state = state .. loc("ss_wins") .. " " .. win_count
    if (current_server_supports_ranking and expected_win_ratio) or win_count + op_win_count > 0 then
      state = state .. "\n" .. loc("ss_winrate") .. "\n"
      local need_line_return = false
      if win_count + op_win_count > 0 then
        state = state .. "    " .. loc("ss_current_rating") .. " " .. (100 * round(win_count / (op_win_count + win_count), 2)) .. "%"
        need_line_return = true
      end
      if current_server_supports_ranking and expected_win_ratio then
        if need_line_return then
          state = state .. "\n"
        end
        state = state .. "    " .. loc("ss_expected_rating") .. " " .. expected_win_ratio .. "%"
      end
    end
  end
  return state
end
--#endregion


--#region battleroom state
select_screen_state = class(
  function(self)

  end
)

function select_screen.isNetPlay(self)
  return select_screen.character_select_mode == "2p_net_vs"
end

function select_screen.isMultiplayer(self)
  return select_screen.character_select_mode == "2p_net_vs" or select_screen.character_select_mode == "2p_local_vs"
end

-- Makes sure all the client data is up to date and ready
function select_screen.confirmLoadingState(self, playerNumber)
  self.roomState.players[playerNumber].loaded = characters[self.roomState.players[playerNumber].character] and characters[self.roomState.players[playerNumber].character].fully_loaded and stages[self.roomState.players[playerNumber].stage] and stages[self.roomState.players[playerNumber].stage].fully_loaded
  self.roomState.players[playerNumber].wants_ready = self.roomState.players[playerNumber].ready
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
local function patch_is_random(refreshed) -- retrocompatibility
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
  while not global_initialize_room_msg and retries < retry_limit do
    local msg = server_queue:pop_next_with("create_room", "character_select", "spectate_request_granted")
    if msg then
      self.roomInitializationMessage = msg
    end
    gprint(loc("ss_init"), unpack(main_menu_screen_pos))
    wait()
    if not do_messages() then
      return main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}
    end
    retries = retries + 1
  end

  -- If we never got the room setup message, bail
  if not global_initialize_room_msg then
    -- abort due to timeout
    warning(loc("ss_init_fail") .. "\n")
    return main_dumb_transition, {main_select_mode, loc("ss_init_fail") .. "\n\n" .. loc("ss_return"), 60, 300}
  end

  return nil
end

function select_screen.initializeNetPlayRoom(self)
  self:setPlayerRatings()
  self:setPlayerNumbers()
  self:setPlayerStates()
  self:updateWinCounts()
  self:updateReplayInfo()
  self:setMatchType()
  self:setExpectedWinRatios()
end

function select_screen.setPlayerRatings(self)
  if self.roomInitializationMessage.ratings then
    self.currentRoomRatings = self.roomInitializationMessage.ratings
  end
end

function select_screen.setPlayerNumbers(self)
  if self.roomInitializationMessage.your_player_number then
    self.my_player_number = self.roomInitializationMessage.your_player_number
  elseif GAME.battleRoom.spectating then
    self.my_player_number = 1
  elseif self.my_player_number and self.my_player_number ~= 0 then
    logger.debug("We assumed our player number is still " .. self.my_player_number)
  else
    error(loc("nt_player_err"))
    logger.error("The server never told us our player number.  Assuming it is 1")
    self.my_player_number = 1
  end

  if self.roomInitializationMessage.op_player_number then
    self.op_player_number = self.roomInitializationMessage.op_player_number or self.op_player_number
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

function select_screen.setPlayerStates(self)
  if self.roomState.my_player_number == 2 and self.roomInitializationMessage.a_menu_state ~= nil
    and self.roomInitializationMessage.b_menu_state ~= nil then
    logger.warn("inverting the states to match player number!")
    self.roomState.myState = self.roomInitializationMessage.b_menu_state
    self.roomState.opState = self.roomInitializationMessage.a_menu_state
  else
    self.roomState.myState = self.roomInitializationMessage.a_menu_state
    self.roomState.opState = self.roomInitializationMessage.b_menu_state
  end

  refresh_based_on_own_mods(self.roomState.myState)
  refresh_based_on_own_mods(self.roomState.opState)
end

function select_screen.updateWinCounts(self)
  if self.roomInitializationMessage.win_counts then
    GAME.battleRoom:updateWinCounts(msg.win_counts)
  end
end

function select_screen.updateReplayInfo(self)
  if self.roomInitializationMessage.replay_of_match_so_far then
    self.roomState.replayInfo = self.roomInitializationMessage.replay_of_match_so_far
  end
end

function select_screen.setMatchType(self)
  if self.roomInitializationMessage.ranked then
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
  if self.currentRoomRatings[my_player_number].new and self.currentRoomRatings[my_player_number].new ~= 0 and self.currentRoomRatings[op_player_number] and self.currentRoomRatings[op_player_number].new ~= 0 then
    self.my_expected_win_ratio = (100 * round(1 / (1 + 10 ^ ((self.currentRoomRatings[op_player_number].new - self.currentRoomRatings[my_player_number].new) / RATING_SPREAD_MODIFIER)), 2))
    self.op_expected_win_ratio = (100 * round(1 / (1 + 10 ^ ((self.currentRoomRatings[my_player_number].new - self.currentRoomRatings[op_player_number].new) / RATING_SPREAD_MODIFIER)), 2))
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
  self.drawMap = {}

  self.pages_amount = fill_map(template_map, self.drawMap)
  if self.current_page > self.pages_amount then
    self.current_page = 1
  end
end

function select_screen.setInitialCursors(self)
  self.roomState.cursorP1 = {position = shallowcpy(self.name_to_xy_per_page[current_page]["__Ready"]), can_super_select = false, selected = false}
  self.roomState.cursorP2 = {position = shallowcpy(self.name_to_xy_per_page[current_page]["__Ready"]), can_super_select = false, selected = false}
end

function select_screen.drawMapToPageIdMapTransform(self)
  -- be wary: name_to_xy_per_page is kinda buggy for larger blocks as they span multiple positions (we retain the last one), and is completely broken with __Empty
  self.name_to_xy_per_page = {}
  for p = 1, self.pages_amount do
    self.name_to_xy_per_page[p] = {}
    for i = 1, self.graphics.ROWS do
      for j = 1, self.graphics.COLUMNS do
        if self.drawMap[p][i][j] then
          self.name_to_xy_per_page[p][self.drawMap[p][i][j]] = {i, j}
        end
      end
    end
  end
end

function select_screen.initializeFromPlayerConfig(self, playerNumber)
  self.roomState.player[playerNumber].stage = config.stage
  self.roomState.player[playerNumber].stage_is_random = ((config.stage == random_stage_special_value or stages[config.stage]:is_bundle()) and config.stage or nil)
  self.roomState.player[playerNumber].character = config.character
  self.roomState.player[playerNumber].character_is_random = ((config.character == random_character_special_value or characters[config.character]:is_bundle()) and config.character or nil)
  self.roomState.player[playerNumber].level = config.level
  self.roomState.player[playerNumber].panels_dir = config.panels
  self.roomState.player[playerNumber].ready = false
  self.roomState.player[playerNumber].ranked = config.ranked
end

function select_screen.loadCharacter(self, playerNumber)
  if self.roomState.player[playerNumber].character_is_random then
    select_screen.resolve_character_random(self.roomState.player[playerNumber])
  else
    character_loader_load(self.roomState.player[playerNumber].character)
  end
  self.roomState.player[playerNumber].character_display_name = characters[self.roomState.player[playerNumber].character].display_name
end

function select_screen.loadStage(self, playerNumber)
  if self.roomState.player[playerNumber].stage_is_random then
    select_screen.resolve_stage_random(self.roomState.player[playerNumber])
  else
    stage_loader_load(self.roomState.player[playerNumber].stage)
  end
  self.roomState.player[playerNumber].stage_display_name = stages[self.roomState.player[playerNumber].stage].display_name
end

function select_screen.setUpMyPlayer(self)
  -- set up the local player
  self:initializeFromPlayerConfig(self.my_player_number)
  self:loadCharacter(self.my_player_number)
  self:loadStage(self.my_player_number)
  self:confirmLoadingState(self.my_player_number)
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

  self:confirmLoadingState(self.op_player_number)
end

function select_screen.handleInput(self)
  local up, down, left, right = {-1, 0}, {1, 0}, {0, -1}, {0, 1}
  if not GAME.battleRoom.spectating then
    local KMax = 1
    if select_screen.character_select_mode == "2p_local_vs" then
      KMax = 2
    end
    for i = 1, KMax do
      local cursor = cursor_data[i]
      if menu_prev_page(i) then
        if not cursor.selected then
          current_page = bound(1, current_page - 1, self.pages_amount)
        end
      elseif menu_next_page(i) then
        if not cursor.selected then
          current_page = bound(1, current_page + 1, self.pages_amount)
        end
      elseif menu_up(i) then
        if not cursor.selected then
          self.move_cursor(cursor, up)
        end
      elseif menu_down(i) then
        if not cursor.selected then
          self.move_cursor(cursor, down)
        end
      elseif menu_left(i) then
        if cursor.selected then
          if cursor.state.cursor == "__Level" then
            cursor.state.level = bound(1, cursor.state.level - 1, #level_to_starting_speed) --which should equal the number of levels in the game
          elseif cursor.state.cursor == "__Panels" then
            cursor.state.panels_dir = self.change_panels_dir(cursor.state.panels_dir, -1)
          elseif cursor.state.cursor == "__Stage" then
            self.change_stage(cursor.state, -1)
          end
        end
        if not cursor.selected then
          self.move_cursor(cursor, left)
        end
      elseif menu_right(i) then
        if cursor.selected then
          if cursor.state.cursor == "__Level" then
            cursor.state.level = bound(1, cursor.state.level + 1, #level_to_starting_speed) --which should equal the number of levels in the game
          elseif cursor.state.cursor == "__Panels" then
            cursor.state.panels_dir = self.change_panels_dir(cursor.state.panels_dir, 1)
          elseif cursor.state.cursor == "__Stage" then
            self.change_stage(cursor.state, 1)
          end
        end
        if not cursor.selected then
          self.move_cursor(cursor, right)
        end
      else
        -- code below is bit hard to read: basically we are storing the default sfx callbacks until it's needed (or not!) based on the on_select method
        local long_enter, long_enter_callback = menu_long_enter(i, true)
        local normal_enter, normal_enter_callback = menu_enter(i, true)
        if long_enter then
          if not self.on_select(cursor, true) then
            long_enter_callback()
          end
        elseif normal_enter and (not cursor.can_super_select or select_being_pressed_ratio(i) < super_selection_enable_ratio) then
          if not self.on_select(cursor, false) then
            normal_enter_callback()
          end
        elseif menu_escape() then
          if cursor.state.cursor == "__Leave" then
            on_quit()
          end
          cursor.selected = false
          cursor.position = shallowcpy(name_to_xy_per_page[current_page]["__Leave"])
          cursor.can_super_select = false
        end
      end
      if cursor.state ~= nil then
        cursor.state.cursor = map[current_page][cursor.position[1]][cursor.position[2]]
        cursor.state.wants_ready = cursor.selected and cursor.state.cursor == "__Ready"
      end
    end
    -- update config, does not redefine it
    config.character = cursor_data[1].state.character_is_random and cursor_data[1].state.character_is_random or cursor_data[1].state.character
    config.stage = cursor_data[1].state.stage_is_random and cursor_data[1].state.stage_is_random or cursor_data[1].state.stage
    config.level = cursor_data[1].state.level
    config.ranked = cursor_data[1].state.ranked
    config.panels = cursor_data[1].state.panels_dir

    if select_screen.character_select_mode == "2p_local_vs" then -- this is registered for future entering of the lobby
      global_op_state = shallowcpy(cursor_data[2].state)
      global_op_state.character = global_op_state.character_is_random and global_op_state.character_is_random or global_op_state.character
      global_op_state.stage = global_op_state.stage_is_random and global_op_state.stage_is_random or global_op_state.stage
      global_op_state.wants_ready = false
    end

    if select_screen:isNetPlay() and not content_equal(cursor_data[1].state, myPreviousConfig) and not GAME.battleRoom.spectating then
      json_send({menu_state = cursor_data[1].state})
    end
    myPreviousConfig = shallowcpy(cursor_data[1].state)
  else -- (we are spectating)
    if menu_escape() then
      do_leave()
      ret = {main_net_vs_lobby} -- we left the select screen as a spectator
    end
  end
end

-- The main screen for selecting characters and settings for a match
function select_screen.main(self)
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
  self:refresh_ready_states()

  self.myPreviousConfig = shallowcpy(self.roomState.players[self.my_player_number])

  logger.trace("got to lines of code before net_vs_room character select loop")
  menu_clock = 0

  -- Main loop for running the select screen and drawing
  while true do

    --self:handleServerMessages()
    -- Handle network messages for 2p vs net
    if select_screen:isNetPlay() then
      local messages = server_queue:pop_all_with("win_counts", "menu_state", "ranked_match_approved", "leave_room", "match_start", "ranked_match_denied")
      if global_initialize_room_msg then
        messages[#messages + 1] = global_initialize_room_msg
        global_initialize_room_msg = nil
      end
      for _, msg in ipairs(messages) do
        if msg.win_counts then
          GAME.battleRoom:updateWinCounts(msg.win_counts)
        end
        if msg.menu_state then
          if GAME.battleRoom.spectating then
            if msg.player_number == 1 or msg.player_number == 2 then
              cursor_data[msg.player_number].state = msg.menu_state
              refresh_based_on_own_mods(cursor_data[msg.player_number].state)
              character_loader_load(cursor_data[msg.player_number].state.character)
              stage_loader_load(cursor_data[msg.player_number].state.stage)
            end
          else
            cursor_data[2].state = msg.menu_state
            refresh_based_on_own_mods(cursor_data[2].state)
            character_loader_load(cursor_data[2].state.character)
            stage_loader_load(cursor_data[2].state.stage)
          end
          refresh_loaded_and_ready_states(cursor_data[1], cursor_data[2])
        end
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
        if msg.leave_room then
          return main_dumb_transition, {main_net_vs_lobby, "", 0, 0} -- opponent left the select screen
        end
        if (msg.match_start or replay_of_match_so_far) and msg.player_settings and msg.opponent_settings then
          logger.debug("spectating: " .. tostring(GAME.battleRoom.spectating))
          local fake_P1 = {panel_buffer = "", gpanel_buffer = ""}
          local fake_P2 = {panel_buffer = "", gpanel_buffer = ""}
          refresh_based_on_own_mods(msg.opponent_settings)
          refresh_based_on_own_mods(msg.player_settings, true)
          refresh_based_on_own_mods(msg) -- for stage only, other data are meaningless to us
          -- mainly for spectator mode, those characters have already been loaded otherwise
          character_loader_load(msg.player_settings.character)
          character_loader_load(msg.opponent_settings.character)
          current_stage = msg.stage
          stage_loader_load(msg.stage)
          character_loader_wait()
          stage_loader_wait()
          GAME.match = Match("vs", GAME.battleRoom)

          -- Use the seed the server gives us if it makes one, else generate a basic one off data both clients have.
          local seed
          if msg.seed or (replay_of_match_so_far and replay_of_match_so_far.vs and replay_of_match_so_far.vs.seed) then
            seed = msg.seed or (replay_of_match_so_far and replay_of_match_so_far.vs and replay_of_match_so_far.vs.seed)
          else 
            seed = 17
            seed = seed * 37 + global_current_room_ratings[1].new;
            seed = seed * 37 + global_current_room_ratings[2].new;
            seed = seed * 37 + GAME.battleRoom.playerWinCounts[1];
            seed = seed * 37 + GAME.battleRoom.playerWinCounts[2];
          end
          GAME.match.seed = seed
          local is_local = true
          if GAME.battleRoom.spectating then
            is_local = false
          end
          P1 = Stack(1, GAME.match, is_local, msg.player_settings.panels_dir, msg.player_settings.level, msg.player_settings.character, msg.player_settings.player_number)
          GAME.match.P1 = P1
          P1.cur_wait_time = default_input_repeat_delay -- this enforces default cur_wait_time for online games.  It is yet to be decided if we want to allow this to be custom online.
          P2 = Stack(2, GAME.match, false, msg.opponent_settings.panels_dir, msg.opponent_settings.level, msg.opponent_settings.character, msg.opponent_settings.player_number)
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
              match_type = "Ranked"
              match_type_message = ""
            else
              match_type = "Casual"
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

          -- For a short time, show the game start / spectate message
          for i = 1, 30 do
            gprint(to_print, unpack(main_menu_screen_pos))
            if not do_messages() then
              return main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}
            end
            process_all_data_messages() -- process data to get initial panel stacks setup
            wait()
          end

          -- Proceed to the game screen and start the game
          P1:starting_state()
          P2:starting_state()
          return main_dumb_transition, {main_net_vs, "", 0, 0}
        end
      end
    end

    -- Calculate the rating difference
    local my_rating_difference = ""
    local op_rating_difference = ""
    if current_server_supports_ranking and not global_current_room_ratings[my_player_number].placement_match_progress then
      if global_current_room_ratings[my_player_number].difference then
        if global_current_room_ratings[my_player_number].difference >= 0 then
          my_rating_difference = "(+" .. global_current_room_ratings[my_player_number].difference .. ") "
        else
          my_rating_difference = "(" .. global_current_room_ratings[my_player_number].difference .. ") "
        end
      end
      if global_current_room_ratings[op_player_number].difference then
        if global_current_room_ratings[op_player_number].difference >= 0 then
          op_rating_difference = "(+" .. global_current_room_ratings[op_player_number].difference .. ") "
        else
          op_rating_difference = "(" .. global_current_room_ratings[op_player_number].difference .. ") "
        end
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
        menu_clock = menu_clock + 1

        character_loader_update()
        stage_loader_update()
        refresh_loaded_and_ready_states(cursor_data[1].state, cursor_data[2] and cursor_data[2].state or nil)
        self:handleInput()
      end
    )

    if ret then
      return unpack(ret)
    end

    -- Handle one player vs game setup
    if cursor_data[1].state.ready and select_screen.character_select_mode == "1p_vs_yourself" then
      GAME.match = Match("vs", GAME.battleRoom)
      P1 = Stack(1, GAME.match, true, cursor_data[1].state.panels_dir, cursor_data[1].state.level, cursor_data[1].state.character)
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
      current_stage = cursor_data[1].state.stage
      stage_loader_load(current_stage)
      stage_loader_wait()
      P1:starting_state()
      return main_dumb_transition, {main_local_vs_yourself, "", 0, 0}
    -- Handle two player vs game setup
    elseif cursor_data[1].state.ready and select_screen.character_select_mode == "2p_local_vs" and cursor_data[2].state.ready then
      GAME.match = Match("vs", GAME.battleRoom)
      P1 = Stack(1, GAME.match, true, cursor_data[1].state.panels_dir, cursor_data[1].state.level, cursor_data[1].state.character)
      GAME.match.P1 = P1
      P2 = Stack(2, GAME.match, true, cursor_data[2].state.panels_dir, cursor_data[2].state.level, cursor_data[2].state.character)
      GAME.match.P2 = P2
      P1:set_garbage_target(P2)
      P2:set_garbage_target(P1)
      current_stage = cursor_data[math.random(1, 2)].state.stage
      stage_loader_load(current_stage)
      stage_loader_wait()
      P2:moveForPlayerNumber(2)
      -- TODO: this does not correctly implement starting configurations.
      -- Starting configurations should be identical for visible blocks, and
      -- they should not be completely flat.
      --
      -- In general the block-generation logic should be the same as the server's, so
      -- maybe there should be only one implementation.
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
