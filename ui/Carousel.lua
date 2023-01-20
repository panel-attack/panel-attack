local class = require("class")
local UiElement = require("ui.UIElement")
local CarouselPassenger = require("ui.CarouselPassenger")
local GraphicsUtil = require("graphics_util")

local xPadding = 0.05
local yPadding = 0.05

local function calculateFontSize(width, height)
  return 9
end

local StageCarousel = class(function(carousel, options)
  if options.passengers == nil then
    options.passengers = {}
  else
    carousel.passengers = options.passengers
  end
  carousel.selected = nil
  if options.selected then
    carousel.selected = options.selected
  else
    carousel.selected = 1
  end

  carousel.font = GraphicsUtil.getGlobalFontWithSize(calculateFontSize(carousel.width, carousel.height))
  carousel.leftArrow = love.graphics.newText(carousel.font, "<")
  carousel.rightArrow = love.graphics.newText(carousel.font, ">")
  carousel.TYPE = "Carousel"
end,
UiElement)

function StageCarousel.addPassenger(self, id, image, text)
  local passenger = CarouselPassenger(id, image, text)
  self.passengers[#self.passengers+1] = passenger
end

function StageCarousel.removeSelectedPassenger(self)
  local passenger = self.passengers[self.selected]
  table.remove(self.passengers, passenger)
  -- selected may be out of bounds now
  self.selected = bound(1, self.selected, #self.passengers)
end

function StageCarousel.moveToNextPassenger(self, directionSign)
  play_optional_sfx(themes[config.theme].sounds.menu_move)
  self.selected = bound(1, self.selected + directionSign, #self.passengers)
end

function StageCarousel:draw()
  assert(#self.passengers == 0, "This carousel has no passengers!")
  local passenger = self.passengers[self.selected]
  local imgWidth, imgHeight = passenger.image:getDimensions()
  -- draw the image centered
  GAME.gfx_q:push({love.graphics.draw, {passenger.image, self.x * xPadding, self.y * yPadding, 0, 80 / imgWidth, 45 / imgHeight, imgWidth / 2, imgHeight / 2}})

  -- text below
  if not passenger.fontText then
    passenger.fontText = love.graphics.newText(self.font, passenger.text)
  end
  GAME.gfx_q:push({love.graphics.draw, {passenger.fontText, self.x * xPadding, self.y * yPadding - 10, 0, 1, 1, math.floor(passenger.fontText:getWidth() / 2), 0}})

  if self.hasFocus then
    GAME.gfx_q:push({love.graphics.draw, {self.leftArrow, self.x + 2, self.height / 2, 0, 1, 1, 0, self.leftArrow:getHeight() / 2}})
    GAME.gfx_q:push({love.graphics.draw, {self.rightArrow, self.x - 5, self.height / 2, 0, 1, 1, self.rightArrow:getWidth(), self.rightArrow:getHeight() / 2}})
  end
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

