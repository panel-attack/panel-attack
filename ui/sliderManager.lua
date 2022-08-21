--@module sliderManager
local sliderManager = {
  sliders = {}
}

local selectedSlider = nil

function sliderManager.draw()
  for id, slider in pairs(sliderManager.sliders) do
    slider:draw()
  end
end

function sliderManager.mouseDragged(x, y)
  local canvasX, canvasY = GAME:transform_coordinates(x, y)
  if selectedSlider == nil then
    return
  end
  
  selectedSlider:setValueFromPos(canvasX)
end

function sliderManager.mouseReleased(x, y)
  local canvasX, canvasY = GAME:transform_coordinates(x, y)
  if selectedSlider == nil then
    return
  end

  selectedSlider:setValueFromPos(canvasX)
  selectedSlider = nil
end

function sliderManager.mousePressed(x, y)
  local canvasX, canvasY = GAME:transform_coordinates(x, y)
  for id, slider in pairs(sliderManager.sliders) do
    if slider:isSelected(canvasX, canvasY) then
      selectedSlider = slider
      selectedSlider:setValueFromPos(canvasX)
    end
  end
end

return sliderManager