local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local Grid = require("client.src.ui.Grid")
local StageCarousel = require("client.src.ui.StageCarousel")
local input = require("common.lib.inputManager")
local PanelCarousel = require("client.src.ui.PanelCarousel")
local Label = require("client.src.ui.Label")
local StackPanel = require("client.src.ui.StackPanel")
local BoolSelector = require("client.src.ui.BoolSelector")

local DesignHelper = class(function(self, sceneParams)
  self:load(sceneParams)
end, Scene)

DesignHelper.name = "DesignHelper"

function DesignHelper:load()
  self:loadGrid()
  --self:loadPanels()
  --self:loadStages()
  --self.grid:createElementAt(1, 2, 2, 1, "stage", self.stageCarousel)
  self.rankedSelection = StackPanel({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  local trueLabel = Label({text = "ss_ranked", vAlign = "top", hAlign = "center"})
  local falseLabel = Label({text = "ss_casual", vAlign = "bottom", hAlign = "center"})
  self.rankedSelection:addChild(trueLabel)
  self.rankedSelection:addChild(falseLabel)
  self.grid:createElementAt(3, 2, 2, 1, "ranked", self.rankedSelection)
  self.rankedSelection:addElement(self:loadRankedSelection(96))
  self.rankedSelection:addElement(self:loadRankedSelection(96))
end

function DesignHelper:loadGrid()
  self.grid = Grid({x = 180, y = 60, unitSize = 108, gridWidth = 9, gridHeight = 6, unitMargin = 6})
  self.uiRoot:addChild(self.grid)
  -- self.cursor = GridCursor({
  --   grid = self.grid,
  --   activeArea = {x1 = 1, y1 = 2, x2 = 9, y2 = 5},
  --   translateSubGrids = true,
  --   startPosition = {x = 9, y = 2},
  --   playerNumber = 1
  -- })
  -- self.uiRoot:addChild(self.cursor)
  -- self.cursor.escapeCallback = function()
  --   SoundController:playSfx(themes[config.theme].sounds.menu_cancel)
  -- end
end

function DesignHelper:loadRankedSelection(width)
  local rankedSelector = BoolSelector({startValue = true, vFill = true, width = width, vAlign = "center", hAlign = "center"})

  return rankedSelector
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
    GAME.navigationStack:pop()
  end
end

function DesignHelper:draw()
  self.grid:draw()
end

return DesignHelper
