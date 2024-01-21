local CharacterSelect = require("scenes.CharacterSelect")
local sceneManager = require("scenes.sceneManager")
local class = require("class")
local GameModes = require("GameModes")
local Grid = require("ui.Grid")
local MultiPlayerSelectionWrapper = require("ui.MultiPlayerSelectionWrapper")
local UiElement = require("ui.UIElement")
local PixelFontLabel = require("ui.PixelFontLabel")
local StackPanel = require("ui.StackPanel")

--@module CharacterSelectVsSelf
-- The character select screen scene
local CharacterSelectVsSelf = class(
  function (self, sceneParams)
    self.lastScore = nil
    self.record = nil
    self:load()
  end,
  CharacterSelect
)

CharacterSelectVsSelf.name = "CharacterSelectVsSelf"
sceneManager:addScene(CharacterSelectVsSelf)

function CharacterSelectVsSelf:customLoad(sceneParams)
  self:loadUserInterface()
end

function CharacterSelectVsSelf:loadUserInterface()
  local player = GAME.battleRoom.players[1]

  self.ui.grid = Grid({x = 153, y = 60, unitSize = 108, gridWidth = 9, gridHeight = 6, unitMargin = 6})
  self.uiRoot:addChild(self.ui.grid)

  self.ui.characterIcons[1] = self:createPlayerIcon(player)
  self.ui.grid:createElementAt(1, 1, 1, 1, "selectedCharacter", self.ui.characterIcons[1])

  self.ui.recordBox = self:createRecordsBox()
  self.ui.grid:createElementAt(2, 1, 2, 1, "recordBox", self.ui.recordBox)

  local panelCarousel = self:createPanelCarousel(player, 96)
  self.ui.panelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "center"})
  self.ui.panelSelection:addElement(panelCarousel, player)
  self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection)

  local stageCarousel = self:createStageCarousel(player, self.ui.grid.unitSize * 3 - self.ui.grid.unitMargin * 2)
  self.ui.stageSelection = MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  self.ui.stageSelection:addElement(stageCarousel, player)
  self.ui.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.ui.stageSelection)

  local levelSlider = self:createLevelSlider(player, 20)
  local oldOnValueChange = levelSlider.onValueChange
  levelSlider.onValueChange = function(ls)
    oldOnValueChange(ls)
    self.lastScore = GAME.scores:lastVsScoreForLevel(ls.value)
    self.record = GAME.scores:recordVsScoreForLevel(ls.value)
    self.ui.recordBox:setLastLines(self.lastScore)
    self.ui.recordBox:setRecord(self.record)
  end
  self.ui.levelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "center"})
  self.ui.levelSelection:addElement(levelSlider, player)
  self.ui.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.ui.levelSelection)

  self.ui.readyButton = self:createReadyButton()
  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)

  local characterButtons = self:getCharacterButtons()
  local characterGridWidth, characterGridHeight = 9, 3
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)
  self.ui.grid:createElementAt(1, 3, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)

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

function CharacterSelectVsSelf:createRecordsBox()
  local level = GAME.battleRoom.players[1].settings.level
  self.lastScore = GAME.scores:lastVsScoreForLevel(level)
  self.record = GAME.scores:recordVsScoreForLevel(level)

  local stackPanel = StackPanel({alignment = "top", hFill = true, vAlign = "center"})

  local lastLines = UiElement({hFill = true})
  local lastLinesLabel = PixelFontLabel({ text = "last lines", xScale = 0.5, yScale = 1, hAlign = "left", x = 20})
  local lastLinesValue = PixelFontLabel({ text = self.lastScore, xScale = 0.5, yScale = 1, hAlign = "right", x = -20})
  lastLines.height = lastLinesLabel.height + 4
  lastLines.label = lastLinesLabel
  lastLines.value = lastLinesValue
  lastLines:addChild(lastLinesLabel)
  lastLines:addChild(lastLinesValue)
  stackPanel.lastLines = lastLines
  stackPanel:addElement(lastLines)

  local record = UiElement({hFill = true})
  local recordLabel = PixelFontLabel({ text = "record", xScale = 0.5, yScale = 1, hAlign = "left", x = 20})
  local recordValue = PixelFontLabel({ text = self.record, xScale = 0.5, yScale = 1, hAlign = "right", x = -20})
  record.height = recordLabel.height + 4
  record.label = recordLabel
  record.value = recordValue
  record:addChild(recordLabel)
  record:addChild(recordValue)
  stackPanel.record = record
  stackPanel:addElement(record)

  stackPanel.setLastLines = function(stackPanel, value)
    stackPanel.lastLines.value:setText(value)
  end

  stackPanel.setRecord = function(stackPanel, value)
    stackPanel.record.value:setText(value)
  end

  return stackPanel
end

local lastLinesLabelQuads = {}
local lastLinesQuads = {}
local recordLabelQuads = {}
local recordQuads = {}

function CharacterSelectVsSelf:customDraw()
  -- local xPosition1 = 196
  -- local xPosition2 = 320
  -- local yPosition = 24
  -- local lastScore = tostring(self.lastScore)
  -- local record = tostring(self.record)
  -- draw_pixel_font("last lines", themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition, 0.5, 1.0, nil, nil, lastLinesLabelQuads)
  -- draw_pixel_font(lastScore,    themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition + 24, 0.5, 1.0, nil, nil, lastLinesQuads)
  -- draw_pixel_font("record",     themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition, 0.5, 1.0, nil, nil, recordLabelQuads)
  -- draw_pixel_font(record,       themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition + 24, 0.5, 1.0, nil, nil, recordQuads)
end

return CharacterSelectVsSelf