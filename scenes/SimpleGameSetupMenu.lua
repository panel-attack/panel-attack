local class = require("class")
local Scene = require("scenes.Scene")
local TextButton = require("ui.TextButton")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local LevelSlider = require("ui.LevelSlider")
local sceneManager = require("scenes.sceneManager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local save = require("save")
local GraphicsUtil = require("graphics_util")
local GameModes = require("GameModes")

--@module SimpleGameSetupMenu
-- A Scene that contains menus for basic game configuation (speed, difficulty, level, etc.)
local SimpleGameSetupMenu = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_main

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
  GAME.localPlayer:setSpeed(self.speedSlider.value)
  GAME.localPlayer:setDifficulty(self.difficultyButtons.value)
  if self.typeButtons.value == "Classic" then
    GAME.localPlayer:setStyle(GameModes.Styles.CLASSIC)
  else
    GAME.localPlayer:setStyle(GameModes.Styles.MODERN)
  end
  write_conf_file()
  GAME.localPlayer:setWantsReady(true)
end

function SimpleGameSetupMenu:exit()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  GAME.battleRoom:shutdown()
  sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
end

function SimpleGameSetupMenu:load(sceneParams)
  self.speedSlider = Slider({
    min = 1, 
    max = 99, 
    value = GAME.config.endless_speed or 1, 
    isVisible = false
  })

  self.difficultyButtons = ButtonGroup(
      {
        buttons = {
          TextButton({label = Label({text = "easy"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
          TextButton({label = Label({text = "normal"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
          TextButton({label = Label({text = "hard"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
          -- TODO: localize "EX Mode"
          TextButton({label = Label({text = "EX Mode"}), translate = false}),
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
        TextButton({label = Label({text = "endless_classic"}), onClick = function()
              self.uiRoot:detach(self.modernMenu)
              self.uiRoot:addChild(self.classicMenu)
              end, width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
        TextButton({label = Label({text = "endless_modern"}), onClick = function()
          self.uiRoot:detach(self.classicMenu)
              self.uiRoot:addChild(self.modernMenu)
              end, width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
      },
      values = {"Classic", "Modern"},
      selectedIndex = config.endless_level and 2 or 1,
      onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
    }
  )
  
  local modernMenuOptions = {
    {Label({text = "endless_type"}), self.typeButtons},
    {Label({text = "level"}), self.levelSlider},
    {TextButton({label = Label({text = "go_"}), onClick = function() self:startGame() end})},
    {TextButton({label = Label({text = "back"}), onClick = self.exit})},
  }
  
  local classicMenuOptions = {
    modernMenuOptions[1],
    {Label({text = "speed", isVisible = false}), self.speedSlider},
    {Label({text = "difficulty", isVisible = false}), self.difficultyButtons},
    {TextButton({label = Label({text = "go_"}), onClick = function() self:startGame() end})},
    {TextButton({label = Label({text = "back"}), onClick = self.exit})},
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
    self.uiRoot:addChild(self.classicMenu)
  else
    self.uiRoot:addChild(self.modernMenu)
  end
  
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end

  for i, button in ipairs(self.difficultyButtons.buttons) do
    button.width = BUTTON_WIDTH
    button.height = BUTTON_HEIGHT
  end
end

function SimpleGameSetupMenu:update(dt)
  self.backgroundImg:update(dt)

  if self.typeButtons.value == "Classic" then
    self.classicMenu:update()
  else
    self.modernMenu:update()
  end
end

function SimpleGameSetupMenu:draw()
  self.backgroundImg:draw()

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

    self.classicMenu:draw()
  else
    self.modernMenu:draw()
  end
end

return SimpleGameSetupMenu