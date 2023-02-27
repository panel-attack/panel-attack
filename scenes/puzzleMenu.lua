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

--@module puzzleMenu
local puzzleMenu = Scene("puzzleMenu")

local font = GraphicsUtil.getGlobalFont()
  
function puzzleMenu:startGame(puzzleSet)
  current_stage = config.stage
  if current_stage == random_stage_special_value then
    current_stage = nil
  end
  
  if config.puzzle_randomColors then
    puzzleSet = deepcpy(puzzleSet)

    for _, puzzle in pairs(puzzleSet.puzzles) do
      puzzle.stack = Puzzle.randomizeColorString(puzzle.stack)
    end
  end
  
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  sceneManager:switchToScene("puzzleGame", {puzzleSet = puzzleSet, puzzleIndex = 1})
  
  if config.puzzle_level ~= self.levelSlider.value or config.puzzle_randomColors ~= self.randomColorsButtons.value then
    config.puzzle_level = self.levelSlider.value
    config.puzzle_randomColors = self.randomColorsButtons.value 
    logger.debug("saving settings...")
    write_conf_file()
  end
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  sceneManager:switchToScene("mainMenu")
end

function puzzleMenu:init()
  sceneManager:addScene(puzzleMenu)

  local tickLength = 16
  self.levelSlider = LevelSlider({
      tickLength = tickLength,
      onValueChange = function(s)
        play_optional_sfx(themes[config.theme].sounds.menu_move)
      end
    })
  
  self.randomColorsButtons = ButtonGroup(
    {
      buttons = {
        Button({label = "op_off", width = 60, height = 25}),
        Button({label = "op_on", width = 60, height = 25}),
      },
      values = {false, true},
      selectedIndex = config.puzzle_randomColors and 2 or 1,
      onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
    }
  )
  
  local menuOptions = {
    {Label({label = "level", isVisible = false}), self.levelSlider},
    {Label({label = "randomColors", isVisible = false}), self.randomColorsButtons},
  }

  for puzzleSetName, puzzleSet in pairsSortedByKeys(GAME.puzzleSets) do
    menuOptions[#menuOptions + 1] = {Button({label = puzzleSetName, translate = false, onClick = function() self:startGame(puzzleSet) end})}
  end
  menuOptions[#menuOptions + 1] = {Button({label = "back", onClick = exitMenu})}
  
  self.menu = Menu({menuItems = menuOptions})
  self.menu:setVisibility(false)
end

function puzzleMenu:load()
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  y = y + 20
  self.menu.x = x
  self.menu.y = y
  
  if themes[config.theme].musics.main then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  reset_filters()
  
  self.menu:updateLabel()
  self.menu:setVisibility(true)
end

function puzzleMenu:drawBackground()
  themes[config.theme].images.bg_main:draw()
end

function puzzleMenu:update()
  gprint(loc("pz_puzzles"), unpack(themes[config.theme].main_menu_screen_pos))
      
  self.menu:update()
  self.menu:draw()
end

function puzzleMenu:unload()
  self.menu:setVisibility(false)
  stop_the_music()
end

return puzzleMenu