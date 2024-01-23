local Scene = require("scenes.Scene")
local TextButton = require("ui.TextButton")
local Label = require("ui.Label")
local consts = require("consts")
local Menu = require("ui.Menu")
local sceneManager = require("scenes.sceneManager")
local GraphicsUtil = require("graphics_util")
local class = require("class")
local GameModes = require("GameModes")
local EndlessMenu = require("scenes.EndlessMenu")
local PuzzleMenu = require("scenes.PuzzleMenu")
local TimeAttackMenu = require("scenes.TimeAttackMenu")
local CharacterSelectVsSelf = require("scenes.CharacterSelectVsSelf")
local TrainingMenu = require("scenes.TrainingMenu")
local ChallengeModeMenu = require("scenes.ChallengeModeMenu")
local Lobby = require("scenes.Lobby")
local CharacterSelect2p = require("scenes.CharacterSelect2p")
local ReplayBrowser = require("scenes.ReplayBrowser")
local InputConfigMenu = require("scenes.InputConfigMenu")
local SetNameMenu = require("scenes.SetNameMenu")
local OptionsMenu = require("scenes.OptionsMenu")
local DesignHelper = require("scenes.DesignHelper")


-- @module MainMenu
-- Scene for the main menu
local MainMenu = class(function(self, sceneParams)
  self.menu = nil -- set in load
  self.backgroundImg = themes[config.theme].images.bg_main
  self:load(sceneParams)
end, Scene)

MainMenu.name = "MainMenu"
sceneManager:addScene(MainMenu)

local function switchToScene(sceneName, transition)
  Menu.playValidationSfx()
  sceneManager:switchToScene(sceneName, transition)
end

local BUTTON_WIDTH = 140
local function createMainMenuButton(text, onClick, extraLabels, translate)
  if translate == nil then
    translate = true
  end
  return TextButton({label = Label({text = text, extraLabels = extraLabels, translate = translate, hAlign = "center", vAlign = "center"}), onClick = onClick, width = BUTTON_WIDTH})
end

local menuItems = {
  {
    createMainMenuButton("mm_1_endless", function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_ENDLESS"))
      switchToScene(EndlessMenu())
    end)
  }, {
    createMainMenuButton("mm_1_puzzle", function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_PUZZLE"))
      switchToScene(PuzzleMenu())
    end)
  }, {
    createMainMenuButton("mm_1_time", function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_TIME_ATTACK"))
      switchToScene(TimeAttackMenu())
    end)
  }, {
    createMainMenuButton("mm_1_vs", function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_VS_SELF"))
      switchToScene(CharacterSelectVsSelf())
    end)
  }, {
    createMainMenuButton("mm_1_training", function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_TRAINING"))
      switchToScene(TrainingMenu())
    end)
  }, {
    createMainMenuButton("mm_1_challenge_mode", function()
      switchToScene(ChallengeModeMenu())
    end)
  }, {
    createMainMenuButton("mm_2_vs_online", function()
      switchToScene(Lobby({serverIp = "panelattack.com"}))
    end, {""})
  }, {
    createMainMenuButton("mm_2_vs_local", function()
      local battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("TWO_PLAYER_VS"))
      if not battleRoom.hasShutdown then
        GAME.battleRoom = battleRoom
        switchToScene(CharacterSelect2p())
      end
    end)
  }, {
    createMainMenuButton("mm_replay_browser", function()
      switchToScene(ReplayBrowser())
    end)
  }, {
    createMainMenuButton("mm_configure", function()
      switchToScene(InputConfigMenu())
    end)
  }, {
    createMainMenuButton("mm_set_name", function()
      switchToScene(SetNameMenu())
    end)
  }, {
    createMainMenuButton("mm_options", function()
      switchToScene(OptionsMenu())
    end)
  }, {
    createMainMenuButton("mm_fullscreen", function()
      Menu.playValidationSfx()
      love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
    end, {"\n(Alt+Enter)"})
  },
  {createMainMenuButton("mm_quit", love.event.quit)}
}

local debugMenuItems = {
  {createMainMenuButton("Beta Server", function() switchToScene(Lobby({serverIp = "betaserver.panelattack.com", serverPort = 59569})) end)},
  {createMainMenuButton("Localhost Server", function() switchToScene(Lobby({serverIp = "Localhost"})) end)}
}

function MainMenu:addDebugMenuItems()
  if config.debugShowServers then
    for i, menuItem in ipairs(debugMenuItems) do
      self.menu:addMenuItem(i + 7, menuItem)
    end
  end
  if config.debugShowDesignHelper then
    self.menu:addMenuItem(#self.menu.menuItems, {
      createMainMenuButton("Design Helper", function()
        switchToScene(DesignHelper())
      end)
    })
  end
end

function MainMenu:removeDebugMenuItems()
  for i, menuItem in ipairs(debugMenuItems) do
    self.menu:removeMenuItem(menuItem[1].id)
  end
end

function MainMenu:load(sceneParams)
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  self.menu = Menu({
    x = (consts.CANVAS_WIDTH / 2) - BUTTON_WIDTH / 2,
    y = y,
    menuItems = menuItems,
    maxHeight = themes[config.theme].main_menu_max_height
  })
  self.uiRoot:addChild(self.menu)

  self:addDebugMenuItems()

  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  CharacterLoader.clear()
  StageLoader.clear()
  GAME.tcpClient:resetNetwork()
  GAME.battleRoom = nil
end

function MainMenu:update(dt)
  if wait_game_update ~= nil then
    has_game_update = wait_game_update:pop()
    if has_game_update ~= nil and has_game_update then
      wait_game_update = nil
      GAME_UPDATER_GAME_VERSION = "NEW VERSION FOUND! RESTART THE GAME!"
    end
  end

  self.backgroundImg:update(dt)
  self.menu:update()
end

function MainMenu:draw()
  self.backgroundImg:draw()
  self.menu:draw()
  local fontHeight = GraphicsUtil.getGlobalFont():getHeight()
  local infoYPosition = 705 - fontHeight / 2

  local loveString = GAME:loveVersionString()
  if loveString == "11.3.0" then
    gprintf(loc("love_version_warning"), -5, infoYPosition, consts.CANVAS_WIDTH, "right")
    infoYPosition = infoYPosition - fontHeight
  end

  if GAME_UPDATER_GAME_VERSION then
    gprintf("PA Version: " .. GAME_UPDATER_GAME_VERSION, -5, infoYPosition, consts.CANVAS_WIDTH, "right")
    infoYPosition = infoYPosition - fontHeight
    if has_game_update then
      GraphicsUtil.draw(panels[config.panels].images.classic[1][1], 1262, 685)
    end
  end
end

return MainMenu
