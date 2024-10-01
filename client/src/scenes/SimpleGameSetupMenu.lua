local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local TextButton = require("client.src.ui.TextButton")
local Slider = require("client.src.ui.Slider")
local Label = require("client.src.ui.Label")
local LevelSlider = require("client.src.ui.LevelSlider")
local Menu = require("client.src.ui.Menu")
local MenuItem = require("client.src.ui.MenuItem")
local ButtonGroup = require("client.src.ui.ButtonGroup")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local GameModes = require("common.engine.GameModes")

--@module SimpleGameSetupMenu
-- A Scene that contains menus for basic game configuation (speed, difficulty, level, etc.)
local SimpleGameSetupMenu = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_main
    self.music = "select_screen"
    self.fallbackMusic = "main"

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
function SimpleGameSetupMenu:getScores(difficulty) return {"", ""} end

-- end abstract functions

local BUTTON_WIDTH = 60
local BUTTON_HEIGHT = 25

function SimpleGameSetupMenu:startGame()
  GAME.theme:playValidationSfx()
  GAME.localPlayer:setWantsReady(true)
end

function SimpleGameSetupMenu:exit()
  GAME.theme:playCancelSfx()
  GAME.battleRoom:shutdown()
  GAME.navigationStack:pop()
end

function SimpleGameSetupMenu:load(sceneParams)
  self.speedSlider = Slider({
    min = 1,
    max = 99,
    value = GAME.config.endless_speed or 1,
    onValueChange = function(slider)
      config.endless_speed = slider.value
    end
  })

  self.difficultyButtons = ButtonGroup(
      {
        buttons = {
          TextButton({label = Label({text = "easy"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
          TextButton({label = Label({text = "normal"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
          TextButton({label = Label({text = "hard"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
          -- TODO: localize "EX Mode"
          TextButton({label = Label({text = "EX Mode"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT, translate = false}),
        },
        values = {1, 2, 3, 4},
        selectedIndex = GAME.config.endless_difficulty or 1,
        onChange = function(group, value)
          GAME.theme:playMoveSfx()
          config.endless_difficulty = value
        end
      }
  )

  local tickLength = 16
  self.levelSlider = LevelSlider({
      tickLength = tickLength,
      value = config.endless_level or 5,
      onValueChange = function(s)
        GAME.theme:playMoveSfx()
        GAME.localPlayer:setLevel(s.value)
        config.level = s.value
      end
    })
  
  self.typeButtons = ButtonGroup(
    {
      buttons = {
        TextButton({label = Label({text = "endless_classic"}), onClick = function(selfElement, inputSource, holdTime)
              self.modernMenu:detach()
              self.uiRoot:addChild(self.classicMenu)
              end, width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
        TextButton({label = Label({text = "endless_modern"}), onClick = function(selfElement, inputSource, holdTime)
              self.classicMenu:detach()
              self.uiRoot:addChild(self.modernMenu)
              end, width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
      },
      values = {"Classic", "Modern"},
      selectedIndex = config.endless_level and 2 or 1,
      onChange = function(group, value)
        GAME.theme:playMoveSfx()
        if value == "Classic" then
          GAME.localPlayer:setStyle(GameModes.Styles.CLASSIC)
          GAME.localPlayer:setDifficulty(self.difficultyButtons.value)
          GAME.localPlayer:setSpeed(config.endless_speed)
          config.endless_level = nil
        elseif value == "Modern" then
          GAME.localPlayer:setStyle(GameModes.Styles.MODERN)
          GAME.localPlayer:setLevel(self.levelSlider.value)
          config.endless_level = self.levelSlider.value
        end
      end
    }
  )
  
  local modernMenuOptions = {
    MenuItem.createToggleButtonGroupMenuItem("endless_type", nil, nil, self.typeButtons),
    MenuItem.createSliderMenuItem("level", nil, nil, self.levelSlider),
    MenuItem.createButtonMenuItem("go_", nil, nil, function() self:startGame() end),
    MenuItem.createButtonMenuItem("back", nil, nil, self.exit)
  }
  
  local classicMenuOptions = {
    modernMenuOptions[1],
    MenuItem.createSliderMenuItem("speed", nil, nil, self.speedSlider),
    MenuItem.createToggleButtonGroupMenuItem("difficulty", nil, nil, self.difficultyButtons),
    MenuItem.createButtonMenuItem("go_", nil, nil, function() self:startGame() end),
    MenuItem.createButtonMenuItem("back", nil, nil, self.exit)
  }

  -- the go buttons are game starting ones, therefore they shouldn't react to the default config
  -- but only key configs instead
  local function receiveInputs(menuItem, input)
    if input.isDown.Swap1 or input.isDown.Start then
      menuItem.textButton:onClick(input)
    end
  end
  
  modernMenuOptions[3].receiveInputs = receiveInputs
  classicMenuOptions[4].receiveInputs = receiveInputs

  self.classicMenu = Menu.createCenteredMenu(classicMenuOptions)
  self.modernMenu = Menu.createCenteredMenu(modernMenuOptions)
  if self.typeButtons.value == "Classic" then
    self.uiRoot:addChild(self.classicMenu)
  else
    self.uiRoot:addChild(self.modernMenu)
  end
end

function SimpleGameSetupMenu:update(dt)
  self.backgroundImg:update(dt)

  if self.typeButtons.value == "Classic" then
    self.classicMenu:receiveInputs()
  else
    self.modernMenu:receiveInputs()
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

    GraphicsUtil.drawPixelFont("last score", themes[config.theme].fontMaps.pixelFontBlue, xPosition1, yPosition, 0.5, 1.0, nil, nil)
    GraphicsUtil.drawPixelFont(lastScore, themes[config.theme].fontMaps.pixelFontBlue, xPosition1, yPosition + 24, 0.5, 1.0, nil, nil)
    GraphicsUtil.drawPixelFont("record", themes[config.theme].fontMaps.pixelFontBlue, xPosition2, yPosition, 0.5, 1.0, nil, nil)
    GraphicsUtil.drawPixelFont(record, themes[config.theme].fontMaps.pixelFontBlue, xPosition2, yPosition + 24, 0.5, 1.0, nil, nil)
  end
  self.uiRoot:draw()
end

return SimpleGameSetupMenu