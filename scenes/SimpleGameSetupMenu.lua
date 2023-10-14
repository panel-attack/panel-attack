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
local GraphicsUtil = require("graphics_util")

--@module SimpleGameSetupMenu
-- A Scene that contains menus for basic game configuation (speed, difficulty, level, etc.)
local SimpleGameSetupMenu = class(
  function (self, sceneParams)
    -- must be set in child classes
    self.gameMode = nil
    self.gameScene = nil
    
    -- set in load
    self.speedSlider = nil
    self.difficultyButtons = nil
    self.typeButtons = nil
    self.levelSlider = nil
    self.gameMode = nil
    self.gameScene = nil
    self.modernMenu = nil
    self.classicMenu = nil
  end,
  Scene
)

-- begin abstract functions

-- returns the scores for the current game mode in the form {last score, record score}
function SimpleGameSetupMenu:getScores() return {"", ""} end

-- end abstract functions

local BUTTON_WIDTH = 60
local BUTTON_HEIGHT = 25

function SimpleGameSetupMenu:startGame()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  config.endless_speed = self.speedSlider.value
  config.endless_difficulty = self.difficultyButtons.value
  if self.typeButtons.value == "Classic" then
    config.endless_level = nil
  else
    config.endless_level = self.levelSlider.value
  end
  write_conf_file()
  GAME.match = Match(self.gameMode)
  current_stage = config.stage
  if current_stage == random_stage_special_value then
    current_stage = nil
  end
  if self.typeButtons.value == "Classic" then
    GAME.match:addPlayer(Stack{which=1, match=GAME.match, is_local=true, panels_dir=config.panels, speed=self.speedSlider.value, difficulty=self.difficultyButtons.value, character=config.character, inputMethod=config.inputMethod})
  else
    GAME.match:addPlayer(Stack{which=1, match=GAME.match, is_local=true, panels_dir=config.panels, level=self.levelSlider.value, character=config.character, inputMethod=config.inputMethod})
  end
  GAME.match.P1:wait_for_random_character()
  GAME.match.P1.do_countdown = config.ready_countdown_1P or false
  GAME.match.P1:starting_state()
  sceneManager:switchToScene(self.gameScene, {})
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  sceneManager:switchToScene("MainMenu")
end

function SimpleGameSetupMenu:load()
    self.speedSlider = Slider({
    min = 1, 
    max = 99, 
    value = GAME.config.endless_speed or 1, 
    isVisible = false
  })

  self.difficultyButtons = ButtonGroup(
      {
        buttons = {
          Button({label = "easy", width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
          Button({label = "normal", width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
          Button({label = "hard", width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
          -- TODO: localize "EX Mode"
          Button({label = "EX Mode", translate = false}),
        },
        values = {1, 2, 3, 4},
        selectedIndex = GAME.config.endless_difficulty or 1,
        onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
      }
  )
  
  local tickLength = 16
  self.levelSlider = LevelSlider({
      tickLength = tickLength,
      value = config.endless_level or 5,
      onValueChange = function(s)
        play_optional_sfx(themes[config.theme].sounds.menu_move)
      end
    })
  
  self.typeButtons = ButtonGroup(
    {
      buttons = {
        Button({label = "endless_classic", onClick = function()
              self.modernMenu:setVisibility(false)
              self.classicMenu:setVisibility(true)
              end, width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
        Button({label = "endless_modern", onClick = function()
              self.classicMenu:setVisibility(false) 
              self.modernMenu:setVisibility(true)
              end, width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
      },
      values = {"Classic", "Modern"},
      selectedIndex = config.endless_level and 2 or 1,
      onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
    }
  )
  
  local modernMenuOptions = {
    {Label({label = "endless_type"}), self.typeButtons},
    {Label({label = "level"}), self.levelSlider},
    {Button({label = "go_", onClick = function() self:startGame() end})},
    {Button({label = "back", onClick = exitMenu})},
  }
  
  local classicMenuOptions = {
    modernMenuOptions[1],
    {Label({label = "speed", isVisible = false}), self.speedSlider},
    {Label({label = "difficulty", isVisible = false}), self.difficultyButtons},
    {Button({label = "go_", onClick = function() self:startGame() end})},
    {Button({label = "back", onClick = exitMenu})},
  }
  
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  y = y + 100
  self.classicMenu = Menu({
    x = x,
    y = y,
    menuItems = classicMenuOptions, 
    maxHeight = themes[config.theme].main_menu_max_height
  })
  self.modernMenu = Menu({
    x = x,
    y = y,
    menuItems = modernMenuOptions,
    maxHeight = themes[config.theme].main_menu_max_height
  })
  if self.typeButtons.value == "Classic" then
    self.modernMenu:setVisibility(false)
    self.classicMenu:setVisibility(true)
  else
    self.classicMenu:setVisibility(false)
    self.modernMenu:setVisibility(true)
  end
  
  reset_filters()
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end

  for i, button in ipairs(self.difficultyButtons.buttons) do
    button.width = BUTTON_WIDTH
    button.height = BUTTON_HEIGHT
  end
end

function SimpleGameSetupMenu:drawBackground() 
  themes[config.theme].images.bg_main:draw() 
end

function SimpleGameSetupMenu:update()
  if self.typeButtons.value == "Classic" then
    local lastScore, record = unpack(self:getScores(self.difficultyButtons.value))
  
    local menu_x, menu_y = unpack(themes[config.theme].main_menu_screen_pos)
    local xPosition1 = menu_x
    local xPosition2 = xPosition1 + 150
    local yPosition = menu_y + 50
  
    local lastScoreLabelQuads = {}
    local lastScoreQuads = {}
    local recordLabelQuads = {}
    local recordQuads = {}
    draw_pixel_font("last score", themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition, 0.5, 1.0, nil, nil, lastScoreLabelQuads)
    draw_pixel_font(lastScore, themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition + 24, 0.5, 1.0, nil, nil, lastScoreQuads)
    draw_pixel_font("record", themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition, 0.5, 1.0, nil, nil, recordLabelQuads)
    draw_pixel_font(record, themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition + 24, 0.5, 1.0, nil, nil, recordQuads)
  
    self.classicMenu:update()
    self.classicMenu:draw()
  else
    self.modernMenu:update()
    self.modernMenu:draw()
  end
  
end

function SimpleGameSetupMenu:unload() 
  if self.typeButtons.value == "Classic" then
    self.classicMenu:setVisibility(false)
  else
    self.modernMenu:setVisibility(false)
  end
  stop_the_music()
end

return SimpleGameSetupMenu