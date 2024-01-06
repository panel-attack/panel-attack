local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local CharacterSelect = require("scenes.CharacterSelect")
local class = require("class")
local GameModes = require("GameModes")
local Grid = require("ui.Grid")
local MultiPlayerSelectionWrapper = require("ui.MultiPlayerSelectionWrapper")

--@module CharacterSelectOnline
-- 
local CharacterSelectOnline = class(
  function (self)
    self:load()
  end,
  CharacterSelect
)

CharacterSelectOnline.name = "CharacterSelectOnline"
sceneManager:addScene(CharacterSelectOnline)

function CharacterSelectOnline:customLoad(sceneParams)
  self:loadUserInterface()
end

function CharacterSelectOnline:loadUserInterface()
  self.ui.grid = Grid({x = 153, y = 60, unitSize = 108, gridWidth = 9, gridHeight = 6, unitMargin = 6})
  self.uiRoot:addChild(self.ui.grid)

  self.ui.panelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "center"})

  self.ui.stageSelection = MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})

  self.ui.levelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "center"})

  self.ui.readyButton = self:createReadyButton()

  local characterButtons = self:getCharacterButtons()
  local characterGridWidth, characterGridHeight = 9, 3
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)

  self.ui.leaveButton = self:createLeaveButton()

  self.ui.characterIcons = {}
  for i = 1, #GAME.battleRoom.players do
    local player = GAME.battleRoom.players[i]

    local panelCarousel = self:createPanelCarousel(player, 48)
    self.ui.panelSelection:addElement(panelCarousel, player)

    local stageCarousel = self:createStageCarousel(player, self.ui.grid.unitSize - self.ui.grid.unitMargin * 2)
    self.ui.stageSelection:addElement(stageCarousel, player)

    local levelSlider = self:createLevelSlider(player, 14)
    self.ui.levelSelection:addElement(levelSlider, player)

    local cursor = self:createCursor(self.ui.grid, player)
    cursor.raise1Callback = function()
      self.ui.characterGrid:turnPage(-1)
    end
    cursor.raise2Callback = function()
      self.ui.characterGrid:turnPage(1)
    end
    self.ui.cursors[i] = cursor

    self.ui.characterIcons[i] = self:createSelectedCharacterIcon(player)
  end

  self.ui.grid:createElementAt(1, 1, 1, 1, "p1 icon", self.ui.characterIcons[1])
  self.ui.grid:createElementAt(8, 1, 1, 1, "p2 icon", self.ui.characterIcons[2])
end


return CharacterSelectOnline