local Carousel = require("client.src.ui.Carousel")
local class = require("common.lib.class")
local StackPanel = require("client.src.ui.StackPanel")
local Label = require("client.src.ui.Label")
local ImageContainer = require("client.src.ui.ImageContainer")
local consts = require("common.engine.consts")
local Stage = require("client.src.mods.Stage")

local StageCarousel = class(function(carousel, options)

end, Carousel)


function StageCarousel:createPassenger(id, image, text)
  local passenger = {}
  passenger.id = id
  passenger.uiElement = StackPanel({alignment = "top", hFill = true, hAlign = "center", vAlign = "center", y = 4})
  passenger.image = ImageContainer({image = image, vAlign = "top", hAlign = "center", drawBorders = true, width = 80, height = 45})
  passenger.uiElement:addElement(passenger.image)
  passenger.label = Label({text = text, translate = id == consts.RANDOM_STAGE_SPECIAL_VALUE, hAlign = "center"})
  passenger.uiElement:addElement(passenger.label)
  return passenger
end

function StageCarousel:loadCurrentStages()
  for i = 0, #stages_ids_for_current_theme do
    local stage
    if i == 0 then
      stage = Stage.getRandomStage()
    else
      stage = stages[stages_ids_for_current_theme[i]]
    end

    local passenger = StageCarousel:createPassenger(stage.id, stage.images.thumbnail, stage.display_name)
    self:addPassenger(passenger)
  end

  self:setPassengerById(config.stage)
end

return StageCarousel