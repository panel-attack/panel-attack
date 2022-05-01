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
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local scene_manager = require("scenes.scene_manager")
local input = require("input2")
local util = require("util")

--@module MainMenu
local puzzle_menu = Scene("puzzle_menu")

local font = love.graphics.getFont()
local arrow = love.graphics.newText(font, ">")

local items = {}
local last_puzzle_idx = 1
local active_idx = last_puzzle_idx

local function startGame()
  stop_the_music()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene(nil)
  
  last_puzzle_idx = active_idx
        
  func = items[active_idx][2]
  arg = {items[active_idx][3]}
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene("main_menu")
end
  
function puzzle_menu:init()
  scene_manager:addScene(puzzle_menu)
  for key, val in util.pairsSortedByKeys(GAME.puzzleSets) do
    items[#items + 1] = {key, make_main_puzzle(val)}
  end
  items[#items + 1] = {"back", nil} -- uses scene manager to go back
end

function puzzle_menu:load()
  if themes[config.theme].musics.main then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  GAME.backgroundImage = themes[config.theme].images.bg_main
  reset_filters()
end

function puzzle_menu:update()
  local to_print = ""
  local arrow = ""
  for i = 1, #items do
    if active_idx == i then
      arrow = arrow .. ">"
    else
      arrow = arrow .. "\n"
    end
    local loc_item = (items[i][1] == "back") and loc("back") or items[i][1]
    to_print = to_print .. "   " .. loc_item .. "\n"
  end
  gprint(loc("pz_puzzles"), unpack(main_menu_screen_pos))
  gprint(loc("pz_info"), main_menu_screen_pos[1] - 280, main_menu_screen_pos[2] + 220)
  gprint(arrow, main_menu_screen_pos[1] + 100, main_menu_screen_pos[2])
  gprint(to_print, main_menu_screen_pos[1] + 100, main_menu_screen_pos[2])
      
  if input:isPressedWithRepeat("Down", .25, .05) then
    active_idx = wrap(1, active_idx + 1, #items)
    --selected_id = (selected_id % #menu_options) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end
  
  if input:isPressedWithRepeat("Up", .25, .05) then
    active_idx = wrap(1, active_idx - 1, #items)
    --selected_id = ((selected_id - 2) % #menu_options) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end
  
  if input.isDown["Start"] or input.isDown["Swap1"] then
    if active_idx == #items then
      exitMenu()
    else
      startGame()
    end
  end
  
  if input.isDown["Swap2"] then
    if active_idx == #items then
      exitMenu()
    else
      active_idx = #items
    end
  end
end

function puzzle_menu:unload()
end

return puzzle_menu