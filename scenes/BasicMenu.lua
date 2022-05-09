local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local LevelSlider = require("ui.LevelSlider")
local scene_manager = require("scenes.scene_manager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")

--@module BasicMenu
local BasicMenu = class(
  function (self, name, options)
    self.name = name
    self.game_mode = options.game_mode
  end,
  Scene
)

local selected_id = 1

local speed_slider = Slider({
    min = 1, 
    max = 99, 
    value = GAME.config.endless_speed or 1, 
    is_visible = false
})

local font = love.graphics.getFont() 
local difficulty_buttons = ButtonGroup(
    {
      Button({text = love.graphics.newText(font, loc("easy")), width = 60, height = 25}),
      Button({text = love.graphics.newText(font, loc("normal")), width = 60, height = 25}),
      Button({text = love.graphics.newText(font, loc("hard")), width = 60, height = 25}),
      -- TODO: localize "EX Mode"
      Button({text = love.graphics.newText(font, "EX Mode")}),
    },
    {1, 2, 3, 4},
    {
      selected_index = GAME.config.endless_difficulty or 1,
      onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
    }
)

function BasicMenu:startGame()
  GAME.match = Match(self.game_mode)

  current_stage = config.stage
  if current_stage == random_stage_special_value then
    current_stage = nil
  end
  commonGameSetup()

  if self.type_buttons.value == "Classic" then
    P1 = Stack{which=1, match=GAME.match, is_local=true, panels_dir=config.panels, speed=speed_slider.value, difficulty=difficulty_buttons.value, character=config.character}
  else
    P1 = Stack{which=1, match=GAME.match, is_local=true, panels_dir=config.panels, level=self.level_slider.value, character=config.character}
  end
  GAME.match.P1 = P1
  P1:wait_for_random_character()
  P1.do_countdown = config.ready_countdown_1P or false
  P2 = nil

  replay = createNewReplay(GAME.match)

  P1:starting_state()
  
  if config.endless_speed ~= speed_slider.value or config.endless_difficulty ~= difficulty_buttons.value then
    config.endless_speed = speed_slider.value
    config.endless_difficulty = difficulty_buttons.value
    --gprint("saving settings...", unpack(main_menu_screen_pos))
    --wait()
    write_conf_file()
  end
  stop_the_music()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene(nil)
  
  local abort_game_function = nil
  if self.game_mode == "endless" then
    abort_game_function = main_endless_select
  else
    abort_game_function = main_timeattack_select
  end
  
  local function processGameResults(gameResult) 
    local extraPath, extraFilename
    local stack = P1
    if stack.level == nil then
      if GAME.match.mode == "endless" then
        GAME.scores:saveEndlessScoreForLevel(P1.score, P1.difficulty)
        extraPath = "Endless"
        extraFilename = "Spd" .. stack.speed .. "-Dif" .. stack.difficulty .. "-endless"
      elseif GAME.match.mode == "time" then
        GAME.scores:saveTimeAttack1PScoreForLevel(P1.score, P1.difficulty)
        extraPath = "Time Attack"
        extraFilename = "Spd" .. stack.speed .. "-Dif" .. stack.difficulty .. "-timeattack"
      end
      finalizeAndWriteReplay(extraPath, extraFilename)
    end

    return {game_over_transition, {nextFunction, nil, P1:pick_win_sfx()}}
  end
  
  func = runMainGameLoop
  arg = {--[[update]] function() end, --[[variableStep]] function() end, abort_game_function, processGameResults}
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene("main_menu")
end

function BasicMenu:init()
  scene_manager:addScene(self)
  
  local tick_length = 16
  self.level_slider = LevelSlider({
      tick_length = tick_length,
      onValueChange = function(s)
        play_optional_sfx(themes[config.theme].sounds.menu_move)
      end
    })
  
  self.type_buttons = ButtonGroup(
    {
      Button({text = love.graphics.newText(font, loc("endless_classic")), onClick = function()
            self.modern_menu:setVisibility(false)
            self.classic_menu:setVisibility(true)
            end, width = 60, height = 25}),
      Button({text = love.graphics.newText(font, loc("endless_modern")), onClick = function()
            self.classic_menu:setVisibility(false) 
            self.modern_menu:setVisibility(true)
            end, width = 60, height = 25}),
    },
    {"Classic", "Modern"},
    {
      selected_index = 2,
      onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
    }
  )
  
  local modern_menu_options = {
    {Label({text = love.graphics.newText(font, loc("endless_type")), is_visible = false}), self.type_buttons},
    {Label({text = love.graphics.newText(font, loc("level")), is_visible = false}), self.level_slider},
    {Button({text = love.graphics.newText(font, loc("go_")), onClick = function() self:startGame() end, is_visible = false})},
    {Button({text = love.graphics.newText(font, loc("back")), onClick = exitMenu, is_visible = false})},
  }
  
  local classic_menu_options = {
    modern_menu_options[1],
    {Label({text = love.graphics.newText(font, loc("speed")), is_visible = false}), speed_slider},
    {Label({text = love.graphics.newText(font, loc("difficulty")), is_visible = false}), difficulty_buttons},
    {Button({text = love.graphics.newText(font, loc("go_")), onClick = function() self:startGame() end, is_visible = false})},
    {Button({text = love.graphics.newText(font, loc("back")), onClick = exitMenu, is_visible = false})},
  }
  
  local x, y = unpack(main_menu_screen_pos)
  y = y + 100
  self.classic_menu = Menu(classic_menu_options, {x = x, y = y})
  self.modern_menu = Menu(modern_menu_options, {x = x, y = y})
  self.classic_menu:setVisibility(false)
  self.modern_menu:setVisibility(false)
end

function BasicMenu:load()
  GAME.backgroundImage = themes[config.theme].images.bg_main
  reset_filters()
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end

  for i, button in ipairs(difficulty_buttons.buttons) do
    button.width = 60
    button.height = 25
  end
  
  if self.type_buttons.value == "Classic" then
    self.classic_menu:setVisibility(true)
  else
    self.modern_menu:setVisibility(true)
  end
end

function BasicMenu:update()  
  if self.type_buttons.value == "Classic" then
    local lastScore, record = unpack(self:getScores(difficulty_buttons.value))
  
    local xPosition1 = 520
    local xPosition2 = xPosition1 + 150
    local yPosition = 270
  
    draw_pixel_font("last score", themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition1, yPosition, 0.5, 1.0)
    draw_pixel_font(lastScore, themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition1, yPosition + 24, 0.5, 1.0)
    draw_pixel_font("record", themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition2, yPosition, 0.5, 1.0)
    draw_pixel_font(record, themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition2, yPosition + 24, 0.5, 1.0)
  
    self.classic_menu:update()
    self.classic_menu:draw()
  else
    self.modern_menu:update()
    self.modern_menu:draw()
  end
  
end

function BasicMenu:unload()  
  if self.type_buttons.value == "Classic" then
    self.classic_menu:setVisibility(false)
  else
    self.modern_menu:setVisibility(false)
  end
end

return BasicMenu