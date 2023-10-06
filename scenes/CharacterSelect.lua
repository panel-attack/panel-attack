local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local consts = require("consts")
local input = require("inputManager")
local tableUtils = require("tableUtils")
local Menu = require("ui.Menu")
local class = require("class")
local logger = require("logger")

--@module CharacterSelect
-- The character select screen scene
local CharacterSelect = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_select_screen
    self.current_page = 1
    self.myPreviousConfig = nil
    self.menu_clock = 0
    
    -- set in child classes
    self.independentControls = false
    self.players = {{
        stage = config.stage,
        selectedStage = config.stage,
        character = config.character,
        selectedCharacter = config.character,
        level = config.level,
        inputMethod = config.inputMethod or "controller",
        panels_dir = config.panels,
        ready = false,
        ranked = config.ranked,
      }}
    self.my_player_number = 1
  end,
  Scene
)

-- begin abstract functions

-- Initalization specific to the child scene
function CharacterSelect:customLoad(sceneParams) end

-- updates specific to the child scene
function CharacterSelect:customUpdate(sceneParams) end

-- end abstract functions

function CharacterSelect:initializeFromMenuState(playerNumber, menuState)
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
  --self.players[playerNumber].cursor.positionId = menuState.cursor
  --self.players[playerNumber].cursor.position = shallowcpy(self.name_to_xy_per_page[self.current_page][menuState.cursor])
end

function CharacterSelect:updateExpectedWinRatios()
  self.currentRoomRatings = self.currentRoomRatings or {{new = 0, old = 0, difference = 0}, {new = 0, old = 0, difference = 0}}
  self.my_expected_win_ratio = nil
  self.op_expected_win_ratio = nil
  logger.trace("my_player_number = " .. self.my_player_number)
  logger.trace("op_player_number = " .. self.op_player_number)
  if self.currentRoomRatings[self.my_player_number].new and self.currentRoomRatings[self.my_player_number].new ~= 0 and self.currentRoomRatings[self.op_player_number] and self.currentRoomRatings[self.op_player_number].new ~= 0 then
    self.my_expected_win_ratio = (100 * math.round(1 / (1 + 10 ^ ((self.currentRoomRatings[self.op_player_number].new - self.currentRoomRatings[self.my_player_number].new) / RATING_SPREAD_MODIFIER)), 2))
    self.op_expected_win_ratio = (100 * math.round(1 / (1 + 10 ^ ((self.currentRoomRatings[self.my_player_number].new - self.currentRoomRatings[self.op_player_number].new) / RATING_SPREAD_MODIFIER)), 2))
  end
end

function CharacterSelect:playThemeMusic()
  if themes[config.theme].musics.select_screen then
    stop_the_music()
    find_and_add_music(themes[config.theme].musics, "select_screen")
  elseif themes[config.theme].musics.main then
    find_and_add_music(themes[config.theme].musics, "main")
  end
end

-- Resolve the current character if it is random
local function resolveRandomCharacter(character, selectedCharacter)
    if characters[character] == nil and selectedCharacter == random_character_special_value then
      character = tableUtils.getRandomElement(characters_ids_for_current_theme)
    end

    if characters[character]:is_bundle() then
      character = tableUtils.getRandomElement(characters[character].sub_characters)
    end
    return character
end

-- Resolve the current stage if it is random
local function resolveRandomStage(stage, selectedStage)
  if stages[stage] == nil and selectedStage == random_stage_special_value  then
    stage = tableUtils.getRandomElement(stages_ids_for_current_theme)
  end

  if stages[stage]:is_bundle() then
    stage = tableUtils.getRandomElement(stages[stage].sub_stages)
  end
  return stage
end

-- sets player.panels_dir / player.character / player.stage based on the respective selection values player.panels_dir, player.selectedCharacter and player.selectedStage
-- Automatically goes to a fallback or random mod if the selected one is not found
function CharacterSelect:refreshBasedOnOwnMods(player)
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

      player.stage = resolveRandomStage(player.stage, player.selectedStage)
      player.stage_display_name = stages[player.stage].stage_display_name
      StageLoader.load(player.stage)
      StageLoader.wait()
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

      player.character = resolveRandomCharacter(player.character, player.selectedCharacter)
      player.character_display_name = characters[player.character].character_display_name
      CharacterLoader.load(player.character)
      CharacterLoader.wait()
      
    end
  end
end

-- Makes sure all the client data is up to date and ready
function CharacterSelect:refreshLoadingState(playerNumber)
  self.players[playerNumber].loaded = characters[self.players[playerNumber].character] and characters[self.players[playerNumber].character].fully_loaded and stages[self.players[playerNumber].stage] and stages[self.players[playerNumber].stage].fully_loaded
end

