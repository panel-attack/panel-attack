local Scene = require("scenes.Scene")
local logger = require("logger")
local Button = require("ui.Button")
local scene_manager = require("scenes.scene_manager")
local input = require("inputManager")
local LevelSlider = require("ui.LevelSlider")
local tableUtils = require("tableUtils")

local MAX_CHARACTERS_PER_PAGE = 34
local MAX_ROWS = 5
local MAX_COLS = 9
local TILE_SIZE = 84
local GRID_SIZE = 100

local button_info = {
    characters = {
      x = 2, 
      y = 2
    },
    level = {
      x = 6, 
      y = 1, 
      width = 3
    },
    stage = {
      x = 3, 
      y = 1, 
      width = 3
    },
    panels = {
      x = 1, 
      y = 1, 
      width = 2
    },
    leave = {
      x = MAX_COLS, 
      y = MAX_ROWS
    },
    ready = {
      x = MAX_COLS, 
      y = 1
    },
    random = {
      x = 1, 
      y = 2
    }
  }

--@module CharacterSelect
local CharacterSelect = class(
  function (self, name, options)
    self.name = name
    self.game_setup_fn = options.game_setup_fn or function (game) end
    self.previous_scene = options.previous_scene or "main_menu"
    self.next_scene = options.next_scene or nil
    self.buttons = {
      characters = {},
      level_select = {},
      stage_select = {},
      panels_select = {},
      page_select = {},
      leave = nil,
      ready = nil,
      random = nil
    }
    self.current_page = 1;
    self.num_character_pages = nil
    self.cursor_pos = {
      x = button_info.ready.x, 
      y = button_info.ready.y
    }
    self.cursor_data = {}
    self.level_slider = nil
    self.button_grid = {}
    self.player_name_text = nil
  end,
  Scene
)

local brackets = {
  left = love.graphics.newText(love.graphics.getFont(), "<"),
  right = love.graphics.newText(love.graphics.getFont(), ">")
}

local function gridToScreen(x, y)
  return 98 + x * GRID_SIZE, 68 + y * GRID_SIZE
end

local function extractButtonInfo(button)
  return (button.x - 98) / GRID_SIZE, (button.y - 68) / GRID_SIZE, (button.width - TILE_SIZE) / GRID_SIZE + 1
end

function CharacterSelect:matchSetup(match) end
function CharacterSelect:customDraw() end

function CharacterSelect:moveCursor(x, y)
  self.cursor_pos.x = x
  self.cursor_pos.y = y
  self.cursor_data[1].selected = false
  self.buttons.level_select.enable:setEnabled(true)
  self.level_slider:setEnabled(false)
  self.buttons.stage_select.enable:setEnabled(true)
  self.buttons.stage_select.left:setEnabled(false)
  self.buttons.stage_select.right:setEnabled(false)
  self.buttons.panels_select.enable:setEnabled(true)
  self.buttons.panels_select.left:setEnabled(false)
  self.buttons.panels_select.right:setEnabled(false)
end

function CharacterSelect:onReady()
  self:moveCursor(button_info.ready.x, button_info.ready.y)

  local current_stage = self.cursor_data[1].state.stage
  stage_loader_load(current_stage)
  stage_loader_wait()

  -- Handle one player vs game setup
  GAME.match = Match("vs", GAME.battleRoom)
  GAME.match.P1 = Stack{which=1, match=GAME.match, is_local=true, panels_dir=self.cursor_data[1].state.panels_dir, level=self.cursor_data[1].state.level, character=self.cursor_data[1].state.character}
  
  scene_manager:switchScene(self.next_scene)
end

-- Sets the state object to a new stage based on the increment
local function changeStage(state, increment)
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
      state.stage = tableUtils.getRandomElement(stages[new_stage].sub_stages)
    else
      state.stage_is_random = nil
      state.stage = new_stage
    end
  else
    state.stage_is_random = random_stage_special_value
    state.stage = tableUtils.getRandomElement(stages_ids_for_current_theme)
    if stages[state.stage]:is_bundle() then -- may pick a bundle!
      state.stage = tableUtils.getRandomElement(stages[state.stage].sub_stages)
    end
  end
  logger.trace("stage and stage_is_random: " .. state.stage .. " / " .. (state.stage_is_random or "nil"))
end

-- Returns the panel dir for the given increment 
local function changePanelsDir(panels_dir, increment)
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

