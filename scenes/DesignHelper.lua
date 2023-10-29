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

local DesignHelper = class(function(self, sceneParams)
  self:load(sceneParams)
end, Scene)

DesignHelper.name = "DesignHelper"
sceneManager:addScene(DesignHelper)

function DesignHelper:load()
  self.backgroundImg = themes[config.theme].images.bg_main
  self.grid = Grid({x = 180, y = 60, unitSize = 102, gridWidth = 9, gridHeight = 6, unitPadding = 6})
  -- this is just for demo purposes, current character should always bind to the underlying matchsetup
  self.selectedCharacter = Button({width = 96, height = 96, image = characters[config.character].images.icon})
  self.grid:createElementAt(1, 1, 1, 1, "selectedCharacter", self.selectedCharacter)
  self:loadPanels()
  self.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.panelCarousel)
  self:loadStages()
  self.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.stageCarousel)
  self:loadLevels()
  self.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.levelSlider)
  self.readyButton = Button({width = 96, height = 96, label = "ready"})
  self.grid:createElementAt(9, 2, 1, 1, "readySelection", self.readyButton)
  self:loadCharacters()
  self.grid:createElementAt(1, 3, 9, 3, "characterSelection", self.characterGrid, true)
  -- the character grid has its own padding so override the padding of the enveloping grid
  self.characterGrid.x = 0
  self.characterGrid.y = 0
  self.leaveButton = Button({width = 96, height = 96, label = "leave"})
  self.grid:createElementAt(9, 6, 1, 1, "leaveSelection", self.leaveButton)
end

function DesignHelper:loadPanels()
  self.panelCarousel = PanelCarousel({})
  self.panelCarousel:loadPanels()
end

function DesignHelper:loadStages()
  self.stageCarousel = StageCarousel({})
  self.stageCarousel:loadCurrentStages()
end

function DesignHelper:loadLevels()
  self.levelSlider = LevelSlider({
    tickLength = 20,
    -- (gridElement width - tickLength * #levels) / 2
    x = 37,
    -- 10 is tickLength / 2, level images are forced into squares
    y = (self.grid.unitSize) / 2 - 10 - self.grid.unitPadding,
    value = config.level or 5,
    onValueChange = function(s)
      play_optional_sfx(themes[config.theme].sounds.menu_move)
    end
  })
end

function DesignHelper:loadCharacters()
  self.characterGrid = PagedUniGrid({x = 0, y = 0, unitSize = 102, gridWidth = 9, gridHeight = 3, unitPadding = 6})
  for i = 1, #characters_ids_for_current_theme do
    local characterButton = Button({image = characters[characters_ids_for_current_theme[i]].images.icon, width = 96, height = 96})
    self.characterGrid:addElement(characterButton)
  end
end

function DesignHelper:drawBackground()
  self.backgroundImg:draw()
  GAME.gfx_q:push({self.grid.draw, {self.grid}})
end

function DesignHelper:update()
  if input.isDown["MenuEsc"] then
    sceneManager:switchToScene("MainMenu")
  end
end

return DesignHelper
