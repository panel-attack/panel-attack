--@module slider_manager
local slider_manager = {}

local sliders = {}
local next_sliders_id = 0
local selected_slider = nil

function slider_manager.add_slider(slider)
  slider.id = next_sliders_id
  sliders[slider.id] = slider
  next_sliders_id = next_sliders_id + 1
end

function slider_manager.remove_button(slider)
  sliders[slider.id] = nil
end

function slider_manager.draw()
  for id, slider in pairs(sliders) do
    if slider.is_visible then
      slider:draw()
    end
  end
end

function slider_manager.mouseDragged(x, y)
  if selected_slider == nil then
    return
  end
  
  selected_slider:setValue(x - selected_slider.x)
end

function slider_manager.mouseReleased(x, y)
  if selected_slider == nil then
    return
  end

  selected_slider:setValue(x - selected_slider.x)
  selected_slider = nil
end

function slider_manager.mousepressed(x, y)
  for id, slider in pairs(sliders) do
    print(slider.is_visible)
    print(slider:isSelected(x, y))
    if slider.is_visible and slider:isSelected(x, y) then
      selected_slider = slider
      selected_slider:setValue(x - selected_slider.x)
    end
  end
end

return slider_manager