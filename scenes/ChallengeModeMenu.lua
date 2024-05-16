local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local class = require("class")
local ChallengeMode = require("ChallengeMode")
local Menu = require("ui.Menu")
local MenuItem = require("ui.MenuItem")
local Label = require("ui.Label")
local TextButton = require("ui.TextButton")
local Stepper = require("ui.Stepper")

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
  GAME.theme:playCancelSfx()
  sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
end

function ChallengeModeMenu:goToCharacterSelect(difficulty)
  GAME.battleRoom = ChallengeMode(difficulty)
  GAME.theme:playValidationSfx()

  local scene = sceneManager:createScene("CharacterSelectChallenge")
  sceneManager:switchToScene(scene)
end

function ChallengeModeMenu:load(sceneParams)
  local difficultyLabels = {}
  local challengeModes = {}
  for i = 1, ChallengeMode.numDifficulties do
    table.insert(difficultyLabels, Label({text = "challenge_difficulty_" .. i}))
    table.insert(challengeModes, i)
  end

  local difficultyStepper = Stepper({
      labels = difficultyLabels,
      values = challengeModes,
      selectedIndex = 1,
      width = 70,
      height = 25,
      onChange = function(value)
        GAME.theme:playMoveSfx()
      end
    }
  )

  local menuItems = {
    MenuItem.createStepperMenuItem("difficulty", nil, nil, difficultyStepper),
    MenuItem.createButtonMenuItem("go_", nil, nil, function()
      self:goToCharacterSelect(difficultyStepper.value)
    end),
    MenuItem.createButtonMenuItem("back", nil, nil, exitMenu)
  }

  self.menu = Menu.createCenteredMenu(menuItems)
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