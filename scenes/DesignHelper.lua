local class = require("class")
local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local Grid = require("ui.Grid")
local GridElement = require("ui.GridElement")
local StageCarousel = require("ui.StageCarousel")
local LevelSlider = require("ui.LevelSlider")
local input = require("inputManager")
local PanelCarousel = require("ui.PanelCarousel")
local PagedUniGrid = require("ui.PagedUniGrid")
local Button = require("ui.Button")
local TextButton = require("ui.TextButton")
local GridCursor = require("ui.GridCursor")
local Focusable = require("ui.Focusable")
local consts = require("consts")
local Label = require("ui.Label")
local StackPanel = require("ui.StackPanel")

local DesignHelper = class(function(self, sceneParams)
  self:load(sceneParams)
end, Scene)

DesignHelper.name = "DesignHelper"
sceneManager:addScene(DesignHelper)

function DesignHelper:load()
  self:loadGrid()
  self:loadPanels()
  self.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.panelCarousel)
end

function DesignHelper:loadGrid()
  self.grid = Grid({x = 180, y = 60, unitSize = 102, gridWidth = 9, gridHeight = 6, unitPadding = 6})
  self.cursor = GridCursor({
    grid = self.grid,
    activeArea = {x1 = 1, y1 = 2, x2 = 9, y2 = 5},
    translateSubGrids = true,
    startPosition = {x = 9, y = 2},
    playerNumber = 1
  })
  self.cursor.escapeCallback = function()
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    sceneManager:switchToScene("MainMenu")
  end
end

function DesignHelper:loadPanels()
  self.panelCarousel = PanelCarousel({hAlign = "center", vAlign = "center", hFill = true, vFill = true})
  self.panelCarousel:loadPanels()
end

function DesignHelper:loadStages()
  self.stageCarousel = StageCarousel({})
  self.stageCarousel:loadCurrentStages()
end

function DesignHelper:drawBackground()
end

function DesignHelper:update()
  self.cursor:receiveInputs()
  if input.allKeys.isDown["6"] then
    self.panelCarousel:setColorCount(self.panelCarousel.colorCount - 1)
  elseif input.allKeys.isDown["7"] then
    self.panelCarousel:setColorCount(self.panelCarousel.colorCount + 1)
  end
  GAME.gfx_q:push({self.grid.draw, {self.grid}})
end

return DesignHelper
