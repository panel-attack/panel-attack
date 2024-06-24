local CharacterSelect = require("client.src.scenes.CharacterSelect")
local class = require("common.lib.class")
local Grid = require("client.src.ui.Grid")
local MultiPlayerSelectionWrapper = require("client.src.ui.MultiPlayerSelectionWrapper")
local Label = require("client.src.ui.Label")

--@module CharacterSelect2p
-- 
local CharacterSelect2p = class(
  function (self, sceneParams)
  end,
  CharacterSelect
)

CharacterSelect2p.name = "CharacterSelect2p"

function CharacterSelect2p:customLoad(sceneParams)
  self:loadUserInterface()
  self.uiRoot.rankedStatus = self:createRankedStatusPanel()
  self.uiRoot:addChild(self.uiRoot.rankedStatus)
end

function CharacterSelect2p:loadUserInterface()
  self.ui.grid = Grid({unitSize = 100, gridWidth = 9, gridHeight = 6, unitMargin = 8, hAlign = "center", vAlign = "center"})
  self.uiRoot:addChild(self.ui.grid)

  self.ui.panelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "top"})
  self.ui.panelSelection:setTitle("panels")
  self.ui.stageSelection = MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  self.ui.stageSelection:setTitle("stage")
  self.ui.levelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "top"})
  self.ui.levelSelection:setTitle("level")

  self.ui.readyButton = self:createReadyButton()

  local characterButtons = self:getCharacterButtons()
  local characterGridWidth, characterGridHeight = self.ui.grid.gridWidth, 3
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)

  self.ui.pageIndicator = self:createPageIndicator(self.ui.characterGrid)

  self.ui.leaveButton = self:createLeaveButton()
  self.ui.rankedSelection = MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  local trueLabel = Label({text = "ss_ranked", vAlign = "top", hAlign = "center"})
  local falseLabel = Label({text = "ss_casual", vAlign = "bottom", hAlign = "center"})
  self.ui.rankedSelection:addChild(trueLabel)
  self.ui.rankedSelection:addChild(falseLabel)

  local levelHeight
  local panelHeight = (self.ui.grid.unitSize - self.ui.grid.unitMargin * 2) / #GAME.battleRoom.players - self.ui.panelSelection.height
  local stageWidth
  local rankedWidth

  if GAME.battleRoom.online then
    self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection)
    self.ui.grid:createElementAt(3, 2, 2, 1, "rankedSelection", self.ui.rankedSelection)
    self.ui.grid:createElementAt(5, 2, 2, 1, "stageSelection", self.ui.stageSelection)
    self.ui.grid:createElementAt(7, 2, 2, 1, "levelSelection", self.ui.levelSelection)

    levelHeight = 12
    stageWidth = self.ui.grid.unitSize - self.ui.grid.unitMargin * 2
    rankedWidth = stageWidth
  else
    self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection)
    self.ui.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.ui.stageSelection)
    self.ui.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.ui.levelSelection)

    levelHeight = 20
    stageWidth = self.ui.grid.unitSize * 1.5 - self.ui.grid.unitMargin * 2
    rankedWidth = stageWidth
  end

  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)
  self.ui.grid:createElementAt(1, 3, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)
  self.ui.grid:createElementAt(5, 6, 1, 1, "pageIndicator", self.ui.pageIndicator)
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

    local levelSlider = self:createLevelSlider(player, levelHeight, panelHeight)
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
    self.ui.playerInfos[i] = self:createPlayerInfo(player)
  end

  self.ui.grid:createElementAt(1, 1, 1, 1, "p1 icon", self.ui.characterIcons[1])
  self.ui.grid:createElementAt(2, 1, 1, 1, "player 1 info", self.ui.playerInfos[1])
  self.ui.grid:createElementAt(7, 1, 1, 1, "p2 icon", self.ui.characterIcons[2])
  self.ui.grid:createElementAt(8, 1, 1, 1, "player 2 info", self.ui.playerInfos[2])

  -- need to be created at the end after the character grid has been settled in
  -- otherwise the placement will be wrong
  self.ui.pageTurnButtons = self:createPageTurnButtons(self.ui.characterGrid)
end


return CharacterSelect2p