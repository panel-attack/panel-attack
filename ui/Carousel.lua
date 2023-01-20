local class = require("class")
local UiElement = require("ui.UIElement")
local CarouselPassenger = require("ui.CarouselPassenger")

local StageCarousel = class(function(carousel, options)
  if options.passengers == nil then
    error("Carousels are no fun without passengers")
  end
  carousel.passengers = options.passengers
  carousel.selected = nil
  if options.selected then
    carousel.selected = options.selected
  else
    carousel.selected = 1
  end
end,
UiElement)

function StageCarousel.moveToNextPassenger(self, directionSign)
  play_optional_sfx(themes[config.theme].sounds.menu_move)
  self.selected = bound(1, self.selected + directionSign, #self.passengers)
end

function StageCarousel:draw()
  local passenger = self.passengers[self.selected]
  local imgDimensions = passenger.image:getDimensions()

  GAME.gfx_q:push({love.graphics.draw, {passenger.image, self.x + 5, self.y + 5, 0, stage_dims[1] / img:getWidth(), stage_dims[2] / img:getHeight(), img:getWidth() / 2, img:getHeight() / 2}})
  GAME.gfx_q:push({love.graphics.draw, {img, stage_button.x + stage_button.width / 2, stage_button.y + stage_button.height / 2, 0, stage_dims[1] / img:getWidth(), stage_dims[2] / img:getHeight(), img:getWidth() / 2, img:getHeight() / 2}})

end

function StageCarousel:onSelect()

end

function StageCarousel:onBack()

end

function StageCarousel.onMove(direction)

end

function StageCarousel.onSwipe(direction)

end

return StageCarousel

