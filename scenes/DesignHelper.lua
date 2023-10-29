local class = require("class")
local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local Grid = require("ui.Grid")
local GridElement = require("ui.GridElement")
local Carousel = require("ui.Carousel")
local LevelSlider = require("ui.LevelSlider")
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
  self.grid = Grid({x = 180, y = 60, unitSize = 102, gridWidth = 9, gridHeight = 6, unitPadding = 6})
  self.grid:createElementAt(1, 1, 1, 1, "selectedCharacter")
  self.grid:createElementAt(1, 2, 2, 1, "panelSelection")
  self:loadStages()
  self.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.stageCarousel)
  self:loadLevels()
  self.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.levelSlider)
  self.grid:createElementAt(9, 2, 1, 1, "readySelection")
  self.grid:createElementAt(1, 3, 9, 3, "characterSelection")
  self.grid:createElementAt(9, 6, 1, 1, "leaveSelection")
end

function DesignHelper:loadStages()
  self.stageCarousel = Carousel({width = 294, height = 90})
  for i = 1, #stages_ids_for_current_theme do
    local stage = stages[stages_ids_for_current_theme[i]]
    local passenger = Carousel.createPassenger(stage.id, stage.images.thumbnail, stage.display_name)
    self.stageCarousel:addPassenger(passenger)
  end

  local randomStage = Carousel.createPassenger(random_stage_special_value, themes[config.theme].images.IMG_random_stage, loc("random"))
  self.stageCarousel:addPassenger(randomStage)

  self.stageCarousel:setPassenger(config.character)
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