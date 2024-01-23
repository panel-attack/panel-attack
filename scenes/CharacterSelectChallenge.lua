local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local CharacterSelect = require("scenes.CharacterSelect")
local class = require("class")
local MultiPlayerSelectionWrapper = require("ui.MultiPlayerSelectionWrapper")
local Grid = require("ui.Grid")

--@module CharacterSelectChallenge
-- 
local CharacterSelectChallenge = class(
  function (self, sceneParams)
    self:load(sceneParams)
  end,
  CharacterSelect
)

CharacterSelectChallenge.name = "CharacterSelectChallenge"
sceneManager:addScene(CharacterSelectChallenge)

function CharacterSelectChallenge:customLoad(sceneParams)
  self:loadUserInterface()
end

function CharacterSelectChallenge:loadUserInterface()
  self.ui.grid = Grid({unitSize = 96, gridWidth = 9, gridHeight = 6, unitMargin = 6, hAlign = "center", vAlign = "center"})
  self.uiRoot:addChild(self.ui.grid)

  self.ui.panelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "top"})
  self.ui.panelSelection:setTitle("panels")
  self.ui.stageSelection = MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  self.ui.stageSelection:setTitle("stage")
  self.ui.readyButton = self:createReadyButton()
  local characterButtons = self:getCharacterButtons()
  local characterGridWidth, characterGridHeight = self.ui.grid.gridWidth, 3
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)
  self.ui.pageIndicator = self:createPageIndicator(self.ui.characterGrid)
  self.ui.leaveButton = self:createLeaveButton()

  local panelHeight
  local stageWidth

  self.ui.grid:createElementAt(1, 2, 3, 1, "panelSelection", self.ui.panelSelection)
  self.ui.grid:createElementAt(4, 2, 3, 1, "stageSelection", self.ui.stageSelection)

  panelHeight = self.ui.grid.unitSize - self.ui.grid.unitMargin * 2- self.ui.panelSelection.height
  stageWidth = self.ui.grid.unitSize * 1.5 - self.ui.grid.unitMargin * 2
  rankedWidth = stageWidth

  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)
  self.ui.grid:createElementAt(1, 3, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)
  self.ui.grid:createElementAt(5, 6, 1, 1, "pageIndicator", self.ui.pageIndicator)
  self.ui.grid:createElementAt(9, 6, 1, 1, "leaveButton", self.ui.leaveButton)

  self.ui.characterIcons = {}
  for i = 1, #GAME.battleRoom.players do
    local player = GAME.battleRoom.players[i]

    if player.human then
      local panelCarousel = self:createPanelCarousel(player, panelHeight)
      self.ui.panelSelection:addElement(panelCarousel, player)

      local cursor = self:createCursor(self.ui.grid, player)
      cursor.raise1Callback = function()
        self.ui.characterGrid:turnPage(-1)
      end
      cursor.raise2Callback = function()
        self.ui.characterGrid:turnPage(1)
      end
      self.ui.cursors[i] = cursor
    end

    local stageCarousel = self:createStageCarousel(player, stageWidth)
    self.ui.stageSelection:addElement(stageCarousel, player)

    self.ui.characterIcons[i] = self:createPlayerIcon(player)
  end

  self.ui.grid:createElementAt(1, 1, 1, 1, "p1 icon", self.ui.characterIcons[1])
  self.ui.grid:createElementAt(9, 1, 1, 1, "p2 icon", self.ui.characterIcons[2])
end

return CharacterSelectChallenge