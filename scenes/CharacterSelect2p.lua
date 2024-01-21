local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local CharacterSelect = require("scenes.CharacterSelect")
local class = require("class")
local GameModes = require("GameModes")
local Grid = require("ui.Grid")
local MultiPlayerSelectionWrapper = require("ui.MultiPlayerSelectionWrapper")
local Label = require("ui.Label")

--@module CharacterSelect2p
-- 
local CharacterSelect2p = class(
  function (self, sceneParams)
    self:load(sceneParams)
  end,
  CharacterSelect
)

CharacterSelect2p.name = "CharacterSelect2p"
sceneManager:addScene(CharacterSelect2p)

function CharacterSelect2p:customLoad(sceneParams)
  self:loadUserInterface()
end

function CharacterSelect2p:loadUserInterface()
  self.ui.grid = Grid({x = 153, y = 60, unitSize = 108, gridWidth = 9, gridHeight = 6, unitMargin = 6})
  self.uiRoot:addChild(self.ui.grid)

  self.ui.panelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "center"})
  self.ui.stageSelection = MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  self.ui.levelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "center"})
  self.ui.readyButton = self:createReadyButton()
  local characterButtons = self:getCharacterButtons()
  local characterGridWidth, characterGridHeight = self.ui.grid.gridWidth, 3
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)
  self.ui.leaveButton = self:createLeaveButton()
  self.ui.rankedSelection = MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  local trueLabel = Label({text = "ss_ranked", vAlign = "top", hAlign = "center"})
  local falseLabel = Label({text = "ss_casual", vAlign = "bottom", hAlign = "center"})
  self.ui.rankedSelection:addChild(trueLabel)
  self.ui.rankedSelection:addChild(falseLabel)

  local levelHeight
  local panelHeight
  local stageWidth
  local rankedWidth

  if GAME.battleRoom.online then
    self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection)
    self.ui.grid:createElementAt(3, 2, 2, 1, "rankedSelection", self.ui.rankedSelection)
    self.ui.grid:createElementAt(5, 2, 2, 1, "stageSelection", self.ui.stageSelection)
    self.ui.grid:createElementAt(7, 2, 2, 1, "levelSelection", self.ui.levelSelection)

    levelHeight = 14
    panelHeight = (self.ui.grid.unitSize - self.ui.grid.unitMargin * 2) / 2
    stageWidth = self.ui.grid.unitSize - self.ui.grid.unitMargin * 2
    rankedWidth = stageWidth
  else
    self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection)
    self.ui.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.ui.stageSelection)
    self.ui.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.ui.levelSelection)

    levelHeight = 20
    panelHeight = (self.ui.grid.unitSize - self.ui.grid.unitMargin * 2) / 2
    stageWidth = self.ui.grid.unitSize * 1.5 - self.ui.grid.unitMargin * 2
    rankedWidth = stageWidth
  end

  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)
  self.ui.grid:createElementAt(1, 3, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)
  self.ui.grid:createElementAt(9, 6, 1, 1, "leaveButton", self.ui.leaveButton)
  
  self.ui.characterIcons = {}
  for i = 1, #GAME.battleRoom.players do
    local player = GAME.battleRoom.players[i]

    local panelCarousel = self:createPanelCarousel(player, panelHeight)
    self.ui.panelSelection:addElement(panelCarousel, player)

    local rankedSelector = self:createRankedSelection(player, rankedWidth)
    self.ui.rankedSelection:addElement(rankedSelector, player)

    local stageCarousel = self:createStageCarousel(player, stageWidth)
    self.ui.stageSelection:addElement(stageCarousel, player)

    local levelSlider = self:createLevelSlider(player, levelHeight)
    self.ui.levelSelection:addElement(levelSlider, player)

    local cursor = self:createCursor(self.ui.grid, player)
    cursor.raise1Callback = function()
      self.ui.characterGrid:turnPage(-1)
    end
    cursor.raise2Callback = function()
      self.ui.characterGrid:turnPage(1)
    end
    self.ui.cursors[i] = cursor

    self.ui.characterIcons[i] = self:createPlayerIcon(player)
  end

  self.ui.grid:createElementAt(1, 1, 1, 1, "p1 icon", self.ui.characterIcons[1])
  self.ui.grid:createElementAt(8, 1, 1, 1, "p2 icon", self.ui.characterIcons[2])
end


return CharacterSelect2p