local Scene = require("scenes.Scene")
local replay_browser = require("replay_browser")
local logger = require("logger")
local options = require("options")
local utf8 = require("utf8")
local analytics = require("analytics")
local main_config_input = require("config_inputs")
local ServerQueue = require("ServerQueue")
local Button = require("ui.Button")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local LevelSlider = require("ui.LevelSlider")
local Label = require("ui.Label")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local util = require("util")
local save = require("save")

--@module MainMenu
local puzzle_menu = Scene("puzzle_menu")

local font = love.graphics.getFont()
  
function puzzle_menu:startGame(puzzle_set)
  current_stage = config.stage
  if current_stage == random_stage_special_value then
    current_stage = nil
  end
  
  if config.puzzle_randomColors then
    puzzle_set = deepcpy(puzzle_set)

    for _, puzzle in pairs(puzzle_set.puzzles) do
      puzzle.stack = Puzzle.randomizeColorString(puzzle.stack)
    end
  end
  
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  sceneManager:switchToScene("puzzle_game", {puzzle_set = puzzle_set, puzzle_index = 1})
  
  if config.puzzle_level ~= self.level_slider.value or config.puzzle_randomColors ~= self.random_colors_buttons.value then
    config.puzzle_level = self.level_slider.value
    config.puzzle_randomColors = self.random_colors_buttons.value 
    logger.debug("saving settings...")
    save.write_conf_file()
  end
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  sceneManager:switchToScene("mainMenu")
end

function puzzle_menu:init()
  sceneManager:addScene(puzzle_menu)

  local tickLength = 16
  self.level_slider = LevelSlider({
      tickLength = tickLength,
      onValueChange = function(s)
        play_optional_sfx(themes[config.theme].sounds.menu_move)
      end
    })
  
  self.random_colors_buttons = ButtonGroup(
    {
      buttons = {
        Button({label = "op_off", width = 60, height = 25}),
        Button({label = "op_on", width = 60, height = 25}),
      },
      values = {false, true},
      selected_index = config.puzzle_randomColors and 2 or 1,
      onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
    }
  )
  
  local menu_options = {
    {Label({label = "level", isVisible = false}), self.level_slider},
    {Label({label = "randomColors", isVisible = false}), self.random_colors_buttons},
  }

  for puzzle_set_name, puzzle_set in util.pairsSortedByKeys(GAME.puzzleSets) do
    menu_options[#menu_options + 1] = {Button({label = puzzle_set_name, translate = false, onClick = function() self:startGame(puzzle_set) end})}
  end
  menu_options[#menu_options + 1] = {Button({label = "back", onClick = exitMenu})}
  
  local x, y = unpack(main_menu_screen_pos)
  y = y + 20
  self.menu = Menu({menuItems = menu_options, x = x, y = y})
  self.menu:setVisibility(false)
end

function puzzle_menu:load()
  if themes[config.theme].musics.main then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  reset_filters()
  
  self.menu:updateLabel()
  self.menu:setVisibility(true)
end

function puzzle_menu:drawBackground()
  themes[config.theme].images.bg_main:draw()
end

function puzzle_menu:update()
  gprint(loc("pz_puzzles"), unpack(main_menu_screen_pos))
  gprint(loc("pz_info"), main_menu_screen_pos[1] - 300, main_menu_screen_pos[2] + 220)
      
  self.menu:update()
  self.menu:draw()
end

function puzzle_menu:unload()
  self.menu:setVisibility(false)
  stop_the_music()
end

return puzzle_menu