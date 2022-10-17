local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local Menu = require("ui.Menu")
local sceneManager = require("scenes.sceneManager")
local replay_browser = require("replay_browser")
local options = require("options")

-- need to load the existing global scene functions until they get ported to scenes
require("mainloop")

--@module MainMenu
local mainMenu = Scene("mainMenu")

local function genOnClickFn(myFunction, args)
  local onClick = function()
    func = myFunction
    arg = args
    play_optional_sfx(themes[config.theme].sounds.menu_validate)
    sceneManager:switchToScene(nil)
  end
  return onClick
end

local switchToScene = function(scene)
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  sceneManager:switchToScene(scene)
end

local menuItems = {
  {Button({label = "mm_1_endless", onClick = genOnClickFn(main_endless_select)})},
  {Button({label = "mm_1_puzzle", onClick = genOnClickFn(main_select_puzz)})},
  {Button({label = "mm_1_time", onClick = genOnClickFn(main_timeattack_select)})},
  {Button({label = "mm_1_vs", onClick = genOnClickFn(main_local_vs_yourself_setup)})},
  {Button({label = "mm_1_training", onClick = genOnClickFn(training_setup)})},
  {Button({label = "mm_2_vs_online", extra_labels = {""}, onClick = genOnClickFn(main_net_vs_setup, {"18.188.43.50"})})},
  --{loc("mm_2_vs_online", "burke.ro"), main_net_vs_setup, {"burke.ro"}},
  --Button({label = "mm_2_vs_online", extra_labels = {"\nTelegraph Server"}, onClick = genOnClickFn(main_net_vs_setup, {"betaserver.panelattack.com", 59569})}),
  --{loc("mm_2_vs_online", "Shosoul's Server"), main_net_vs_setup, {"149.28.227.184"}},
  --{loc("mm_2_vs_online", "betaserver.panelattack.com"), main_net_vs_setup, {"betaserver.panelattack.com"}},
  --{loc("mm_2_vs_online", "(USE ONLY WITH OTHER CLIENTS ON THIS TEST BUILD 025beta)"), main_net_vs_setup, {"18.188.43.50"}},
  --{loc("mm_2_vs_online", "This test build is for offline-use only"), main_select_mode},
  --{loc("mm_2_vs_online", "domi1819.xyz"), main_net_vs_setup, {"domi1819.xyz"}},
  --{loc("mm_2_vs_online", "(development-use only)"), main_net_vs_setup, {"localhost"}},
  --{loc("mm_2_vs_online", "LittleEndu's server"), main_net_vs_setup, {"51.15.207.223"}},
  {Button({label = "mm_2_vs_local", onClick = genOnClickFn(main_local_vs_setup)})},
  {Button({label = "mm_replay_browser", onClick = genOnClickFn(replay_browser.main)})},
  {Button({label = "mm_configure", onClick = function() switchToScene("inputConfigMenu") end})},
  {Button({label = "mm_set_name", onClick = genOnClickFn(main_set_name)})},
  {Button({label = "mm_options", onClick = genOnClickFn(options.main)})},
  {Button({label = "mm_fullscreen", extra_labels = {"\n(LAlt+Enter)"}, onClick = function() play_optional_sfx(themes[config.theme].sounds.menu_validate) fullscreen() end})},
  {Button({label = "mm_quit", onClick = love.event.quit})}
}

function mainMenu:init()
  sceneManager:addScene(self)
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  self.menu = Menu({
      menuItems = menuItems,
      x = x, y = y})
  self.menu:setVisibility(false)
end

function mainMenu:load()
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  character_loader_clear()
  stage_loader_clear()
  resetNetwork()
  GAME.backgroundImage = themes[config.theme].images.bg_main
  GAME.battleRoom = nil
  GAME.input:clearInputConfigurationsForPlayers()
  GAME.input:requestPlayerInputConfigurationAssignments(1)
  reset_filters()
  match_type_message = ""
  self.menu:updateLabel()
  self.menu:setVisibility(true)
end

function mainMenu:update()
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

function mainMenu:unload()
  self.menu:setVisibility(false)
end

return mainMenu