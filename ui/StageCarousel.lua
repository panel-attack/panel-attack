local Carousel = require("ui.Carousel")
local class = require("class")
local StackPanel = require("ui.StackPanel")
local Label = require("ui.Label")
local ImageContainer = require("ui.ImageContainer")

local StageCarousel = class(function(carousel, options)

end, Carousel)


function StageCarousel:createPassenger(id, image, text)
  local passenger = {}
  passenger.id = id
  passenger.uiElement = StackPanel({alignment = "top", hFill = true, hAlign = "center", vAlign = "center"})
  passenger.image = ImageContainer({image = image, vAlign = "top", hAlign = "center", drawBorders = true, width = 80, height = 45})
  passenger.uiElement:addElement(passenger.image)
  passenger.label = Label({text = text, translate = false, hAlign = "center"})
  passenger.uiElement:addElement(passenger.label)
  return passenger
end

function StageCarousel:loadCurrentStages()
  for i = 1, #stages_ids_for_current_theme do
    local stage = stages[stages_ids_for_current_theme[i]]
    local passenger = StageCarousel:createPassenger(stage.id, stage.images.thumbnail, stage.display_name)
    self:addPassenger(passenger)
  end

  local randomStage = StageCarousel:createPassenger(random_stage_special_value, themes[config.theme].images.IMG_random_stage, "random")
  self:addPassenger(randomStage)

  self:setPassengerById(config.stage)
end

return StageCarousel