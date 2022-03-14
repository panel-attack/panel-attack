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
local arrow = love.graphics.newText(font, ">")
local menu_buttons = {
  Button({text = love.graphics.newText(font, loc("mm_1_endless")), onClick = function() switchScene("endless_menu") end, is_visible = false}),
  Button({text = love.graphics.newText(font, loc("mm_1_puzzle")), onClick = function() switchScene("puzzle_menu") end, is_visible = false}),
  Button({text = love.graphics.newText(font, loc("mm_1_time")), onClick = function() switchScene("time_attack_menu") end, is_visible = false}),
  Button({text = love.graphics.newText(font, loc("mm_1_vs")), onClick = function() switchScene("vs_self_menu") end, is_visible = false}),
  Button({text = love.graphics.newText(font, loc("mm_1_training")), onClick = genOnClickFn(training_setup), is_visible = false}),
  --{loc("mm_2_vs_online", "burke.ro"), main_net_vs_setup, {"burke.ro"}},
  Button({text = love.graphics.newText(font, loc("mm_2_vs_online", "\nTelegraph Server")), onClick = genOnClickFn(main_net_vs_setup, {"betaserver.panelattack.com", 59569}), is_visible = false}),
  --{loc("mm_2_vs_online", "Shosoul's Server"), main_net_vs_setup, {"149.28.227.184"}},
  --{loc("mm_2_vs_online", "betaserver.panelattack.com"), main_net_vs_setup, {"betaserver.panelattack.com"}},
  --{loc("mm_2_vs_online", "(USE ONLY WITH OTHER CLIENTS ON THIS TEST BUILD 025beta)"), main_net_vs_setup, {"18.188.43.50"}},
  --{loc("mm_2_vs_online", "This test build is for offline-use only"), main_select_mode},
  --{loc("mm_2_vs_online", "domi1819.xyz"), main_net_vs_setup, {"domi1819.xyz"}},
  --{loc("mm_2_vs_online", "(development-use only)"), main_net_vs_setup, {"localhost"}},
  --{loc("mm_2_vs_online", "LittleEndu's server"), main_net_vs_setup, {"51.15.207.223"}},
  Button({text = love.graphics.newText(font, loc("mm_2_vs_local")), onClick = genOnClickFn(main_local_vs_setup), is_visible = false}),
  Button({text = love.graphics.newText(font, loc("mm_replay_browser")), onClick = genOnClickFn(replay_browser.main), is_visible = false}),
  Button({text = love.graphics.newText(font, loc("mm_configure")), onClick = genOnClickFn(main_config_input), is_visible = false}),
  Button({text = love.graphics.newText(font, loc("mm_set_name")), onClick = genOnClickFn(main_set_name), is_visible = false}),
  Button({text = love.graphics.newText(font, loc("mm_options")), onClick = genOnClickFn(options.main), is_visible = false}),
  Button({text = love.graphics.newText(font, loc("mm_fullscreen", "\n(LAlt+Enter)")), onClick = function() play_optional_sfx(themes[config.theme].sounds.menu_validate) fullscreen() end, is_visible = false}),
  Button({text = love.graphics.newText(font, loc("mm_quit")), onClick = exit_game, is_visible = false})
}

local selected_id = 1

function main_menu:init()
  scene_manager:addScene(main_menu)
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
  local menu_x, menu_y = unpack(main_menu_screen_pos)
  for i, button in ipairs(menu_buttons) do
    button.x = menu_x + 25
    button.y = i > 1 and menu_buttons[i - 1].y + menu_buttons[i - 1].height + 5 or menu_y
    -- button.width = 110
    -- button.height = 25
    button.is_visible = true
  end
end

function main_menu:update()
  if input:isPressedWithRepeat("down", .25, .05) then
    selected_id = (selected_id % #menu_buttons) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end
  if input:isPressedWithRepeat("up", .25, .05) then
    selected_id = ((selected_id - 2) % #menu_buttons) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end
  if input.isDown["return"] then
    menu_buttons[selected_id].onClick()
  end
  if input.isDown["escape"] then
    if selected_id ~= #menu_buttons then
      selected_id = #menu_buttons
      play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    else
      love.event.quit()
    end
  end
  
  local animationX = (math.cos(6 * love.timer.getTime()) * 5) - 9
  local arrowx = menu_buttons[selected_id].x - 10 + animationX
  local arrowy = menu_buttons[selected_id].y + menu_buttons[selected_id].height / 4
  GAME.gfx_q:push({love.graphics.draw, {arrow, arrowx, arrowy, 0, 1, 1, 0, 0}})
  
  if wait_game_update ~= nil then
    has_game_update = wait_game_update:pop()
    if has_game_update ~= nil and has_game_update then
      wait_game_update = nil
      GAME_UPDATER_GAME_VERSION = "NEW VERSION FOUND! RESTART THE GAME!"
    end
  end

  if GAME_UPDATER_GAME_VERSION then
    gprintf("version: " .. GAME_UPDATER_GAME_VERSION, -2, 705, canvas_width, "right")
    if has_game_update then
      menu_draw(panels[config.panels].images.classic[1][1], 1262, 685)
    end
  end
end

function main_menu:unload()
  for i, button in ipairs(menu_buttons) do
    button.is_visible = false
  end
end

return main_menu