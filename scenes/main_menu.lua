local Scene = require("scenes.Scene")
local replay_browser = require("replay_browser")
local logger = require("logger")
local select_screen = require("select_screen")
local options = require("options")
local utf8 = require("utf8")
local analytics = require("analytics")
local main_config_input = require("config_inputs")
local ServerQueue = require("ServerQueue")

--@module MainMenu
local main_menu = Scene()

--[[
local menu_options = {
  {loc("mm_1_endless"), main_endless_select},
  {loc("mm_1_puzzle"), main_select_puzz},
  {loc("mm_1_time"), main_timeattack_select},
  {loc("mm_1_vs"), main_local_vs_yourself_setup},
  {loc("mm_1_training"), training_setup},
  --{loc("mm_2_vs_online", "burke.ro"), main_net_vs_setup, {"burke.ro"}},
  {loc("mm_2_vs_online", ""), main_net_vs_setup, {"18.188.43.50"}},
  --{loc("mm_2_vs_online", "Shosoul's Server"), main_net_vs_setup, {"149.28.227.184"}},
  --{loc("mm_2_vs_online", "betaserver.panelattack.com"), main_net_vs_setup, {"betaserver.panelattack.com"}},
  --{loc("mm_2_vs_online", "(USE ONLY WITH OTHER CLIENTS ON THIS TEST BUILD 025beta)"), main_net_vs_setup, {"18.188.43.50"}},
  --{loc("mm_2_vs_online", "This test build is for offline-use only"), main_select_mode},
  --{loc("mm_2_vs_online", "domi1819.xyz"), main_net_vs_setup, {"domi1819.xyz"}},
  --{loc("mm_2_vs_online", "(development-use only)"), main_net_vs_setup, {"localhost"}},
  --{loc("mm_2_vs_online", "LittleEndu's server"), main_net_vs_setup, {"51.15.207.223"}},
  {loc("mm_2_vs_online", "server for ranked Ex Mode"), main_net_vs_setup, {"exserver.panelattack.com", 49568}},
  {loc("mm_2_vs_local"), main_local_vs_setup},
  {loc("mm_replay_browser"), replay_browser.main},
  {loc("mm_configure"), main_config_input},
  {loc("mm_set_name"), main_set_name},
  {loc("mm_options"), options.main},
  {loc("mm_fullscreen", "(LAlt+Enter)"), fullscreen, goEscape},
  {loc("mm_quit"), exit_game, exit_game}
}
--]]

local main_menu2
function main_menu:load()
  CLICK_MENUS = {}
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
  local menu_x, menu_y = unpack(main_menu_screen_pos)
  
  ret = nil

  local function goEscape()
    main_menu2:set_active_idx(#main_menu.buttons)
  end

  local function selectFunction(myFunction, args)
    local function constructedFunction()
      main_menu_last_index = main_menu.active_idx
      main_menu2:remove_self()
      func = myFunction
      arg = args
    end
    return constructedFunction
  end

  match_type_message = ""
  print(main_endless_select)
  local items = {
    {loc("mm_1_endless"), main_endless_select},
    {loc("mm_1_puzzle"), main_select_puzz},
    {loc("mm_1_time"), main_timeattack_select},
    {loc("mm_1_vs"), main_local_vs_yourself_setup},
    {loc("mm_1_training"), training_setup},
    --{loc("mm_2_vs_online", "burke.ro"), main_net_vs_setup, {"burke.ro"}},
    {loc("mm_2_vs_online", ""), main_net_vs_setup, {"18.188.43.50"}},
    --{loc("mm_2_vs_online", "Shosoul's Server"), main_net_vs_setup, {"149.28.227.184"}},
    --{loc("mm_2_vs_online", "betaserver.panelattack.com"), main_net_vs_setup, {"betaserver.panelattack.com"}},
    --{loc("mm_2_vs_online", "(USE ONLY WITH OTHER CLIENTS ON THIS TEST BUILD 025beta)"), main_net_vs_setup, {"18.188.43.50"}},
    --{loc("mm_2_vs_online", "This test build is for offline-use only"), main_select_mode},
    --{loc("mm_2_vs_online", "domi1819.xyz"), main_net_vs_setup, {"domi1819.xyz"}},
    --{loc("mm_2_vs_online", "(development-use only)"), main_net_vs_setup, {"localhost"}},
    --{loc("mm_2_vs_online", "LittleEndu's server"), main_net_vs_setup, {"51.15.207.223"}},
    {loc("mm_2_vs_online", "server for ranked Ex Mode"), main_net_vs_setup, {"exserver.panelattack.com", 49568}},
    {loc("mm_2_vs_local"), main_local_vs_setup},
    {loc("mm_replay_browser"), replay_browser.main},
    {loc("mm_configure"), main_config_input},
    {loc("mm_set_name"), main_set_name},
    {loc("mm_options"), options.main}
  }

  main_menu2 = ClickMenu(menu_x, menu_y, nil, canvas_height - menu_y - 10, main_menu_last_index)
  for i = 1, #items do
    main_menu2:add_button(items[i][1], selectFunction(items[i][2], items[i][3]), goEscape)
  end
  main_menu2:add_button(loc("mm_fullscreen", "(LAlt+Enter)"), fullscreen, goEscape)
  main_menu2:add_button(loc("mm_quit"), exit_game, exit_game)
end

function main_menu:update()
  main_menu2:draw()
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

  coroutine.yield()
  variable_step(
    function()
      main_menu2:update()
    end
  )
end

function main_menu:draw()
  
end

function main_menu:unload()
  
end

return main_menu