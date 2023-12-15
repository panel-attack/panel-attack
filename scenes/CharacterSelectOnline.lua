local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local CharacterSelect = require("scenes.CharacterSelect")
local class = require("class")
local logger = require("logger")
local Label = require("ui.Label")
local GameModes = require("GameModes")
local Grid = require("ui.Grid")
local MultiPlayerSelectionWrapper = require("ui.MultiPlayerSelectionWrapper")

--@module CharacterSelectOnline
-- 
local CharacterSelectOnline = class(
  function (self, sceneParams)
    
    self.roomInitializationMessage = sceneParams.roomInitializationMessage
    self.players = {{}, {}}
    
    self.transitioning = false
    self.stateParams = {
      maxDisplayTime = nil,
      minDisplayTime = nil,
      sceneName = nil,
      sceneParams = nil,
      switchSceneLabel = nil
    }
    
    self.startTime = love.timer.getTime()
    self.state = nil -- set in customLoad

    self:load(sceneParams)
  end,
  CharacterSelect
)

CharacterSelectOnline.name = "CharacterSelectOnline"
sceneManager:addScene(CharacterSelectOnline)

function CharacterSelectOnline:customLoad(sceneParams)
  if not GAME.battleRoom then
    GAME.battleRoom = sceneParams.battleRoom
  else
    GAME.battleRoom.match = nil
  end
  self:loadUserInterface()
end

function CharacterSelectOnline:loadUserInterface()
  self.ui.grid = Grid({x = 153, y = 60, unitSize = 108, gridWidth = 9, gridHeight = 6, unitMargin = 6})

  self.ui.panelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "center"})
  self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection)

  self.ui.stageSelection = MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  self.ui.grid:createElementAt(5, 2, 2, 1, "stageSelection", self.ui.stageSelection)

  self.ui.levelSelection = MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "center"})
  self.ui.grid:createElementAt(7, 2, 2, 1, "levelSelection", self.ui.levelSelection)

  self.ui.readyButton = self:createReadyButton()
  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)

  local characterButtons = self:getCharacterButtons()
  local characterGridWidth, characterGridHeight = 9, 3
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)
  self.ui.grid:createElementAt(1, 3, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)

  self.ui.leaveButton = self:createLeaveButton()
  self.ui.grid:createElementAt(9, 6, 1, 1, "leaveButton", self.ui.leaveButton)

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