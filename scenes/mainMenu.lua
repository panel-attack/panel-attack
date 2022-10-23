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
  {Button({label = "mm_1_endless", onClick = function() switchToScene("endless_menu") end})},
  {Button({label = "mm_1_puzzle", onClick = function() switchToScene("puzzle_menu") end})},
  {Button({label = "mm_1_time", onClick = function() switchToScene("time_attack_menu") end})},
  {Button({label = "mm_1_vs", onClick = function() switchToScene("vs_self_menu") end})},
  {Button({label = "mm_1_training", onClick = function() switchToScene("training_mode_menu") end})},
  {Button({label = "mm_2_vs_online", extra_labels = {""}, onClick = function() play_optional_sfx(themes[config.theme].sounds.menu_validate) sceneManager:switchToScene("lobby", {ip = "18.188.43.50"}) end})},
  --{Button({label = "mm_2_vs_online", extra_labels = {"\nTelegraph Server"}, onClick = genOnClickFn(main_net_vs_setup, {"betaserver.panelattack.com", 59569})})},
  --{Button({label = "mm_2_vs_online", extra_labels = {"(development-use only)"}, onClick = genOnClickFn(main_net_vs_setup, {"localhost"})})},
  {Button({label = "mm_2_vs_local", onClick = genOnClickFn(main_local_vs_setup)})},
  {Button({label = "mm_replay_browser", onClick = function() switchToScene("replay_menu") end})},
  {Button({label = "mm_configure", onClick = function() switchToScene("input_config_menu") end})},
  {Button({label = "mm_set_name", onClick = function() play_optional_sfx(themes[config.theme].sounds.menu_validate) sceneManager:switchToScene("set_name_menu", {prevScene = "main_menu"}) end})},
  {Button({label = "mm_options", onClick = function() switchToScene("options_menu") end})},
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