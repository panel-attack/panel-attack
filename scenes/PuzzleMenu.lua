local Scene = require("scenes.Scene")
local logger = require("logger")
local Button = require("ui.Button")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local LevelSlider = require("ui.LevelSlider")
local Label = require("ui.Label")
local sceneManager = require("scenes.sceneManager")
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

    self:load(sceneParams)
  end,
  Scene
)

PuzzleMenu.name = "PuzzleMenu"
sceneManager:addScene(PuzzleMenu)

local BUTTON_WIDTH = 60
local BUTTON_HEIGHT = 25
local font = GraphicsUtil.getGlobalFont()

function PuzzleMenu:startGame(puzzleSet)
  if config.puzzle_level ~= self.levelSlider.value or config.puzzle_randomColors ~= self.randomColorsButtons.value then
    config.puzzle_level = self.levelSlider.value
    config.puzzle_randomColors = self.randomColorsButtons.value
    logger.debug("saving settings...")
    write_conf_file()
  end

  current_stage = StageLoader.resolveStageSelection(config.stage)

  if config.puzzle_randomColors or config.puzzle_randomFlipped then
    puzzleSet = deepcpy(puzzleSet)

    for _, puzzle in pairs(puzzleSet.puzzles) do
      if config.puzzle_randomColors then
        puzzle.stack = Puzzle.randomizeColorsInPuzzleString(puzzle.stack)
      end
      if config.puzzle_randomFlipped then
        if math.random(2) == 1 then
          puzzle.stack = Puzzle.horizontallyFlipPuzzleString(puzzle.stack)
        end
      end
    end
  end

  play_optional_sfx(themes[config.theme].sounds.menu_validate)

  GAME.localPlayer:setPuzzleSet(puzzleSet)
  GAME.localPlayer:setWantsReady(true)
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  GAME.battleRoom = nil
  sceneManager:switchToScene("MainMenu")
end

function PuzzleMenu:load()
  local tickLength = 16
  self.levelSlider = LevelSlider({
      tickLength = tickLength,
      value = config.puzzle_level or 5,
      onValueChange = function(s)
        play_optional_sfx(themes[config.theme].sounds.menu_move)
      end
    })
  
  self.randomColorsButtons = ButtonGroup(
    {
      buttons = {
        Button({label = "op_off", width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
        Button({label = "op_on", width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
      },
      values = {false, true},
      selectedIndex = config.puzzle_randomColors and 2 or 1,
      onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
    }
  )
  
  self.randomlyFlipPuzzleButtons = ButtonGroup(
    {
      buttons = {
        Button({label = "op_off", width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
        Button({label = "op_on", width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
      },
      values = {false, true},
      selectedIndex = config.puzzle_randomFlipped and 2 or 1,
      onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
    }
  )
  
  local menuOptions = {
    {Label({label = "level", isVisible = false}), self.levelSlider},
    {Label({label = "randomColors", isVisible = false}), self.randomColorsButtons},
    {Label({label = "randomHorizontalFlipped", isVisible = false}), self.randomlyFlipPuzzleButtons}
  }

  for puzzleSetName, puzzleSet in pairsSortedByKeys(GAME.puzzleSets) do
    menuOptions[#menuOptions + 1] = {Button({label = puzzleSetName, translate = false, onClick = function() self:startGame(puzzleSet) end})}
  end
  menuOptions[#menuOptions + 1] = {Button({label = "back", onClick = exitMenu})}
  
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  y = y + 20
  self.menu = Menu({
    x = x,
    y = y,
    menuItems = menuOptions,
    maxHeight = themes[config.theme].main_menu_max_height
  })
  
  if themes[config.theme].musics.main then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  reset_filters()

  if not GAME.battleRoom then
    GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.ONE_PLAYER_PUZZLE)
  end
end

function PuzzleMenu:drawBackground()
  themes[config.theme].images.bg_main:draw()
end

function PuzzleMenu:update()
  gprint(loc("pz_puzzles"), unpack(themes[config.theme].main_menu_screen_pos))
      
  self.menu:update()
  self.menu:draw()

  if GAME.battleRoom then
    GAME.battleRoom:update()
  end
end

function PuzzleMenu:unload()
  self.menu:setVisibility(false)
  stop_the_music()
end

return PuzzleMenu