local class = require("class")
local UiElement = require("ui.UIElement")
local CarouselPassenger = require("ui.CarouselPassenger")
local GraphicsUtil = require("graphics_util")
local Util = require ("util")
local canBeFocused = require("ui.Focusable")
local input = require("inputManager")

local xPadding = 0.05
local yPadding = 0.05

local function calculateFontSize(width, height)
  return 9
end

local StageCarousel = class(function(carousel, options)
  canBeFocused(carousel)

  if options.passengers == nil then
    carousel.passengers = {}
  else
    carousel.passengers = options.passengers
  end
  carousel.selectedId = nil
  if options.selectedId then
    carousel.selectedId = options.selectedId
  else
    carousel.selectedId = 1
  end

  carousel.font = GraphicsUtil.getGlobalFontWithSize(calculateFontSize(carousel.width, carousel.height))
  carousel.leftArrow = love.graphics.newText(carousel.font, "<")
  carousel.rightArrow = love.graphics.newText(carousel.font, ">")
  carousel.TYPE = "Carousel"
end,
UiElement)

function StageCarousel.addPassenger(self, passenger)
  self.passengers[#self.passengers+1] = passenger
end

function StageCarousel.removeSelectedPassenger(self)
  local passenger = self:getSelectedPassenger()
  table.remove(self.passengers, passenger)
  -- selectedId may be out of bounds now
  self.selectedId = Util.wrap(1, self.selectedId, #self.passengers)
end

function StageCarousel.moveToNextPassenger(self, directionSign)
  play_optional_sfx(themes[config.theme].sounds.menu_move)
  self.selectedId = Util.wrap(1, self.selectedId + directionSign, #self.passengers)
end

function StageCarousel.getSelectedPassenger(self)
  return self.passengers[self.selectedId]
end

function StageCarousel.setPassenger(self, passengerId)
  for i = 1, #self.passengers do
    if self.passengers[i].id == passengerId then
      self.selectedId = i
    end
  end
end

function StageCarousel:draw()
  assert(#self.passengers > 0, "This carousel has no passengers!")
  local passenger = self:getSelectedPassenger()
  if passenger.image == nil then
    local phi = 5
  end
  local imgWidth, imgHeight = passenger.image:getDimensions()
  local x, y = self:getScreenPos()
  -- draw the image centered
  GAME.gfx_q:push({love.graphics.draw, {passenger.image, x * (1 + xPadding), y * (1 + yPadding), 0, 80 / imgWidth, 45 / imgHeight, imgWidth / 2, imgHeight / 2}})

  -- text below
  if not passenger.fontText then
    passenger.fontText = love.graphics.newText(self.font, passenger.text)
  end
  GAME.gfx_q:push({love.graphics.draw, {passenger.fontText,  x * (1 + xPadding), y * (1 + yPadding) - 10, 0, 1, 1, math.floor(passenger.fontText:getWidth() / 2), 0}})

  if self.hasFocus then
    GAME.gfx_q:push({love.graphics.draw, {self.leftArrow, x + 2, y + self.height / 2, 0, 1, 1, 0, self.leftArrow:getHeight() / 2}})
    GAME.gfx_q:push({love.graphics.draw, {self.rightArrow, x + self.width - 5, y + self.height / 2, 0, 1, 1, self.rightArrow:getWidth(), self.rightArrow:getHeight() / 2}})
  end
end

-- this should/may be overwritten by the parent
function StageCarousel:onSelect()
  self:onBack()
end

-- this should/may be overwritten by the parent
function StageCarousel:onBack()
  self:yieldFocus()
end


-- the parent makes sure this is only called while focused
function StageCarousel:receiveInputs()
  if input:isPressedWithRepeat("Left", 0.25, 0.25) then
    self:moveToNextPassenger(-1)
  elseif input:isPressedWithRepeat("Right", 0.25, 0.25) then
    self:moveToNextPassenger(1)
  elseif input.isDown["Swap1"] or input.isDown["Start"] then
    play_optional_sfx(themes[config.theme].sounds.menu_enter)
    self:onSelect()
  elseif input.isDown["Swap2"] or input.isDown["Escape"] then
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    self:onBack()
  end

  -- TODO: Interpret touch/mouse inputs
end

-- function StageCarousel.onMove(direction)

-- end

-- function StageCarousel.onSwipe(direction)

-- end

return StageCarousel