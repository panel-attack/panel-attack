local class = require("class")
local UiElement = require("ui.UIElement")
local ArrowButton = require("ui.ArrowButton")
local GraphicsUtil = require("graphics_util")
local Util = require("util")
local canBeFocused = require("ui.Focusable")
local input = require("inputManager")

local function calculateFontSize(height)
  return math.floor(height / 10) + 1
end

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

function Carousel.createNavigationButtons(self)
  self.leftButton =
    ArrowButton({
      x = - (self.width * 0.05),
      y = self.height * 0.25,
      width = self.width * 0.3,
      height = self.height * 0.5,
      onClick = function()
        self:moveToNextPassenger(-1)
      end,
      text = love.graphics.newText(self.font, "<"),
      parent = self
    })
  self.rightButton =
    ArrowButton({
      x = self.width * 0.75,
      y = self.height * 0.25,
      width = self.width * 0.3,
      height = self.height * 0.5,
      onClick = function()
        self:moveToNextPassenger(1)
      end,
      text = love.graphics.newText(self.font, ">"),
      parent = self
    })
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
end

function Carousel.getSelectedPassenger(self)
  return self.passengers[self.selectedId]
end

function Carousel.setPassenger(self, passengerId)
  for i = 1, #self.passengers do
    if self.passengers[i].id == passengerId then
      self.selectedId = i
    end
  end
end

local aspectRatio = {x = 80, y = 45}
function Carousel:draw()
  assert(#self.passengers > 0, "This carousel has no passengers!")
  local passenger = self:getSelectedPassenger()
  local imgWidth, imgHeight = passenger.image:getDimensions()
  local x, y = self:getScreenPos()
  -- draw the image centered
  menu_drawf(passenger.image, (x + self.width / 2) * GFX_SCALE, (y + self.height / 2) * GFX_SCALE, "center", "center", 0, aspectRatio.x / imgWidth, aspectRatio.y / imgHeight)

  -- text below
  -- Sankyr might tell me this should be a label but it's kinda bleh
  if not passenger.fontText then
    passenger.fontText = love.graphics.newText(self.font, passenger.text)
  end
  GraphicsUtil.printText(passenger.fontText, (x + self.width / 2) * GFX_SCALE, (y + self.height * 0.85) * GFX_SCALE, "center")

  if self.hasFocus then
    self.leftButton:draw()
    self.rightButton:draw()
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

  -- TODO: Interpret touch inputs like swipes
  -- probably needs some groundwork in inputManager though
end

return Carousel