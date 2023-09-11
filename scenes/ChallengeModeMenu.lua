local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local class = require("class")
local ChallengeMode = require("ChallengeMode")
local Menu = require("ui.Menu")
local Label = require("ui.Label")
local Button = require("ui.Button")
local Stepper = require("ui.Stepper")
local Slider = require("ui.Slider")
local tableUtils = require("tableUtils")

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
  sceneManager:switchToScene("MainMenu")
end

function ChallengeModeMenu:load(sceneParams)
  local difficultyLabels = {}
  local challengeModes = {}
  for i = 1, ChallengeMode.numDifficulties do
    table.insert(difficultyLabels, Label({
        label = "challenge_difficulty_" .. i,
        width = 70,
        height = 25}))
    table.insert(challengeModes, ChallengeMode(i))
  end

  local difficultyStepper = Stepper({
      labels = difficultyLabels,
      values = challengeModes,
      selectedIndex = 1,
    }
  )

  local menuItems = {
    {Label({label = "difficulty"}), difficultyStepper},
    {Button({label = "go_", onClick = function() sceneManager:switchToScene("CharacterSelectChallenge", {challengeMode = difficultyStepper.value}) end})},
    {Button({label = "back", onClick = exitMenu})},
  }

  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  y = y + 100
  self.menu = Menu({
    x = x,
    y = y,
    menuItems = menuItems,
  })
end

function ChallengeModeMenu:drawBackground()
  self.backgroundImg:draw()
end

function ChallengeModeMenu:update(dt)
  self.backgroundImg:update(dt)
  self.menu:update(dt)
  self.menu:draw()
end

function ChallengeModeMenu:unload()
  
end

return ChallengeModeMenu