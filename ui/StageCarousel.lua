local Carousel = require("ui.Carousel")
local class = require("class")
local GraphicsUtil = require("graphics_util")

local StageCarousel = class(function(carousel, options)

end, Carousel)


function StageCarousel:createPassenger(id, image, text)
  local passenger = {}
  passenger.id = id
  if image then
    passenger.image = image
  else
    passenger.image = themes[config.theme].images.IMG_random_stage
  end
  passenger.text = text
  --assert(id and text, "A carousel passenger needs to have an id, an image and a text!")
  return passenger
end

function StageCarousel:loadCurrentStages()
  for i = 1, #stages_ids_for_current_theme do
    local stage = stages[stages_ids_for_current_theme[i]]
    local passenger = StageCarousel.createPassenger(stage.id, stage.images.thumbnail, stage.display_name)
    self:addPassenger(passenger)
  end

  local randomStage = StageCarousel.createPassenger(random_stage_special_value, themes[config.theme].images.IMG_random_stage, loc("random"))
  self:addPassenger(randomStage)

  self:setPassenger(config.stage)
end

return StageCarousel