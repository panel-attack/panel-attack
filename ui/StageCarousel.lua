local Carousel = require("ui.Carousel")
local class = require("class")
local GraphicsUtil = require("graphics_util")

local StageCarousel = class(function(carousel, options)

end, Carousel)


function StageCarousel.createPassenger(id, image, text)
  local passenger = {}
  passenger.id = id
  if image then
    passenger.image = image
  else
    passenger.image = themes[config.theme].images.IMG_random_stage
  end
  passenger.text = text
  assert(id and text, "A carousel passenger needs to have an id, an image and a text!")
  return passenger
end

local aspectRatio = {x = 80, y = 45}
function StageCarousel:drawPassenger()
  local passenger = self:getSelectedPassenger()
  local imgWidth, imgHeight = passenger.image:getDimensions()
  local x, y = self:getScreenPos()
  -- draw the image centered
  menu_drawf(passenger.image, (x + self.width / 2), (y + self.height * 0.4), "center", "center", 0, aspectRatio.x / imgWidth, aspectRatio.y / imgHeight)

  -- text below
  -- Sankyr might tell me this should be a label but it's kinda bleh
  if not passenger.fontText then
    passenger.fontText = love.graphics.newText(self.font, passenger.text)
  end
  GraphicsUtil.printText(passenger.fontText, (x + self.width / 2), (y + self.height * 0.75), "center")

  return aspectRatio.x
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