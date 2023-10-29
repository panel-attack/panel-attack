local class = require("class")
local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local Grid = require("ui.Grid")
local GridElement = require("ui.GridElement")
local Carousel = require("ui.Carousel")
local input = require("inputManager")

local DesignHelper = class(function (self, sceneParams)
    self:load(sceneParams)
  end,
  Scene
)

DesignHelper.name = "DesignHelper"
sceneManager:addScene(DesignHelper)

function DesignHelper:load()
  self.backgroundImg = themes[config.theme].images.bg_main
  self.grid = Grid({x = 60, y = 20, unitSize = 34, gridWidth = 9, gridHeight = 6, unitPadding = 2})
  self.grid:createElementAt(1, 1, 1, 1, "selectedCharacter")
  self.grid:createElementAt(1, 2, 2, 1, "panelSelection")
  self:loadStages()
  self.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.stageCarousel)
  self.grid:createElementAt(6, 2, 3, 1, "levelSelection")
  self.grid:createElementAt(9, 2, 1, 1, "readySelection")
  self.grid:createElementAt(1, 3, 9, 3, "characterSelection")
  self.grid:createElementAt(9, 6, 1, 1, "leaveSelection")
end

function DesignHelper:loadStages()
  self.stageCarousel = Carousel({x = 0, y = 0, width = 102, height = 34})
  for i = 1, #stages_ids_for_current_theme do
    local stage = stages[stages_ids_for_current_theme[i]]
    local passenger = Carousel.createPassenger(stage.id, stage.images.thumbnail, stage.display_name)
    self.stageCarousel:addPassenger(passenger)
  end

  local randomStage = Carousel.createPassenger(random_stage_special_value, themes[config.theme].images.IMG_random_stage, loc("random"))
  self.stageCarousel:addPassenger(randomStage)

  self.stageCarousel:setPassenger(config.character)
end

function DesignHelper:drawBackground()
  self.backgroundImg:draw()
  self.grid:draw()
end

function DesignHelper:update()
  if input.isDown["MenuEsc"] then
    sceneManager:switchToScene("MainMenu")
  end
end

return DesignHelper