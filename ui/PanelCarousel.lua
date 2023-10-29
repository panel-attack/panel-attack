local Carousel = require("ui.Carousel")
local class = require("class")
local GraphicsUtil = require("graphics_util")

local PanelCarousel = class(function(carousel, options)
  carousel.colorCount = 5
end, Carousel)

function PanelCarousel.createPassenger(id)
  return {id = id}
end

function PanelCarousel:drawPassenger()
  local id = self:getSelectedPassenger().id
  local width = panels[id].images.classic[1][1]:getWidth()
  local scale = 1
  if width < 20 then
    scale = 20 / width
    width = 20
  elseif width > 0.25 * self.height then
    scale = (0.25 * self.height) / width
    width = 0.25 * self.height
  end

  local xOffset, yOffset = self:getScreenPos()
  local totalWidth = (self.colorCount + 1) * width
  xOffset = xOffset + (self.width - totalWidth) / 2
  yOffset = yOffset + (self.height - width) / 2

  for i = 1, self.colorCount do
    -- regular colors
    love.graphics.draw(panels[id].images.classic[i][1], xOffset + (i - 1) * width, yOffset, 0, scale, scale)
  end
  -- always draw shock
  love.graphics.draw(panels[id].images.classic[8][1], xOffset + self.colorCount * width, yOffset, 0, scale, scale)

  return xOffset, totalWidth
end

function PanelCarousel:setColorCount(count)
  self.colorCount = count
end

function PanelCarousel:loadPanels()
  for i = 1, #panels_ids do
    local passenger = PanelCarousel.createPassenger(panels_ids[i])
    self:addPassenger(passenger)
  end

  self:setPassenger(config.panels)
end

return PanelCarousel