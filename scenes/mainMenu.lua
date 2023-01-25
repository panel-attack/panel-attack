local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local consts = require("consts")
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

local BUTTON_WIDTH = 140
local function createMainMenuButton(label, onClick, extra_labels, translate)
  if translate == nil then
    translate = true
  end
  return Button({label = label, extra_labels = extra_labels, translate = translate, onClick = onClick, width = BUTTON_WIDTH})
end

local menuItems = {
  {createMainMenuButton("mm_1_endless", genLegacyMainloopFn(main_endless_select))},
  {createMainMenuButton("mm_1_puzzle", genLegacyMainloopFn(main_select_puzz))},
  {createMainMenuButton("mm_1_time", genLegacyMainloopFn(main_timeattack_select))},
  {createMainMenuButton("mm_1_vs", genLegacyMainloopFn(main_local_vs_yourself_setup))},
  {createMainMenuButton("mm_1_training", genLegacyMainloopFn(training_setup))},
  {createMainMenuButton("mm_2_vs_online", genLegacyMainloopFn(main_net_vs_setup, {"18.188.43.50"}),  {""})},
  {createMainMenuButton("mm_2_vs_local", genLegacyMainloopFn(main_local_vs_setup))},
  {createMainMenuButton("mm_replay_browser", genLegacyMainloopFn(replay_browser.main))},
  {createMainMenuButton("mm_configure", function() switchToScene("inputConfigMenu") end)},
  {createMainMenuButton("mm_set_name", function() Menu.playValidationSfx() sceneManager:switchToScene("setNameMenu", {prevScene = "mainMenu"}) end)},
  {createMainMenuButton("mm_options", function() switchToScene("optionsMenu") end)},
  {createMainMenuButton("mm_fullscreen", function() Menu.playValidationSfx() fullscreen() end, {"\n(LAlt+Enter)"})},
  {createMainMenuButton("mm_quit", love.event.quit)}
}

if config.debugShowServers then
  table.insert(menuItems, 7, {createMainMenuButton("Beta Server", genLegacyMainloopFn(main_net_vs_setup, {"betaserver.panelattack.com", 59569}),  {""}, false)})
  table.insert(menuItems, 8, {createMainMenuButton("Localhost Server", genLegacyMainloopFn(main_net_vs_setup, {"localhost"}),  {""}, false)})
end

function mainMenu:init()
  sceneManager:addScene(self)
  self.menu = Menu({menuItems = menuItems})
  self.menu:setVisibility(false)
end

function mainMenu:load()
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  self.menu.x = (consts.CANVAS_WIDTH / 2) - BUTTON_WIDTH / 2
  self.menu.y = y
  
  self.backgroundImg = themes[config.theme].images.bg_main
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
  self.backgroundImg:draw()
end

function mainMenu:update(dt)
  if wait_game_update ~= nil then
    has_game_update = wait_game_update:pop()
    if has_game_update ~= nil and has_game_update then
      wait_game_update = nil
      GAME_UPDATER_GAME_VERSION = "NEW VERSION FOUND! RESTART THE GAME!"
    end
  end

  self.backgroundImg:update(dt)
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