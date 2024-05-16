local class = require("class")
local UiElement = require("ui.UIElement")
local GraphicsUtil = require("graphics_util")
local canBeFocused = require("ui.Focusable")
local tableUtils = require("tableUtils")

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

  carousel.initialTouchX = 0
  carousel.initialTouchY = 0
  carousel.swiping = false

  carousel.TYPE = "Carousel"
end, UiElement)

function Carousel:createPassenger(id, uiElement)
  error("Each specific carousel needs to implement its own passenger")
  -- passengers are expected to have an id property with a unique identifier
  -- passengers are expected to have a uiElement property for being drawn
end

function Carousel.addPassenger(self, passenger)
  self.passengers[#self.passengers + 1] = passenger
  self:addChild(passenger.uiElement)
  passenger.uiElement:setVisibility(false)
end

function Carousel.removeSelectedPassenger(self)
  local passenger = self:getSelectedPassenger()
  table.remove(self.passengers, passenger)
  -- selectedId may be out of bounds now
  self.selectedId = wrap(1, self.selectedId, #self.passengers)
end

function Carousel.moveToNextPassenger(self, directionSign)
  GAME.theme:playMoveSfx()
  self.passengers[self.selectedId].uiElement:setVisibility(false)
  self.selectedId = wrap(1, self.selectedId + directionSign, #self.passengers)
  self.passengers[self.selectedId].uiElement:setVisibility(true)
  self:onPassengerUpdate()
end

function Carousel.getSelectedPassenger(self)
  return self.passengers[self.selectedId]
end

function Carousel.setPassengerById(self, passengerId)
  local passenger = tableUtils.first(self.passengers, function(passenger) return passenger.id == passengerId end)
  if passenger then
    self:setPassengerByIndex(tableUtils.indexOf(self.passengers, passenger))
  end
end

function Carousel.setPassengerByIndex(self, index)
  self.passengers[self.selectedId].uiElement:setVisibility(false)
  self.selectedId = index
  self.passengers[index].uiElement:setVisibility(true)
  self:onPassengerUpdate()
end

function Carousel:drawSelf()
  if DEBUG_ENABLED then
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
  end
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
function Carousel:receiveInputs(inputs)
  if inputs:isPressedWithRepeat("Left", 0.25, 0.25) then
    self:moveToNextPassenger(-1)
  elseif inputs:isPressedWithRepeat("Right", 0.25, 0.25) then
    self:moveToNextPassenger(1)
  elseif inputs.isDown["Swap1"] or inputs.isDown["Start"] then
    GAME.theme:playValidationSfx()
    self:onSelect()
  elseif inputs.isDown["Swap2"] or inputs.isDown["Escape"] then
    GAME.theme:playCancelSfx()
    self:onBack()
  end
end

-- TODO: Interpret touch inputs such as swipes
-- probably needs some groundwork in inputManager though
function Carousel:onTouch(x, y)
  self.swiping = true
  self.initialTouchX = x
  self.initialTouchY = y
  self.initialTouchPassenger = self.selectedId
end

function Carousel:onDrag(x, y)
  -- let's say 40 pixels are 1 stage
  local indexOffset = math.floor((x - self.initialTouchX) / 40)
  local direction = math.sign(indexOffset)
  local passengerIndex = self.initialTouchPassenger
  for i = self.initialTouchPassenger, self.initialTouchPassenger + (indexOffset - 1), direction do
    passengerIndex = wrap(1, passengerIndex + direction, #self.passengers)
  end
  if passengerIndex ~= self.selectedId then
    self:setPassengerByIndex(passengerIndex)
  end
end

function Carousel:onRelease(x, y)
  self:onDrag(x, y)
  self.swiping = false
  self.initialTouchX = 0
  self.initialTouchY = 0
  self.initialTouchPassenger = nil
end

return Carousel