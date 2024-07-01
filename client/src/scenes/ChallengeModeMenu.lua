local Scene = require("client.src.scenes.Scene")
local class = require("common.lib.class")
local ChallengeMode = require("client.src.ChallengeMode")
local Menu = require("client.src.ui.Menu")
local MenuItem = require("client.src.ui.MenuItem")
local Label = require("client.src.ui.Label")
local Stepper = require("client.src.ui.Stepper")
local CharacterSelectChallenge = require("client.src.scenes.CharacterSelectChallenge")

--@module ChallengeModeMenu
-- 
local ChallengeModeMenu = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_main
    self.keepMusic = true
    self:load(sceneParams)
  end,
  Scene
)

ChallengeModeMenu.name = "ChallengeModeMenu"

local function exitMenu()
  GAME.theme:playCancelSfx()
  GAME.navigationStack:pop()
end

function ChallengeModeMenu:goToCharacterSelect(difficulty)
  GAME.theme:playValidationSfx()
  GAME.battleRoom = ChallengeMode(difficulty)
  if GAME.battleRoom then
    GAME.navigationStack:replace(CharacterSelectChallenge())
  end
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
  self.menu:receiveInputs()
end

function ChallengeModeMenu:draw()
  self.backgroundImg:draw()
  self.uiRoot:draw()
end

return ChallengeModeMenu