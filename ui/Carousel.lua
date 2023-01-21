local class = require("class")
local UiElement = require("ui.UIElement")
local Button = require("ui.Button")
local CarouselPassenger = require("ui.CarouselPassenger")
local GraphicsUtil = require("graphics_util")
local Util = require("util")
local canBeFocused = require("ui.Focusable")
local input = require("inputManager")

local function calculateFontSize(width, height)
  return math.floor(height / 10) + 1
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
  carousel:createNavigationButtons()

  carousel.TYPE = "Carousel"
end, UiElement)

function StageCarousel.createNavigationButtons(self)
  self.leftButton =
    Button({
      x = self.width * 0.05,
      y = self.height * 0.5,
      width = self.width * 0.3,
      height = self.height * 0.5,
      halign = "center",
      valign = "center",
      onClick = function()
        self:moveToNextPassenger(-1)
      end,
      text = love.graphics.newText(self.font, "<"),
      parent = self
    })
  self.rightButton =
    Button({
      x = self.width * 0.75,
      y = self.height * 0.5,
      width = self.width * 0.3,
      height = self.height * 0.5,
      halign = "center",
      valign = "center",
      onClick = function()
        self:moveToNextPassenger(1)
      end,
      text = love.graphics.newText(self.font, ">"),
      parent = self
    })
end

function StageCarousel.addPassenger(self, passenger)
  self.passengers[#self.passengers + 1] = passenger
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

local aspectRatio = {x = 80, y = 45}
function StageCarousel:draw()
  assert(#self.passengers > 0, "This carousel has no passengers!")
  local passenger = self:getSelectedPassenger()
  local imgWidth, imgHeight = passenger.image:getDimensions()
  local x, y = self:getScreenPos()
  -- draw the image centered
  menu_drawf(passenger.image, x + self.width / 2, y + self.height / 2, "center", "center", 0, aspectRatio.x / imgWidth, aspectRatio.y / imgHeight)

  -- text below
  -- Sankyr might tell me this should be a label but it's kinda bleh
  if not passenger.fontText then
    passenger.fontText = love.graphics.newText(self.font, passenger.text)
  end
  GraphicsUtil.printText(passenger.fontText, x + self.width / 2, y + self.height * 0.85, "center")

  if self.hasFocus then
    self.leftButton:draw()
    self.rightButton:draw()
  end

  -- because i'm graphics dumb, draw borders around the thing
  grectangle("line", x, y, self.width, self.height)
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
