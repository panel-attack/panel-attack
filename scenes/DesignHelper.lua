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
local GameModes = require("GameModes")

local DesignHelper = class(function(self, sceneParams)
  self:load(sceneParams)
end, Scene)

DesignHelper.name = "DesignHelper"
sceneManager:addScene(DesignHelper)

function DesignHelper:load()
  self:loadGrid()
  self:loadPanels()
  self:loadStages()
  self.grid:createElementAt(1, 2, 2, 1, "stage", self.stageCarousel)
end

function DesignHelper:loadGrid()
  self.grid = Grid({x = 180, y = 60, unitSize = 102, gridWidth = 9, gridHeight = 6, unitMargin = 6})
  self.cursor = GridCursor({
    grid = self.grid,
    activeArea = {x1 = 1, y1 = 2, x2 = 9, y2 = 5},
    translateSubGrids = true,
    startPosition = {x = 9, y = 2},
    playerNumber = 1
  })
  self.cursor.escapeCallback = function()
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
  end
end

function DesignHelper:loadPanels()
  self.panelCarousel = PanelCarousel({hAlign = "center", vAlign = "center", hFill = true, vFill = true})
  self.panelCarousel:loadPanels()
end

function DesignHelper:loadStages()
  self.stageCarousel = StageCarousel({hAlign = "center", vAlign = "center", hFill = true, vFill = true})
  self.stageCarousel:loadCurrentStages()
end

function DesignHelper:update()
  if input.allKeys.isDown["MenuEsc"] then
    sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
  end
end

function DesignHelper:draw()
  self.grid.draw()
end

return DesignHelper
