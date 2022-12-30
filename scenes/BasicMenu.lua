local class = require("class")
local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local LevelSlider = require("ui.LevelSlider")
local sceneManager = require("scenes.sceneManager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local save = require("save")

--@module BasicMenu
local BasicMenu = class(
  function (self, name, options)
    self.name = name
    self.game_mode = options.game_mode
    self.game_scene = options.game_scene
  end,
  Scene
)

local selected_id = 1

local speed_slider = Slider({
    min = 1, 
    max = 99, 
    value = GAME.config.endless_speed or 1, 
    isVisible = false
})

local font = love.graphics.getFont() 
local difficulty_buttons = ButtonGroup(
    {
      buttons = {
        Button({label = "easy", width = 60, height = 25}),
        Button({label = "normal", width = 60, height = 25}),
        Button({label = "hard", width = 60, height = 25}),
        -- TODO: localize "EX Mode"
        Button({label = "EX Mode", translate = false}),
      },
      values = {1, 2, 3, 4},
      selected_index = GAME.config.endless_difficulty or 1,
      onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
    }
)

function BasicMenu:startGame()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  
  if config.endless_speed ~= speed_slider.value or config.endless_difficulty ~= difficulty_buttons.value then
    config.endless_speed = speed_slider.value
    config.endless_difficulty = difficulty_buttons.value
    --gprint("saving settings...", unpack(main_menu_screen_pos))
    --wait()
    save.write_conf_file()
  end
  
  GAME.match = Match(self.game_mode)

  current_stage = config.stage
  if current_stage == random_stage_special_value then
    current_stage = nil
  end

  if self.type_buttons.value == "Classic" then
    GAME.match.P1 = Stack{which=1, match=GAME.match, is_local=true, panels_dir=config.panels, speed=speed_slider.value, difficulty=difficulty_buttons.value, character=config.character}
  else
    GAME.match.P1 = Stack{which=1, match=GAME.match, is_local=true, panels_dir=config.panels, level=self.level_slider.value, character=config.character}
  end
  GAME.match.P1:wait_for_random_character()
  GAME.match.P1.do_countdown = config.ready_countdown_1P or false
  GAME.match.P2 = nil

  GAME.match.P1:starting_state()
  
  sceneManager:switchToScene(self.game_scene)
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  sceneManager:switchToScene("mainMenu")
end

function BasicMenu:init()
  sceneManager:addScene(self)
  
  local tickLength = 16
  self.level_slider = LevelSlider({
      tickLength = tickLength,
      onValueChange = function(s)
        play_optional_sfx(themes[config.theme].sounds.menu_move)
      end
    })
  
  self.type_buttons = ButtonGroup(
    {
      buttons = {
        Button({label = "endless_classic", onClick = function()
              self.modern_menu:setVisibility(false)
              self.classic_menu:setVisibility(true)
              end, width = 60, height = 25}),
        Button({label = "endless_modern", onClick = function()
              self.classic_menu:setVisibility(false) 
              self.modern_menu:setVisibility(true)
              end, width = 60, height = 25}),
      },
      values = {"Classic", "Modern"},
      selected_index = 2,
      onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
    }
  )
  
  local modern_menu_options = {
    {Label({label = "endless_type"}), self.type_buttons},
    {Label({label = "level"}), self.level_slider},
    {Button({label = "go_", onClick = function() self:startGame() end})},
    {Button({label = "back", onClick = exitMenu})},
  }
  
  local classic_menu_options = {
    modern_menu_options[1],
    {Label({label = "speed", isVisible = false}), speed_slider},
    {Label({label = "difficulty", isVisible = false}), difficulty_buttons},
    {Button({label = "go_", onClick = function() self:startGame() end})},
    {Button({label = "back", onClick = exitMenu})},
  }
  
  local x, y = unpack(main_menu_screen_pos)
  y = y + 100
  self.classic_menu = Menu({menuItems = classic_menu_options, x = x, y = y})
  self.modern_menu = Menu({menuItems = modern_menu_options, x = x, y = y})
  self.classic_menu:setVisibility(false)
  self.modern_menu:setVisibility(false)
end

function BasicMenu:load()
  self.classic_menu:updateLabel()
  self.modern_menu:updateLabel()
  
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

function BasicMenu:drawBackground() 
  themes[config.theme].images.bg_main:draw() 
end

function BasicMenu:update()
  if self.type_buttons.value == "Classic" then
    local lastScore, record = unpack(self:getScores(difficulty_buttons.value))
  
    local xPosition1 = 520
    local xPosition2 = xPosition1 + 150
    local yPosition = 270
  
    draw_pixel_font("last lines", themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition, 0.5, 1.0)
    draw_pixel_font(lastScore,    themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition + 24, 0.5, 1.0)
    draw_pixel_font("record",     themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition, 0.5, 1.0)
    draw_pixel_font(record,       themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition + 24, 0.5, 1.0)
  
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
  stop_the_music()
end

return BasicMenu