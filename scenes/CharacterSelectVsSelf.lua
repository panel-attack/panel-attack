local CharacterSelect = require("scenes.CharacterSelect")
local sceneManager = require("scenes.sceneManager")
local class = require("class")
local GameModes = require("GameModes")
local Grid = require("ui.Grid")
local MultiPlayerSelectionWrapper = require("ui.MultiPlayerSelectionWrapper")

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

  self.ui.characterIcons[1] = self:createSelectedCharacterIcon(player)
  self.ui.grid:createElementAt(1, 1, 1, 1, "selectedCharacter", self.ui.characterIcons[1])

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

function CharacterSelectVsSelf:customUpdate()
end

local lastLinesLabelQuads = {}
local lastLinesQuads = {}
local recordLabelQuads = {}
local recordQuads = {}

function CharacterSelectVsSelf:customDraw()
  local xPosition1 = 196
  local xPosition2 = 320
  local yPosition = 24
  local lastScore = tostring(self.lastScore)
  local record = tostring(self.record)
  draw_pixel_font("last lines", themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition, 0.5, 1.0, nil, nil, lastLinesLabelQuads)
  draw_pixel_font(lastScore,    themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition + 24, 0.5, 1.0, nil, nil, lastLinesQuads)
  draw_pixel_font("record",     themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition, 0.5, 1.0, nil, nil, recordLabelQuads)
  draw_pixel_font(record,       themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition + 24, 0.5, 1.0, nil, nil, recordQuads)
end

return CharacterSelectVsSelf