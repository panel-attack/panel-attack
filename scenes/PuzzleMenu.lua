local Scene = require("scenes.Scene")
local logger = require("logger")
local TextButton = require("ui.TextButton")
local Menu = require("ui.Menu")
local MenuItem = require("ui.MenuItem")
local ButtonGroup = require("ui.ButtonGroup")
local LevelSlider = require("ui.LevelSlider")
local Label = require("ui.Label")
local sceneManager = require("scenes.sceneManager")
local StackPanel = require("ui.StackPanel")
local input = require("inputManager")
local GraphicsUtil = require("graphics_util")
local consts = require("consts")
local class = require("class")
local GameModes = require("GameModes")

--@module puzzleMenu
-- Scene for the puzzle selection menu
local PuzzleMenu = class(
  function (self, sceneParams)
    -- set in load
    self.levelSlider = nil
    self.randomColorButtons = nil
    self.menu = nil
    self.puzzleLabel = nil

    self:load(sceneParams)
  end,
  Scene
)

PuzzleMenu.name = "PuzzleMenu"
sceneManager:addScene(PuzzleMenu)

local BUTTON_WIDTH = 60
local BUTTON_HEIGHT = 25

function PuzzleMenu:startGame(puzzleSet)
  if config.puzzle_level ~= self.levelSlider.value or config.puzzle_randomColors ~= self.randomColorsButtons.value then
    logger.debug("saving settings...")
    write_conf_file()
  end

  if config.puzzle_randomColors or config.puzzle_randomFlipped then
    puzzleSet = deepcpy(puzzleSet)

    for _, puzzle in pairs(puzzleSet.puzzles) do
      if config.puzzle_randomColors then
        puzzle.stack = Puzzle.randomizeColorsInPuzzleString(puzzle.stack)
      end
      if config.puzzle_randomFlipped then
        if math.random(2) == 1 then
          puzzle.stack = puzzle:horizontallyFlipPuzzleString()
        end
      end
    end
  end

  SoundController:playSfx(themes[config.theme].sounds.menu_validate)

  GAME.localPlayer:setPuzzleSet(puzzleSet)
  GAME.localPlayer:setWantsReady(true)
end

function PuzzleMenu:exit()
  SoundController:playSfx(themes[config.theme].sounds.menu_validate)
  GAME.battleRoom:shutdown()
  sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
end

function PuzzleMenu:load(sceneParams)
  local tickLength = 16
  self.levelSlider = LevelSlider({
      tickLength = tickLength,
      value = config.puzzle_level or 5,
      onValueChange = function(s)
        SoundController:playSfx(themes[config.theme].sounds.menu_move)
        config.puzzle_level = s.value
        GAME.localPlayer:setLevel(s.value)
      end
    })

  self.randomColorsButtons = ButtonGroup(
    {
      buttons = {
        TextButton({label = Label({text = "op_off"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
        TextButton({label = Label({text = "op_on"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
      },
      values = {false, true},
      selectedIndex = config.puzzle_randomColors and 2 or 1,
      onChange = function(value)
        SoundController:playSfx(themes[config.theme].sounds.menu_move)
        config.puzzle_randomColors = value
      end
    }
  )
  
  self.randomlyFlipPuzzleButtons = ButtonGroup(
    {
      buttons = {
        TextButton({label = Label({text = "op_off"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
        TextButton({label = Label({text = "op_on"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
      },
      values = {false, true},
      selectedIndex = config.puzzle_randomFlipped and 2 or 1,
      onChange = function(value)
        SoundController:playSfx(themes[config.theme].sounds.menu_move)
        config.puzzle_randomFlipped = value
      end
    }
  )
  
  local menuOptions = {
    MenuItem.createSliderMenuItem("level", nil, nil, self.levelSlider),
    MenuItem.createToggleButtonGroupMenuItem("randomColors", nil, nil, self.randomColorsButtons),
    MenuItem.createToggleButtonGroupMenuItem("randomHorizontalFlipped", nil, nil, self.randomlyFlipPuzzleButtons),
  }

  for puzzleSetName, puzzleSet in pairsSortedByKeys(GAME.puzzleSets) do
    menuOptions[#menuOptions + 1] = MenuItem.createButtonMenuItem(puzzleSetName, nil, false, function() self:startGame(puzzleSet) end)
  end
  menuOptions[#menuOptions + 1] = MenuItem.createButtonMenuItem("back", nil, nil, self.exit)
  
  self.menu = Menu.createCenteredMenu(menuOptions)

  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  self.puzzleLabel = Label({text = "pz_puzzles", x = x - 10, y = y - 40})
  
  self.uiRoot:addChild(self.menu)
  self.uiRoot:addChild(self.puzzleLabel)

  SoundController:playMusic(themes[config.theme].stageTracks.main)
end

function PuzzleMenu:update(dt)
  self.menu:update(dt)
end

function PuzzleMenu:draw()
  themes[config.theme].images.bg_main:draw()
  self.uiRoot:draw()
end

return PuzzleMenu