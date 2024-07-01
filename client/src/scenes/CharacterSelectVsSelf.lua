local CharacterSelect = require("client.src.scenes.CharacterSelect")
local class = require("common.lib.class")
local Grid = require("client.src.ui.Grid")
local MultiPlayerSelectionWrapper = require("client.src.ui.MultiPlayerSelectionWrapper")

--@module CharacterSelectVsSelf
-- The character select screen scene
local CharacterSelectVsSelf = class(
  function (self, sceneParams)
    self.lastScore = nil
    self.record = nil
  end,
  CharacterSelect
)

CharacterSelectVsSelf.name = "CharacterSelectVsSelf"

function CharacterSelectVsSelf:customLoad(sceneParams)
  self:loadUserInterface()
end

function CharacterSelectVsSelf:loadUserInterface()
  local player = GAME.battleRoom.players[1]

  self.ui.grid = Grid({unitSize = 100, gridWidth = 9, gridHeight = 6, unitMargin = 8, hAlign = "center", vAlign = "center"})
  self.uiRoot:addChild(self.ui.grid)

  self.ui.characterIcons[1] = self:createPlayerIcon(player)
  self.ui.grid:createElementAt(1, 1, 1, 1, "selectedCharacter", self.ui.characterIcons[1])

  self.ui.recordBox = self:createRecordsBox()
  self:refresh()
  self.ui.grid:createElementAt(2, 1, 2, 1, "recordBox", self.ui.recordBox)

  self.ui.panelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "top"})
  self.ui.panelSelection:setTitle("panels")
  local panelCarousel = self:createPanelCarousel(player, self.ui.grid.unitSize - self.ui.grid.unitMargin * 2 - self.ui.panelSelection.height)
  self.ui.panelSelection:addElement(panelCarousel, player)
  self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection)

  local stageCarousel = self:createStageCarousel(player, self.ui.grid.unitSize * 3 - self.ui.grid.unitMargin * 2)
  self.ui.stageSelection = MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  self.ui.stageSelection:setTitle("stage")
  self.ui.stageSelection:addElement(stageCarousel, player)
  self.ui.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.ui.stageSelection)

  self.ui.levelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "top"})
  self.ui.levelSelection:setTitle("level")
  local levelSlider = self:createLevelSlider(player, 20, self.ui.grid.unitSize - self.ui.grid.unitMargin * 2 - self.ui.levelSelection.height)
  local oldOnValueChange = levelSlider.onValueChange
  levelSlider.onValueChange = function(ls)
    oldOnValueChange(ls)
    self.lastScore = GAME.scores:lastVsScoreForLevel(ls.value)
    self.record = GAME.scores:recordVsScoreForLevel(ls.value)
    self.ui.recordBox:setLastLines(self.lastScore)
    self.ui.recordBox:setRecord(self.record)
  end
  self.ui.levelSelection:addElement(levelSlider, player)
  self.ui.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.ui.levelSelection)

  self.ui.readyButton = self:createReadyButton()
  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)

  local characterButtons = self:getCharacterButtons()
  local characterGridWidth, characterGridHeight = 9, 3
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)
  self.ui.grid:createElementAt(1, 3, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)

  self.ui.pageIndicator = self:createPageIndicator(self.ui.characterGrid)
  self.ui.grid:createElementAt(5, 6, 1, 1, "pageIndicator", self.ui.pageIndicator)

  self.ui.pageTurnButtons = self:createPageTurnButtons(self.ui.characterGrid)

  self.ui.leaveButton = self:createLeaveButton()
  self.ui.grid:createElementAt(9, 6, 1, 1, "leaveButton", self.ui.leaveButton)

  self.ui.cursors[1] = self:createCursor(self.ui.grid, player)
  self.ui.cursors[1].raise1Callback = function()
    self.ui.characterGrid:turnPage(-1)
  end
  self.ui.cursors[1].raise2Callback = function()
    self.ui.characterGrid:turnPage(1)
  end
end

function CharacterSelectVsSelf:refresh()
  local level = GAME.battleRoom.players[1].settings.level
  self.lastScore = GAME.scores:lastVsScoreForLevel(level)
  self.record = GAME.scores:recordVsScoreForLevel(level)
  self.ui.recordBox:setLastLines(self.lastScore)
  self.ui.recordBox:setRecord(self.record)
end

return CharacterSelectVsSelf