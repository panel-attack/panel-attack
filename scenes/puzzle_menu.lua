local Scene = require("scenes.Scene")
local replay_browser = require("replay_browser")
local logger = require("logger")
local select_screen = require("select_screen")
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
local scene_manager = require("scenes.scene_manager")
local input = require("input2")
local util = require("util")
local save = require("save")

--@module MainMenu
local puzzle_menu = Scene("puzzle_menu")

local font = love.graphics.getFont()

local items = {}
  
function puzzle_menu:startGame(id)
  stop_the_music()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene(nil)
  
  if config.puzzle_level ~= self.level_slider.value or config.puzzle_randomColors ~= self.random_colors_buttons.value then
    config.puzzle_level = self.level_slider.value
    config.puzzle_randomColors = self.random_colors_buttons.value 
    logger.debug("saving settings...")
    save.write_conf_file()
  end
        
  func = items[id][2]
  arg = {items[id][3]}
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene("main_menu")
end
  
function puzzle_menu:init()
  scene_manager:addScene(puzzle_menu)

  local tick_length = 16
  self.level_slider = LevelSlider({
      tick_length = tick_length,
      onValueChange = function(s)
        play_optional_sfx(themes[config.theme].sounds.menu_move)
      end
    })
  
  self.random_colors_buttons = ButtonGroup(
    {
      Button({text = love.graphics.newText(font, loc("op_on")), width = 60, height = 25}),
      Button({text = love.graphics.newText(font, loc("op_off")), width = 60, height = 25}),
    },
    {true, false},
    {
      selected_index = config.puzzle_randomColors and 1 or 2,
      onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
    }
  )
  
  local menu_options = {
    {Label({text = love.graphics.newText(font, loc("level")), is_visible = false}), self.level_slider},
    {Label({text = love.graphics.newText(font, loc("randomColors")), is_visible = false}), self.random_colors_buttons},
  }
  
  for key, val in util.pairsSortedByKeys(GAME.puzzleSets) do
    items[#items + 1] = {key, makeSelectPuzzleSetFunction(val)}
    menu_options[#menu_options + 1] = {Button({text = love.graphics.newText(font, key), onClick = function() self:startGame(#items) end})}
  end
  menu_options[#menu_options + 1] = {Button({text = love.graphics.newText(font, loc("back")), onClick = exitMenu})}
  
  local x, y = unpack(main_menu_screen_pos)
  y = y + 20
  self.menu = Menu(menu_options, {x = x, y = y})
  self.menu:setVisibility(false)
end

function puzzle_menu:load()
  if themes[config.theme].musics.main then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  GAME.backgroundImage = themes[config.theme].images.bg_main
  reset_filters()
  
  self.menu:setVisibility(true)
end

function puzzle_menu:update()
  gprint(loc("pz_puzzles"), unpack(main_menu_screen_pos))
  gprint(loc("pz_info"), main_menu_screen_pos[1] - 300, main_menu_screen_pos[2] + 220)
      
  self.menu:update()
  self.menu:draw()
end

function puzzle_menu:unload()
  self.menu:setVisibility(false)
end

return puzzle_menu