function CharacterSelect:showCharacterPage(page)
  local index = 0
  for i = 0, MAX_CHARACTERS_PER_PAGE - 1 do
    local x = (i + button_info.characters.x - 1) % MAX_COLS + 1
    local y = math.floor((i + button_info.characters.x - 1) / MAX_COLS + button_info.characters.y)
    self.button_grid[y][x] = nil
  end
  for i, character_button in ipairs(self.buttons.characters) do
    character_button:setVisibility(i > (page - 1) * MAX_CHARACTERS_PER_PAGE and i <= page * MAX_CHARACTERS_PER_PAGE)
    if character_button.isVisible then
      local x = (index + button_info.characters.x - 1) % MAX_COLS + 1
      local y = math.floor((index + button_info.characters.x - 1) / MAX_COLS + button_info.characters.y)
      self.button_grid[y][x] = character_button
      index = index + 1
    end
  end
end

function CharacterSelect:init()
  scene_manager:addScene(self)
  
  local outline_color = {234/255, 234/255, 234/255, 1}
  self.num_character_pages = math.ceil(#characters_ids_for_current_theme / MAX_CHARACTERS_PER_PAGE)
  
  for i = 1, MAX_ROWS do
    self.button_grid[i] = {}
  end
  
  -- init characters
  for i, id in ipairs(characters_ids_for_current_theme) do
    local name = string.gsub(characters[id].display_name, "%s", "\n")
    local page_index = (i - 1) % MAX_CHARACTERS_PER_PAGE
    local x = (page_index + button_info.characters.x - 1) % MAX_COLS + 1
    local y = math.floor((page_index + button_info.characters.x - 1) / MAX_COLS + button_info.characters.y)
    local x_pos, y_pos = gridToScreen(x, y)
    self.buttons.characters[i] = Button({
        x = x_pos, 
        y = y_pos, 
        width = TILE_SIZE, 
        height = TILE_SIZE, 
        label = name,
        translate = false,
        valign = "top",
        image = characters[id].images.icon, 
        outlineColor = outline_color,
        isVisible = false,
        onClick = function()
          self:moveCursor(x, y)
          self.cursor_data[1].state.character = id
          config.character = id
          characters[id]:play_selection_sfx()
          character_loader_load(id)
        end
      })
  end
  
  -- init random button
  local x, y = gridToScreen(button_info.random.x, button_info.random.y)
  self.buttons.random = Button({
      x = x, 
      y = y, 
      width = TILE_SIZE, 
      height = TILE_SIZE, 
      label = "random",
      outlineColor = outline_color,
      isVisible = false,
      onClick = function()
        self:moveCursor(button_info.random.x, button_info.random.y)
        play_optional_sfx(themes[config.theme].sounds.menu_validate)
        self.cursor_data[1].state.character = tableUtils.getRandomElement(characters_ids_for_current_theme)
        config.character = "__RandomCharacter"
        character_loader_load(self.cursor_data[1].state.character)
      end
    })
  
  -- init leave button
  x, y = gridToScreen(button_info.leave.x, button_info.leave.y)
  self.buttons.leave = Button({
      x = x, 
      y = y, 
      width = TILE_SIZE, 
      height = TILE_SIZE, 
      label = "leave",
      outlineColor = outline_color,
      isVisible = false,
      onClick = function()
        self:moveCursor(button_info.leave.x, button_info.leave.y)
        play_optional_sfx(themes[config.theme].sounds.menu_validate)
        -- branch
        scene_manager:switchScene(self.previous_scene)
      end
    })
  
  -- init ready button
  x, y = gridToScreen(button_info.ready.x, button_info.ready.y)
  self.buttons.ready = Button({
      x = x, 
      y = y, 
      width = TILE_SIZE, 
      height = TILE_SIZE, 
      label = "ready",
      outlineColor = outline_color,
      isVisible = false,
      onClick = function() self:onReady() end
    })
  
  -- init level selector
  x, y = gridToScreen(button_info.level.x, button_info.level.y)
  self.buttons.level_select.enable = Button({
      x = x, 
      y = y, 
      width = GRID_SIZE * button_info.level.width - GRID_SIZE + TILE_SIZE, 
      height = TILE_SIZE, 
      label = "level",
      valign = "top",
      outlineColor = outline_color,
      color = {0, 0, 0, 0},
      isVisible = false,
      onClick = function() 
        self:moveCursor(button_info.level.x, button_info.level.y)
        self.buttons.level_select.enable:setEnabled(false)
        self.level_slider:setEnabled(true)
        play_optional_sfx(themes[config.theme].sounds.menu_validate)
      end,
      onMousePressed = function() end
    })
  local tickLength = 11
  self.level_slider = LevelSlider({
      x = x + self.buttons.level_select.enable.width / 2 - tickLength * #themes[config.theme].images.IMG_levels / 2,
      y = y + self.buttons.level_select.enable.height / 2 - tickLength / 2,
      tickLength = tickLength,
      isVisible = false,
      value = config.level,
      onValueChange = function(s)
        play_optional_sfx(themes[config.theme].sounds.menu_move)
        config.level = s.value
        self.cursor_data[1].state.level = s.value
      end
    })
  
  -- init stage selector
  x, y = gridToScreen(button_info.stage.x, button_info.stage.y)
  local width = GRID_SIZE * (button_info.stage.width / 2 - 1) + TILE_SIZE
  self.buttons.stage_select.left = Button({
      x = x,
      y = y, 
      width = width, 
      height = TILE_SIZE, 
      label = "",
      translate = false,
      outlineColor = {0, 0, 0, 0},
      color = {0, 0, 0, 0},
      isVisible = false,
      onClick = function()
        play_optional_sfx(themes[config.theme].sounds.menu_move)
        changeStage(self.cursor_data[1].state, -1)
      end,
      onMousePressed = function() end
    })
  self.buttons.stage_select.right = Button({
      x = x + width, 
      y = y, 
      width = width, 
      height = TILE_SIZE, 
      label = "",
      translate = false,
      outlineColor = {0, 0, 0, 0},
      color = {0, 0, 0, 0},
      isVisible = false,
      onClick = function()
        play_optional_sfx(themes[config.theme].sounds.menu_move)
        changeStage(self.cursor_data[1].state, 1)
      end,
      onMousePressed = function() end
    })
  self.buttons.stage_select.enable = Button({
      x = x, 
      y = y, 
      width = GRID_SIZE * button_info.stage.width - GRID_SIZE + TILE_SIZE, 
      height = TILE_SIZE, 
      label = "stage",
      valign = "top",
      outlineColor = outline_color,
      color = {0, 0, 0, 0},
      isVisible = false,
      onClick = function() 
        self:moveCursor(button_info.stage.x, button_info.stage.y)
        self.cursor_data[1].selected = true
        self.cursor_data[1].state.cursor = "__Stage"
        self.buttons.stage_select.enable:setEnabled(false)
        self.buttons.stage_select.left:setEnabled(true)
        self.buttons.stage_select.right:setEnabled(true)
        play_optional_sfx(themes[config.theme].sounds.menu_validate)
      end,
      onMousePressed = function() end
    })
  
  -- init panels select
  width = GRID_SIZE * (button_info.panels.width / 2 - 1) + TILE_SIZE
  x, y = gridToScreen(button_info.panels.x, button_info.panels.y)
  self.buttons.panels_select.left = Button({
      x = x,
      y = y, 
      width = width, 
      height = TILE_SIZE, 
      label = "",
      translate = false,
      outlineColor = {0, 0, 0, 0},
      color = {0, 0, 0, 0},
      isVisible = false,
      onClick = function()
        play_optional_sfx(themes[config.theme].sounds.menu_move)
        self.cursor_data[1].state.panels_dir = changePanelsDir(self.cursor_data[1].state.panels_dir, -1)
      end,
      onMousePressed = function() end
    })
  self.buttons.panels_select.right = Button({
      x = x + width, 
      y = y, 
      width = width, 
      height = TILE_SIZE, 
      label = "",
      translate = false,
      outlineColor = {0, 0, 0, 0},
      color = {0, 0, 0, 0},
      isVisible = false,
      onClick = function()
        play_optional_sfx(themes[config.theme].sounds.menu_move)
        self.cursor_data[1].state.panels_dir = changePanelsDir(self.cursor_data[1].state.panels_dir, 1)
      end,
      onMousePressed = function() end
    })
  self.buttons.panels_select.enable = Button({
      x = x, 
      y = y, 
      width = GRID_SIZE * button_info.panels.width - GRID_SIZE + TILE_SIZE, 
      height = TILE_SIZE, 
      label = "panels",
      valign = "top",
      outlineColor = outline_color,
      color = {0, 0, 0, 0},
      isVisible = false,
      onClick = function() 
        self:moveCursor(button_info.panels.x, button_info.panels.y)
        self.cursor_data[1].selected = true
        self.cursor_data[1].state.cursor = "__Panels"
        self.buttons.panels_select.enable:setEnabled(false)
        self.buttons.panels_select.left:setEnabled(true)
        self.buttons.panels_select.right:setEnabled(true)
        play_optional_sfx(themes[config.theme].sounds.menu_validate)
      end,
      onMousePressed = function() end
    })
  
  -- init page select
  x, y = gridToScreen(5, 6)
  self.buttons.page_select.left = Button({
      x = x - 25,
      y = y - 5, 
      width = 25, 
      height = 25, 
      label = "<",
      translate = false,
      isVisible = false,
      onClick = function()
        play_optional_sfx(themes[config.theme].sounds.menu_move)
        self.current_page = bound(1, self.current_page - 1, self.num_character_pages)
        self:showCharacterPage(self.current_page)
      end
    })
  self.buttons.page_select.right = Button({
      x = x + TILE_SIZE, 
      y = y - 5, 
      width = 25, 
      height = 25, 
      label = ">",
      translate = false,
      isVisible = false,
      onClick = function()
        play_optional_sfx(themes[config.theme].sounds.menu_move)
        self.current_page = bound(1, self.current_page + 1, self.num_character_pages)
        self:showCharacterPage(self.current_page)
      end
    })

  self.button_grid[button_info.random.y][button_info.random.x] = self.buttons.random
  self.button_grid[button_info.leave.y][button_info.leave.x] = self.buttons.leave
  self.button_grid[button_info.ready.y][button_info.ready.x] = self.buttons.ready
  for i = 0, button_info.level.width - 1 do
    self.button_grid[button_info.level.y][button_info.level.x + i] = self.buttons.level_select.enable
  end
  for i = 0, button_info.stage.width - 1 do
    self.button_grid[button_info.stage.y][button_info.stage.x + i] = self.buttons.stage_select.enable
  end
  for i = 0, button_info.panels.width - 1 do
    self.button_grid[button_info.panels.y][button_info.panels.x + i] = self.buttons.panels_select.enable
  end
end

local character_select_mode = "1p_vs_yourself"
local fallback_when_missing = {nil, nil}

-- Resolve the current character if it is random
local function resolve_character_random(state)
  if state.character_is_random ~= nil then
    if state.character_is_random == random_character_special_value then
      state.character = tableUtils.getRandomElement(characters_ids_for_current_theme)
      if characters[state.character]:is_bundle() then -- may pick a bundle
        state.character = tableUtils.getRandomElement(characters[state.character].sub_characters)
      end
    else
      state.character = tableUtils.getRandomElement(characters[state.character_is_random].sub_characters)
    end
    return true
  end
  return false
end

-- Resolve the current stage if it is random
local function resolve_stage_random(state)
  if state.stage_is_random ~= nil then
    if state.stage_is_random == random_stage_special_value then
      state.stage = tableUtils.getRandomElement(stages_ids_for_current_theme)
      if stages[state.stage]:is_bundle() then
        state.stage = tableUtils.getRandomElement(stages[state.stage].sub_stages)
      end
    else
      state.stage = tableUtils.getRandomElement(stages[state.stage_is_random].sub_stages)
    end
  end
end

-- Makes sure all the client data is up to date and ready
local function add_client_data(state)
  state.loaded = characters[state.character] and characters[state.character].fully_loaded and stages[state.stage] and stages[state.stage].fully_loaded
  state.wants_ready = state.ready
end

-- Updates the loaded and ready state for both states
local function refresh_loaded_and_ready(state_1, state_2)
  state_1.loaded = characters[state_1.character] and characters[state_1.character].fully_loaded and stages[state_1.stage] and stages[state_1.stage].fully_loaded
  if state_2 then
    state_2.loaded = characters[state_2.character] and characters[state_2.character].fully_loaded and stages[state_2.stage] and stages[state_2.stage].fully_loaded
  end
end

function CharacterSelect:load()
  for _, button_group in pairs(self.buttons) do
    if button_group.TYPE == "Button" then
      button_group:updateLabel()
      button_group:setVisibility(true)
    else
      for _, button in pairs(button_group) do
        button:updateLabel()
        button:setVisibility(true)
      end
    end
  end
  self:showCharacterPage(self.current_page)
  self.level_slider:setVisibility(true)
  
  if not GAME.battleRoom then
    GAME.battleRoom = BattleRoom()
  end
  GAME.battleRoom.playerNames[2] = nil
  my_player_number = 1
  op_state = nil
  self.player_name_text = love.graphics.newText(love.graphics.getFont(), GAME.battleRoom.playerNames[1])
  if themes[config.theme].musics.select_screen then
    stop_the_music()
    find_and_add_music(themes[config.theme].musics, "select_screen")
  elseif themes[config.theme].musics.main then
    find_and_add_music(themes[config.theme].musics, "main")
  end

  GAME.backgroundImage = themes[config.theme].images.bg_select_screen
  reset_filters()
  
  op_win_count = op_win_count or 0
  match_type_message = match_type_message or ""

  self.cursor_data[1] = {}
  self.cursor_data[2] = {}

  -- our data (first player in local)
  if global_my_state ~= nil then
    self.cursor_data[1].state = shallowcpy(global_my_state)
    global_my_state = nil
  else
    self.cursor_data[1].state = {
      stage = config.stage,
      stage_is_random = ((config.stage == random_stage_special_value or stages[config.stage]:is_bundle()) and config.stage or nil),
      character = config.character,
      character_is_random = ((config.character == random_character_special_value or characters[config.character]:is_bundle()) and config.character or nil),
      level = config.level,
      panels_dir = config.panels,
      cursor = "__Ready",
      ready = false,
      ranked = config.ranked
    }
  end

  if resolve_character_random(self.cursor_data[1].state) then
    character_loader_load(self.cursor_data[1].state.character)
  end
  self.cursor_data[1].state.character_display_name = characters[self.cursor_data[1].state.character].display_name

  resolve_stage_random(self.cursor_data[1].state)
  stage_loader_load(self.cursor_data[1].state.stage)

  add_client_data(self.cursor_data[1].state)
  
  refresh_loaded_and_ready(self.cursor_data[1].state, self.cursor_data[2] and self.cursor_data[2].state or nil)
end

-- Draw the base cursor for the player
function CharacterSelect:drawCursor(x, y)
  local offset = 8
  local cur_blink_frequency = .33
  local cursor_frame = (math.floor(love.timer.getTime() / cur_blink_frequency) % 2) + 1
  local cur_img = themes[config.theme].images.IMG_char_sel_cursors[1][cursor_frame]
  local cur_img_left = themes[config.theme].images.IMG_char_sel_cursor_halves.left[1][cursor_frame]
  local cur_img_right = themes[config.theme].images.IMG_char_sel_cursor_halves.right[1][cursor_frame]
  local cur_img_w, cur_img_h = cur_img:getDimensions()
  local cursor_scale = (TILE_SIZE + offset * 2) / cur_img_w
  local button_x = x
  local button_y = y
  local button_width = 1
  if self.button_grid[y][x] then
    button_x, button_y, button_width = extractButtonInfo(self.button_grid[y][x])
  end
  x, y = gridToScreen(button_x, button_y)
  GAME.gfx_q:push({love.graphics.draw, {cur_img, cur_img_left, x - offset, y - offset, 0, cursor_scale, cursor_scale}})
  GAME.gfx_q:push({love.graphics.draw, {cur_img, cur_img_right, x + GRID_SIZE * (button_width - 1) + TILE_SIZE / 2, y - offset, 0, cursor_scale, cursor_scale}})
end

-- Draw the panel selection UI
function CharacterSelect:drawPanelsSelector()
  local index = 0
  local num_panels = self.level_slider.value < 9 and 6 or 7
  local panels_button = self.buttons.panels_select.enable
  local panel_size = .25 * TILE_SIZE
  for i, img in ipairs(panels[self.cursor_data[1].state.panels_dir].images.classic) do
    if i <= 8 and i ~= 7 and (i ~= 6 or self.level_slider.value >= 9) then
      local scale = panel_size / img[1]:getWidth()
      GAME.gfx_q:push({love.graphics.draw, {img[1], panels_button.x + panels_button.width / 2 + (index - num_panels / 2) * scale * img[1]:getWidth(), panels_button.y + panels_button.height / 2, 0, scale, scale, 0, img[1]:getHeight() / 2}})
      index = index + 1
    end
  end
  local x_offset
  if self.buttons.panels_select.left.isEnabled then
    x_offset = panels_button.width / 2 - panel_size * (num_panels / 2 + .9)
    GAME.gfx_q:push({love.graphics.draw, {brackets.left, panels_button.x + panels_button.width / 2 - panel_size * (num_panels / 2 + .5), panels_button.y + TILE_SIZE / 2, 0, 1, 1, 0, brackets.left:getHeight() / 2}})
    GAME.gfx_q:push({love.graphics.draw, {brackets.right, panels_button.x + panels_button.width / 2 + panel_size * (num_panels / 2 + .5), panels_button.y + TILE_SIZE / 2, 0, 1, 1, brackets.right:getWidth(), brackets.right:getHeight() / 2}})
  else
    x_offset = panels_button.width / 2 - panel_size * (num_panels / 2 + .51)
  end
  GAME.gfx_q:push({love.graphics.draw, {themes[config.theme].images.IMG_players[1], panels_button.x + x_offset, panels_button.y + TILE_SIZE / 2, 0, 1, 1, 0, themes[config.theme].images.IMG_players[1]:getHeight() / 2}})
end

-- Draw the stage select UI
function CharacterSelect:drawStage()
  local stage_dims = {80, 45}
  local img
  local display_name
  if self.cursor_data[1].state.stage_is_random then
    img = themes[config.theme].images.IMG_random_stage or stages[self.cursor_data[1].state.stage].images.thumbnail
    display_name = loc("random")
  else
    img = stages[self.cursor_data[1].state.stage].images.thumbnail
    display_name = stages[self.cursor_data[1].state.stage].display_name
  end
  local stage_button = self.buttons.stage_select.enable
  GAME.gfx_q:push({love.graphics.draw, {img, stage_button.x + stage_button.width / 2, stage_button.y + stage_button.height / 2, 0, stage_dims[1] / img:getWidth(), stage_dims[2] / img:getHeight(), img:getWidth() / 2, img:getHeight() / 2}})

  local x_offset
  if self.buttons.stage_select.left.isEnabled then
    GAME.gfx_q:push({love.graphics.draw, {brackets.left, stage_button.x + stage_button.width / 2 - (stage_dims[1] / 2 + 12), stage_button.y + stage_button.height / 2 + 10, 0, 1, 1, 0, brackets.left:getHeight() / 2}})
    GAME.gfx_q:push({love.graphics.draw, {brackets.right, stage_button.x + stage_button.width / 2 + stage_dims[1] / 2 + 12, stage_button.y + stage_button.height / 2 + 10, 0, 1, 1, brackets.right:getWidth(), brackets.right:getHeight() / 2}})
  end
  GAME.gfx_q:push({love.graphics.draw, {themes[config.theme].images.IMG_players[1], stage_button.x + stage_button.width / 2 - stage_dims[1] / 2 - 12, stage_button.y + stage_button.height / 2, 0, 1, 1, 0, themes[config.theme].images.IMG_players[1]:getHeight() / 2}})
  
  -- TODO: cache text
  local font = love.graphics.newFont(9)
  local text = love.graphics.newText(font, display_name)
  GAME.gfx_q:push({love.graphics.draw, {text, math.floor(stage_button.x + stage_button.width / 2), stage_button.y + stage_dims[2] + 20, 0, 1, 1, math.floor(text:getWidth() / 2), 0}})
  GAME.gfx_q:push({love.graphics.draw, {text, math.floor(stage_button.x + stage_button.width / 2 + 1), stage_button.y + stage_dims[2] + 20, 0, 1, 1, math.floor(text:getWidth() / 2), 0}})
end

-- Draw the players current character, player number etc
function CharacterSelect:drawPlayerInfo()
  local x, y = gridToScreen(1, 0)
  local character_img = config.character == "__RandomCharacter" and themes[config.theme].images.IMG_random_character or characters[self.cursor_data[1].state.character].images.icon
  local scale = TILE_SIZE / character_img:getWidth()
  
  GAME.gfx_q:push({love.graphics.draw, {character_img, x, y, 0, scale, scale, 0, 0}})
  GAME.gfx_q:push({love.graphics.setColor, {234/255, 234/255, 234/255, 1}})
  GAME.gfx_q:push({love.graphics.rectangle, {"line", x, y, TILE_SIZE, TILE_SIZE}})
  GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})

  if characters[self.cursor_data[1].state.character] and not characters[self.cursor_data[1].state.character].fully_loaded then
    local loading_img = themes[config.theme].images.IMG_loading
    GAME.gfx_q:push({love.graphics.draw, {themes[config.theme].images.IMG_loading, x + .5 * TILE_SIZE, y + .5 * TILE_SIZE, 0, 1, 1, loading_img:getWidth() / 2, loading_img:getHeight() / 2}})
  elseif self.cursor_data[1].state.wants_ready then
    local ready_img = themes[config.theme].images.IMG_ready
    GAME.gfx_q:push({love.graphics.draw, {ready_img, x + .5 * TILE_SIZE, y + .5 * TILE_SIZE, 0, 1, 1, ready_img:getWidth() / 2, ready_img:getHeight() / 2}})
  end

  local player_img = themes[config.theme].images.IMG_players[1]
  scale = 20 / player_img:getHeight()
  GAME.gfx_q:push({love.graphics.draw, {player_img, x + .3 * TILE_SIZE, y + .75 * TILE_SIZE, 0, scale, scale, player_img:getWidth(), 0}})

  local level_img = themes[config.theme].images.IMG_levels[self.level_slider.value]
  scale = 20 / level_img:getHeight()
  GAME.gfx_q:push({love.graphics.draw, {level_img, x + .75 * TILE_SIZE, y + .75 * TILE_SIZE, 0, scale, scale, 0, 0}})
  
  GAME.gfx_q:push({love.graphics.setColor, {0, 0, 0, 1}})
  GAME.gfx_q:push({love.graphics.draw, {self.player_name_text, x + .5 * TILE_SIZE + 1, y + 1, 0, 1, 1, self.player_name_text:getWidth() / 2, 0}})
  GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
  GAME.gfx_q:push({love.graphics.draw, {self.player_name_text, x + .5 * TILE_SIZE, y, 0, 1, 1, self.player_name_text:getWidth() / 2, 0}})