-- Updates the ready state for all players
function CharacterSelect:refreshReadyStates()
  for playerNumber = 1, #self.players do
    self.players[playerNumber].ready = self.players[playerNumber].wants_ready and self.players[playerNumber].loaded
  end
end

function CharacterSelect:setUpOpponentPlayer()
  self.op_player_number = 2

  self:initializeFromPlayerConfig(self.op_player_number)

  if global_op_state then
    self.players[self.op_player_number].selectedCharacter = global_op_state.character
    self.players[self.op_player_number].character = global_op_state.character
    self.players[self.op_player_number].stage = global_op_state.stage
    self.players[self.op_player_number].panels_dir = global_op_state.panels_dir
  end

  self:refreshBasedOnOwnMods(self.players[self.op_player_number])
  self:refreshLoadingState(self.op_player_number)
end

function CharacterSelect:load(sceneParams)
   --"2p_net_vs", msg
   --"2p_local_vs"
   --"2p_local_computer_vs"
   --"1p_vs_yourself"
  self:customLoad(sceneParams)

  
  if themes[config.theme].musics.select_screen then
    stop_the_music()
    find_and_add_music(themes[config.theme].musics, "select_screen")
  elseif themes[config.theme].musics.main then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  reset_filters()
  --self:prepareDrawMap()
  --self:drawMapToPageIdMapTransform()
  --self:setInitialCursors()

  --if not GAME.battleRoom.spectating then
  --  self:initializeFromPlayerConfig(self.my_player_number)
  --end
  self:refreshBasedOnOwnMods(self.players[self.my_player_number])
  self:refreshLoadingState(self.my_player_number)

  self:refreshReadyStates()

  self.myPreviousConfig = deepcpy(self.players[self.my_player_number])
  self.menu_clock = 0
end

function CharacterSelect:updateMyConfig()
  -- update config, does not redefine it
  local myPlayer = self.players[self.my_player_number]
  config.character = myPlayer.selectedCharacter
  config.stage = myPlayer.selectedStage
  config.level = myPlayer.level
  config.inputMethod = myPlayer.inputMethod
  config.ranked = myPlayer.ranked
  config.panels = myPlayer.panels_dir
end

function CharacterSelect:updateConfig()
  if not deep_content_equal(self.players[self.my_player_number], self.myPreviousConfig) then
    self:updateMyConfig()
    self.myPreviousConfig = deepcpy(self.players[self.my_player_number])
  end
end

function CharacterSelect:handleInput()
  local up, down, left, right = {-1, 0}, {1, 0}, {0, -1}, {0, 1}
  if not GAME.battleRoom.spectating then
    local local_players
    --[[if select_screen.character_select_mode == "2p_local_vs" then
      local_players = { self.my_player_number, self.op_player_number}
    else
      local_players = { self.my_player_number }
    end--]]
    local_players = { self.my_player_number }
    
    for i = 1, #local_players do
      local player = self.players[local_players[i]]
      --[[local cursor = player.cursor
      if menu_prev_page(i) then
        if not cursor.selected then
          self.current_page = util.bound(1, self.current_page - 1, self.pages_amount)
        end
      elseif menu_next_page(i) then
        if not cursor.selected then
          self.current_page = util.bound(1, self.current_page + 1, self.pages_amount)
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
            player.level = util.bound(1, player.level - 1, #level_to_starting_speed) --which should equal the number of levels in the game
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
            player.level = util.bound(1, player.level + 1, #level_to_starting_speed) --which should equal the number of levels in the game
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
      --]]

      --player.cursor.positionId = self.drawMap[self.current_page][cursor.position[1]][cursor.position[2]]
      --player.wants_ready = player.cursor.selected and player.cursor.positionId == "__Ready"
      player.wants_ready = true
      player.ranked = false
      player.level = 10
    end

    --[[if select_screen.character_select_mode == "2p_local_vs" then
      self:savePlayer2Config()
    end
    --]]

    self:updateConfig()
  else -- (we are spectating)
    if menu_escape() then
      self:on_quit()
      -- we left the select screen as a spectator, there is no need to wait on the server to confirm our leave
      return {main_net_vs_lobby}
    end
  end

  return nil
end

function CharacterSelect:update()
  if self:customUpdate() then
    return
  end
  
  --gfx_q:push({graphics.draw, {graphics, self}})
  
  self:refreshLoadingState(self.my_player_number)
  self:handleInput()
  
  self:refreshReadyStates()

  --if select_screen.character_select_mode == "2p_local_computer_vs" and self.players[self.my_player_number].ready then
  --  return self:start1pCpuMatch()
end

function CharacterSelect:drawBackground()
  self.backgroundImg:draw()
end

function CharacterSelect:unload()
  stop_the_music()
end

return CharacterSelect