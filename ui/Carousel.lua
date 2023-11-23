local class = require("class")
local UiElement = require("ui.UIElement")
local CarouselButton = require("ui.CarouselButton")
local GraphicsUtil = require("graphics_util")
local canBeFocused = require("ui.Focusable")
local input = require("inputManager")

local function calculateFontSize(height)
  return math.floor(height / 2) + 1
end

-- A carousel with arrow touch buttons that allows to spin a selection of elements around in both directions
-- This is an "abstract" class, classes should inherit this and overwrite createPassenger and drawPassenger
local Carousel = class(function(carousel, options)
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

  carousel.font = GraphicsUtil.getGlobalFontWithSize(calculateFontSize(carousel.height))
  carousel:createNavigationButtons()

  carousel.TYPE = "Carousel"
end, UiElement)

function Carousel.createPassenger(id, image, text)
  error("Each specific carousel needs to implement its own passenger")
end

function Carousel.createNavigationButtons(self)
  self.leftButton =
    CarouselButton({
      direction = "left",
      onClick = function()
        self:moveToNextPassenger(-1)
      end,
      text = love.graphics.newText(self.font, "<")
    })
  self.rightButton =
    CarouselButton({
      direction = "right",
      onClick = function()
        self:moveToNextPassenger(1)
      end,
      text = love.graphics.newText(self.font, ">")
    })
  self:addChild(self.leftButton)
  self:addChild(self.rightButton)
end

function Carousel.addPassenger(self, passenger)
  self.passengers[#self.passengers + 1] = passenger
end

function Carousel.removeSelectedPassenger(self)
  local passenger = self:getSelectedPassenger()
  table.remove(self.passengers, passenger)
  -- selectedId may be out of bounds now
  self.selectedId = wrap(1, self.selectedId, #self.passengers)
end

function Carousel.moveToNextPassenger(self, directionSign)
  play_optional_sfx(themes[config.theme].sounds.menu_move)
  self.selectedId = wrap(1, self.selectedId + directionSign, #self.passengers)
  self:onPassengerUpdate()
end

function Carousel.getSelectedPassenger(self)
  return self.passengers[self.selectedId]
end

function Carousel.setPassenger(self, passengerId)
  for i = 1, #self.passengers do
    if self.passengers[i].id == passengerId then
      self.selectedId = i
      self:onPassengerUpdate()
    end
  end
end

function Carousel:draw()
  assert(#self.passengers > 0, "This carousel has no passengers!")
  local x, y = self:getScreenPos()
  grectangle("line", x, y, self.width, self.height)

  local width = self:drawPassenger()
  self.leftButton:updatePosition(width)
  self.rightButton:updatePosition(width)

  if self.hasFocus or config.inputMethod == "touch" or DEBUG_ENABLED then
    self.leftButton:draw()
    self.rightButton:draw()
  end
end

-- drawPassenger should return the x,y,width,height the passenger takes up centered in the carousel
function Carousel:drawPassenger()
  error("each specific carousel needs to draw its own specific passenger")
end

function Carousel:onPassengerUpdate()
  if self.onPassengerUpdateCallback then
    self:onPassengerUpdateCallback()
  end
end

-- this should/may be overwritten by the parent
function Carousel:onSelect()
  if self.onSelectCallback then
    self.onSelectCallback()
  end
  self:yieldFocus()
end

-- this should/may be overwritten by the parent
function Carousel:onBack()
  if self.onBackCallback then
    self.onBackCallback()
  end
  self:yieldFocus()
end

-- the parent makes sure this is only called while focused
function Carousel:receiveInputs()
  if input:isPressedWithRepeat("Left", 0.25, 0.25) then
    self:moveToNextPassenger(-1)
  elseif input:isPressedWithRepeat("Right", 0.25, 0.25) then
    self:moveToNextPassenger(1)
  elseif input.isDown["Swap1"] or input.isDown["Start"] then
    play_optional_sfx(themes[config.theme].sounds.menu_validate)
    self:onSelect()
  elseif input.isDown["Swap2"] or input.isDown["Escape"] then
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    self:onBack()
  end

  -- TODO: Interpret touch inputs such as swipes
  -- probably needs some groundwork in inputManager though
end

return Carousel