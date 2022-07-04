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
local scene_manager = require("scenes.scene_manager")
local input = require("input2")
require("mainloop")

--@module MainMenu
local main_menu = Scene("main_menu")

local function genOnClickFn(myFunction, args)
  local onClick = function()
    func = myFunction
    arg = args
    play_optional_sfx(themes[config.theme].sounds.menu_validate)
    scene_manager:switchScene(nil)
  end
  return onClick
end

local switchScene = function(scene)
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene(scene)
end
  
local font = love.graphics.getFont() 

local menu_buttons = {
  Button({label = "mm_1_endless", onClick = function() switchScene("endless_menu") end}),
  Button({label = "mm_1_puzzle", onClick = function() switchScene("puzzle_menu") end}),
  Button({label = "mm_1_time", onClick = function() switchScene("time_attack_menu") end}),
  Button({label = "mm_1_vs", onClick = function() switchScene("vs_self_menu") end}),
  Button({label = "mm_1_training", onClick = function() switchScene("training_mode_menu") end}),
  Button({label = "mm_2_vs_online", extra_labels = {""}, onClick = genOnClickFn(main_net_vs_setup, {"18.188.43.50"})}),
  --{loc("mm_2_vs_online", "burke.ro"), main_net_vs_setup, {"burke.ro"}},
  --Button({label = "mm_2_vs_online", extra_labels = {"\nTelegraph Server"}, onClick = genOnClickFn(main_net_vs_setup, {"betaserver.panelattack.com", 59569})}),
  --{loc("mm_2_vs_online", "Shosoul's Server"), main_net_vs_setup, {"149.28.227.184"}},
  --{loc("mm_2_vs_online", "betaserver.panelattack.com"), main_net_vs_setup, {"betaserver.panelattack.com"}},
  --{loc("mm_2_vs_online", "(USE ONLY WITH OTHER CLIENTS ON THIS TEST BUILD 025beta)"), main_net_vs_setup, {"18.188.43.50"}},
  --{loc("mm_2_vs_online", "This test build is for offline-use only"), main_select_mode},
  --{loc("mm_2_vs_online", "domi1819.xyz"), main_net_vs_setup, {"domi1819.xyz"}},
  --{loc("mm_2_vs_online", "(development-use only)"), main_net_vs_setup, {"localhost"}},
  --{loc("mm_2_vs_online", "LittleEndu's server"), main_net_vs_setup, {"51.15.207.223"}},
  Button({label = "mm_2_vs_local", onClick = genOnClickFn(main_local_vs_setup)}),
  Button({label = "mm_replay_browser", onClick = function() switchScene("replay_menu") end}),
  Button({label = "mm_configure", onClick = function() switchScene("input_config_menu") end}),
  Button({label = "mm_set_name", onClick = function() switchScene("set_name_menu") end}),
  Button({label = "mm_options", onClick = function() switchScene("options_menu") end}),
  Button({label = "mm_fullscreen", extra_labels = {"\n(LAlt+Enter)"}, onClick = function() play_optional_sfx(themes[config.theme].sounds.menu_validate) fullscreen() end}),
  Button({label = "mm_quit", onClick = love.event.quit})
}

function main_menu:init()
  scene_manager:addScene(main_menu)
  local x, y = unpack(main_menu_screen_pos)
  self.menu = Menu({
      {menu_buttons[1]},
      {menu_buttons[2]},
      {menu_buttons[3]},
      {menu_buttons[4]},
      {menu_buttons[5]},
      {menu_buttons[6]},
      {menu_buttons[7]},
      {menu_buttons[8]},
      {menu_buttons[9]},
      {menu_buttons[10]},
      {menu_buttons[11]},
      {menu_buttons[12]},
      {menu_buttons[13]},
      }, {x = x, y = y})
  self.menu:setVisibility(false)
end

function main_menu:load()
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  character_loader_clear()
  stage_loader_clear()
  close_socket()
  GAME.backgroundImage = themes[config.theme].images.bg_main
  GAME.battleRoom = nil
  GAME.input:clearInputConfigurationsForPlayers()
  GAME.input:requestPlayerInputConfigurationAssignments(1)
  reset_filters()
  logged_in = 0
  connection_up_time = 0
  connected_server_ip = ""
  current_server_supports_ranking = false
  match_type = ""
  match_type_message = ""
  self.menu:updateLabel()
  self.menu:setVisibility(true)
end

function main_menu:update()
  if wait_game_update ~= nil then
    has_game_update = wait_game_update:pop()
    if has_game_update ~= nil and has_game_update then
      wait_game_update = nil
      GAME_UPDATER_GAME_VERSION = "NEW VERSION FOUND! RESTART THE GAME!"
    end
  end

  local fontHeight = get_global_font():getHeight()
  local infoYPosition = 705 - fontHeight/2

  local loveString = GAME:loveVersionString()
  if loveString == "11.3.0" then
    gprintf(loc("love_version_warning"), -5, infoYPosition, canvas_width, "right")
    infoYPosition = infoYPosition - fontHeight
  end

  if GAME_UPDATER_GAME_VERSION then
    gprintf("PA Version: " .. GAME_UPDATER_GAME_VERSION, -5, infoYPosition, canvas_width, "right")
    infoYPosition = infoYPosition - fontHeight
    if has_game_update then
      menu_draw(panels[config.panels].images.classic[1][1], 1262, 685)
    end
  end
  
  self.menu:update()
  self.menu:draw()
end

function main_menu:unload()
  self.menu:setVisibility(false)
end

return main_menu