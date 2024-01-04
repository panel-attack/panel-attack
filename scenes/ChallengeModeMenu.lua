local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local class = require("class")
local ChallengeMode = require("ChallengeMode")
local Menu = require("ui.Menu")
local Label = require("ui.Label")
local TextButton = require("ui.TextButton")
local Stepper = require("ui.Stepper")
local Slider = require("ui.Slider")
local tableUtils = require("tableUtils")
local GameModes = require("GameModes")

--@module ChallengeModeMenu
-- 
local ChallengeModeMenu = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_main
    self:load(sceneParams)
  end,
  Scene
)

ChallengeModeMenu.name = "ChallengeModeMenu"
sceneManager:addScene(ChallengeModeMenu)

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
end

function ChallengeMode:goToCharacterSelect()
  local battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_CHALLENGE"))
  
  local scene = sceneManager:createScene("CharacterSelectVsSelf")
  sceneManager:switchToScene(scene)
end

function ChallengeModeMenu:load(sceneParams)
  local difficultyLabels = {}
  local challengeModes = {}
  for i = 1, ChallengeMode.numDifficulties do
    table.insert(difficultyLabels, Label({text = "challenge_difficulty_" .. i}))
    table.insert(challengeModes, ChallengeMode(i))
  end

  local difficultyStepper = Stepper({
      labels = difficultyLabels,
      values = challengeModes,
      selectedIndex = 1,
      width = 70,
      height = 25
    }
  )

  local menuItems = {
    {Label({text = "difficulty"}), difficultyStepper},
    {TextButton({label = Label({text = "go_"}), onClick = self.goToCharacterSelect})},
    {TextButton({label = Label({text = "back"}), onClick = exitMenu})},
  }

  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  y = y + 100
  self.menu = Menu({
    x = x,
    y = y,
    menuItems = menuItems,
  })
  self.uiRoot:addChild(self.menu)
end

function ChallengeModeMenu:update(dt)
  self.backgroundImg:update(dt)
  self.menu:update(dt)
end

function ChallengeModeMenu:draw()
  self.backgroundImg:draw()
  self.uiRoot:draw()
end

return ChallengeModeMenu