end

function CharacterSelect:drawLevelSelector()
  local x_offset
  local level_button = self.buttons.level_select.enable
  if self.level_slider.isEnabled then
    x_offset = level_button.width / 2 - self.level_slider.tickLength * 7.6
    GAME.gfx_q:push({love.graphics.draw, {brackets.left, level_button.x + level_button.width / 2 - self.level_slider.tickLength * 6.6, level_button.y + TILE_SIZE / 2, 0, 1, 1, 0, brackets.left:getHeight() / 2}})
    GAME.gfx_q:push({love.graphics.draw, {brackets.right, level_button.x + level_button.width / 2 + self.level_slider.tickLength * 6.6, level_button.y + TILE_SIZE / 2, 0, 1, 1, brackets.right:getWidth(), brackets.right:getHeight() / 2}})
  else
    x_offset = level_button.width / 2 - self.level_slider.tickLength * 6.6
  end
  GAME.gfx_q:push({love.graphics.draw, {themes[config.theme].images.IMG_players[1], level_button.x + x_offset, level_button.y + TILE_SIZE / 2, 0, 1, 1, 0, themes[config.theme].images.IMG_players[1]:getHeight() / 2}})
end

function CharacterSelect:update()
  self:drawStage()
  self:drawLevelSelector()
  self:drawPanelsSelector()
  self:drawPlayerInfo()
  self:drawCursor(self.cursor_pos.x, self.cursor_pos.y)
  
  -- Draw the current score and record
  self:customDraw()
  
  -- Draw the player information buttons
  assert(GAME.battleRoom, "need battle room")
  assert(my_player_number and (my_player_number == 1 or my_player_number == 2), "need number")
  
  local playerNumberWaiting = GAME.input.playerNumberWaitingForInputConfiguration()
  if playerNumberWaiting then
    gprintf(loc("player_press_key", playerNumberWaiting), 0, 30, canvas_width, "center")
  end

  -- Draw an indicator that there are more character pages
  if self.num_character_pages > 1 then
    gprintf(loc("page") .. " " .. self.current_page .. "/" .. self.num_character_pages, 0, 660, canvas_width, "center")
  end

  character_loader_update()
  stage_loader_update()
  refresh_loaded_and_ready(self.cursor_data[1].state, self.cursor_data[2] and self.cursor_data[2].state or nil)

  if input:isPressedWithRepeat("Raise1", .25, .05) then
    self.buttons.page_select.left.onClick()
  end
  
  if input:isPressedWithRepeat("Raise2", .25, .05) then
    self.buttons.page_select.right.onClick()
  end
  
  if input:isPressedWithRepeat("Up", .25, .05) then
    if not (self.level_slider.isEnabled or self.buttons.stage_select.left.isEnabled or self.buttons.panels_select.left.isEnabled) then
      self.cursor_pos.y = (self.cursor_pos.y - 2) % MAX_ROWS + 1
      play_optional_sfx(themes[config.theme].sounds.menu_move)
    end
  end
  
  if input:isPressedWithRepeat("Down", .25, .05) then
    if not (self.level_slider.isEnabled or self.buttons.stage_select.left.isEnabled or self.buttons.panels_select.left.isEnabled) then
      self.cursor_pos.y = self.cursor_pos.y % MAX_ROWS + 1
      play_optional_sfx(themes[config.theme].sounds.menu_move)
    end
  end
  
  if input:isPressedWithRepeat("Left", .25, .05) then
    if self.level_slider.isEnabled then
      self.level_slider:setValue(self.level_slider.value - 1)
    elseif self.buttons.stage_select.left.isEnabled then
      self.buttons.stage_select.left.onClick()
    elseif self.buttons.panels_select.left.isEnabled then
      self.buttons.panels_select.left.onClick()
    else
      local x = self.cursor_pos.x
      local y = self.cursor_pos.y
      local width = 1
      if self.button_grid[self.cursor_pos.y][self.cursor_pos.x] then
        x, y, width = extractButtonInfo(self.button_grid[self.cursor_pos.y][self.cursor_pos.x])
      end
      self.cursor_pos.x = x
      self.cursor_pos.x = (self.cursor_pos.x - 2) % MAX_COLS + 1
      play_optional_sfx(themes[config.theme].sounds.menu_move)
    end
  end
  
  if input:isPressedWithRepeat("Right", .25, .05) then
    if self.level_slider.isEnabled then
      self.level_slider:setValue(self.level_slider.value + 1)
    elseif self.buttons.stage_select.right.isEnabled then
      self.buttons.stage_select.right.onClick()
    elseif self.buttons.panels_select.right.isEnabled then
      self.buttons.panels_select.right.onClick()
    else
      local x = self.cursor_pos.x
      local y = self.cursor_pos.y
      local width = 1
      if self.button_grid[self.cursor_pos.y][self.cursor_pos.x] then
        x, y, width = extractButtonInfo(self.button_grid[self.cursor_pos.y][self.cursor_pos.x])
      end
      self.cursor_pos.x = x + width - 1
      self.cursor_pos.x = self.cursor_pos.x % MAX_COLS + 1
      play_optional_sfx(themes[config.theme].sounds.menu_move)
    end
  end
  
  if input.isDown["Swap1"] or input.isDown["Start"] then
    if self.level_slider.isEnabled or self.buttons.stage_select.left.isEnabled or self.buttons.panels_select.left.isEnabled then
      self:moveCursor(self.cursor_pos.x, self.cursor_pos.y)
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
    else
      self.button_grid[self.cursor_pos.y][self.cursor_pos.x].onClick()
      local x, y, width = extractButtonInfo(self.button_grid[self.cursor_pos.y][self.cursor_pos.x])
      if width == 1 and not (self.cursor_pos.x == button_info.leave.x and self.cursor_pos.y == button_info.leave.y) then
        self.cursor_pos.x = button_info.ready.x
        self.cursor_pos.y = button_info.ready.y
      end
    end
  end
  
  if input.isDown["Swap2"] then
    if self.cursor_pos.x == button_info.leave.x and self.cursor_pos.y == button_info.leave.y then
      scene_manager:switchScene("main_menu")
    else
      self:moveCursor(button_info.leave.x, button_info.leave.y)
    end
  end
  -- update config, does not redefine it
  config.stage = self.cursor_data[1].state.stage_is_random and self.cursor_data[1].state.stage_is_random or self.cursor_data[1].state.stage
  config.panels = self.cursor_data[1].state.panels_dir
end

function CharacterSelect:unload()
  for _, button_group in pairs(self.buttons) do
    if button_group.TYPE == "Button" then
      button_group:setVisibility(false)
    else
      for _, button in pairs(button_group) do
        button:setVisibility(false)
      end
    end
  end
  self.level_slider:setVisibility(false)
  if themes[config.theme].musics.select_screen then
    stop_the_music()
  end
end

return CharacterSelect