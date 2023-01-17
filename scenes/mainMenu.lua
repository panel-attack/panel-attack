local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local Menu = require("ui.Menu")
local sceneManager = require("scenes.sceneManager")
local replay_browser = require("replay_browser")
local options = require("options")
local GraphicsUtil = require("graphics_util")

-- need to load the existing global scene functions until they get ported to scenes
require("mainloop")

--@module MainMenu
local mainMenu = Scene("mainMenu")

local function genLegacyMainloopFn(myFunction, args)
  local onClick = function()
    func = myFunction
    arg = args
    Menu.playValidationSfx()
    sceneManager:switchToScene(nil)
  end
  return onClick
end

local switchToScene = function(scene)
  Menu.playValidationSfx()
  sceneManager:switchToScene(scene)
end

local menuItems = {
  {Button({label = "mm_1_endless", onClick = genLegacyMainloopFn(main_endless_select)})},
  {Button({label = "mm_1_puzzle", onClick = genLegacyMainloopFn(main_select_puzz)})},
  {Button({label = "mm_1_time", onClick = genLegacyMainloopFn(main_timeattack_select)})},
  {Button({label = "mm_1_vs", onClick = genLegacyMainloopFn(main_local_vs_yourself_setup)})},
  {Button({label = "mm_1_training", onClick = genLegacyMainloopFn(training_setup)})},
  {Button({label = "mm_2_vs_online", extra_labels = {""}, onClick = genLegacyMainloopFn(main_net_vs_setup, {"18.188.43.50"})})},
  --{Button({label = "mm_2_vs_online", extra_labels = {"\nTelegraph Server"}, onClick = genOnClickFn(main_net_vs_setup, {"betaserver.panelattack.com", 59569})})},
  --{Button({label = "mm_2_vs_online", extra_labels = {"(development-use only)"}, onClick = genOnClickFn(main_net_vs_setup, {"localhost"})})},
  {Button({label = "mm_2_vs_local", onClick = genLegacyMainloopFn(main_local_vs_setup)})},
  {Button({label = "mm_replay_browser", onClick = genLegacyMainloopFn(replay_browser.main)})},
  {Button({label = "mm_configure", onClick = function() switchToScene("inputConfigMenu") end})},
  {Button({label = "mm_set_name", onClick = function() Menu.playValidationSfx() sceneManager:switchToScene("setNameMenu", {prevScene = "mainMenu"}) end})},
  {Button({label = "mm_options", onClick = function() switchToScene("optionsMenu") end})},
  {Button({label = "mm_fullscreen", extra_labels = {"\n(LAlt+Enter)"}, onClick = function() Menu.playValidationSfx() fullscreen() end})},
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
  GAME.battleRoom = nil
  GAME.input:clearInputConfigurationsForPlayers()
  GAME.input:requestPlayerInputConfigurationAssignments(1)
  reset_filters()
  match_type_message = ""
  self.menu:updateLabel()
  self.menu:setVisibility(true)
end

function mainMenu:drawBackground()
  themes[config.theme].images.bg_main:draw()
end

function mainMenu:update()
  if wait_game_update ~= nil then
    has_game_update = wait_game_update:pop()
    if has_game_update ~= nil and has_game_update then
      wait_game_update = nil
      GAME_UPDATER_GAME_VERSION = "NEW VERSION FOUND! RESTART THE GAME!"
    end
  end

  local fontHeight = GraphicsUtil.getGlobalFont():getHeight()
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