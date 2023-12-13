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
    self:load()
  end,
  CharacterSelect
)

CharacterSelectVsSelf.name = "VsSelfMenu"
sceneManager:addScene(CharacterSelectVsSelf)

function CharacterSelectVsSelf:customLoad(sceneParams)
  GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.ONE_PLAYER_VS_SELF)
  self:loadUserInterface()
end

function CharacterSelectVsSelf:loadUserInterface()
  local player = GAME.battleRoom.players[1]

  self.ui = {}
  self.ui.grid = Grid({x = 153, y = 60, unitSize = 108, gridWidth = 9, gridHeight = 6, unitMargin = 6})
  self.ui.selectedCharacter = self:createSelectedCharacterIcon(player)
  self.ui.grid:createElementAt(1, 1, 1, 1, "selectedCharacter", self.ui.selectedCharacter)

  self.ui.panelCarousel = self:createPanelCarousel(player)
  self.ui.panelSelection = MultiPlayerSelectionWrapper({hFill = true, vFill = true})
  self.ui.panelSelection:addElement(self.ui.panelCarousel, player)
  self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection)

  self.ui.stageCarousel = self:createStageCarousel(player)
  self.ui.stageSelection = MultiPlayerSelectionWrapper({hFill = true, vFill = true})
  self.ui.stageSelection:addElement(self.ui.stageCarousel, player)
  self.ui.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.ui.stageSelection)

  self.ui.levelSlider = self:createLevelSlider(player, 20)
  self.ui.levelSelection = MultiPlayerSelectionWrapper({hFill = true, vFill = true})
  self.ui.levelSelection:addElement(self.ui.levelSlider, player)
  self.ui.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.ui.levelSelection)

  self.ui.readyButton = self:createReadyButton()
  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)

  local characterButtons = self:getCharacterButtons()
  local characterGridWidth, characterGridHeight = 9, 3
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)
  self.ui.grid:createElementAt(1, 3, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)

  self.ui.leaveButton = self:createLeaveButton()
  self.ui.grid:createElementAt(9, 6, 1, 1, "leaveButton", self.ui.leaveButton)

  self.ui.cursor = self:createCursor(self.ui.grid, player)
  self.ui.cursor.raise1Callback = function()
    self.ui.characterGrid:turnPage(-1)
  end
  self.ui.cursor.raise2Callback = function()
    self.ui.characterGrid:turnPage(1)
  end
  -- we need to refresh the position once so it fetches the current element after all grid elements were loaded in customLoad
  --self.ui.cursor:updatePosition(self.ui.cursor.selectedGridPos.x, self.ui.cursor.selectedGridPos.y)
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
  local lastScore = tostring(GAME.scores:lastVsScoreForLevel(self.ui.levelSlider.value))
  local record = tostring(GAME.scores:recordVsScoreForLevel(self.ui.levelSlider.value))
  draw_pixel_font("last lines", themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition, 0.5, 1.0, nil, nil, lastLinesLabelQuads)
  draw_pixel_font(lastScore,    themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition + 24, 0.5, 1.0, nil, nil, lastLinesQuads)
  draw_pixel_font("record",     themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition, 0.5, 1.0, nil, nil, recordLabelQuads)
  draw_pixel_font(record,       themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition + 24, 0.5, 1.0, nil, nil, recordQuads)
end

return CharacterSelectVsSelf