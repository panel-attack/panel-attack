local class = require("class")
local replay_browser = require("replay_browser")
local logger = require("logger")
local options = require("options")
local utf8 = require("utf8")
local analytics = require("analytics")
local main_config_input = require("config_inputs")
local ServerQueue = require("ServerQueue")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local scene_manager = require("scenes.scene_manager")
local input = require("inputManager")

local function updatePos(self, x, y)
  self.x = x
  self.y = y
  local prev_y = y
  for i, menu_item in ipairs(self.menu_items) do
    for j, ui_element in ipairs(menu_item) do
      ui_element.x = j == 1 and x or (menu_item[j - 1].x + menu_item[j - 1].width + 10)
      ui_element.y = prev_y
      if ui_element.TYPE == "ButtonGroup" then
        ui_element:setPos(ui_element.x, ui_element.y)
      elseif ui_element.TYPE == "Stepper" then
        ui_element:setPos(ui_element.x, ui_element.y)
      end
    end
    prev_y = prev_y + menu_item[1].height + 5
  end
end

--@module MainMenu
local Menu = class(
  function(self, menu_items, options)
    self.menu_items = menu_items
    self.x = options.x or 0
    self.y = options.y or 0
    self.selected_id = 1
    updatePos(self, self.x, self.y)
  end
)

local font = love.graphics.getFont()
local arrow = love.graphics.newText(font, ">")

Menu.updatePos = updatePos

function Menu:updateLabel()
  for i, menu_item in ipairs(self.menu_items) do
    for j, ui_element in ipairs(menu_item) do
      ui_element:updateLabel()
    end
  end
end

function Menu:setVisibility(is_visible)
  for i, menu_item in ipairs(self.menu_items) do
    for j, ui_element in ipairs(menu_item) do
      ui_element:setVisibility(is_visible)
    end
  end
end

function Menu:update()
  if input:isPressedWithRepeat("Up", .25, .05) then
    self.selected_id = ((self.selected_id - 2) % #self.menu_items) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end
  
  if input:isPressedWithRepeat("Down", .25, .05) then
    self.selected_id = (self.selected_id % #self.menu_items) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end

  if input:isPressedWithRepeat("Left", .25, .05) then
    if self.menu_items[self.selected_id][2] then
      if self.menu_items[self.selected_id][2].TYPE == "Slider" then
        local slider = self.menu_items[self.selected_id][2]
        slider:setValue(slider.value - 1)
      end
      if self.menu_items[self.selected_id][2].TYPE == "ButtonGroup" then
        local button_group = self.menu_items[self.selected_id][2]
        button_group:setActiveButton(button_group.selected_index - 1)
      end
      if self.menu_items[self.selected_id][2].TYPE == "Stepper" then
        local dynamic_button_group = self.menu_items[self.selected_id][2]
        dynamic_button_group:setState(dynamic_button_group.selected_index - 1)
      end
    end
  end

  if input:isPressedWithRepeat("Right", .25, .05) then
    if self.menu_items[self.selected_id][2] then
      if self.menu_items[self.selected_id][2].TYPE == "Slider" then
        local slider = self.menu_items[self.selected_id][2]
        slider:setValue(slider.value + 1)
      end
      if self.menu_items[self.selected_id][2].TYPE == "ButtonGroup" then
        local button_group = self.menu_items[self.selected_id][2]
        button_group:setActiveButton(button_group.selected_index + 1)
      end
      if self.menu_items[self.selected_id][2].TYPE == "Stepper" then
        local dynamic_button_group = self.menu_items[self.selected_id][2]
        dynamic_button_group:setState(dynamic_button_group.selected_index + 1)
      end
    end
  end
  
  if input.isDown["Start"] or input.isDown["Swap1"]  then
    if self.menu_items[self.selected_id][1].TYPE == "Button" then
      self.menu_items[self.selected_id][1].onClick()
    end
  end
  
  if input.isDown["Swap2"] then
    if self.selected_id ~= #self.menu_items then
      self.selected_id = #self.menu_items
      play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    else
      self.menu_items[self.selected_id][1].onClick()
    end
  end
end

function Menu:draw()
  local animationX = (math.cos(6 * love.timer.getTime()) * 5) - 9
  local arrowx = self.menu_items[self.selected_id][1].x - 10 + animationX
  local arrowy = self.menu_items[self.selected_id][1].y + self.menu_items[self.selected_id][1].height / 4
  GAME.gfx_q:push({love.graphics.draw, {arrow, arrowx, arrowy, 0, 1, 1, 0, 0}})
  
  for i, menu_item in ipairs(self.menu_items) do
    for j, ui_element in ipairs(menu_item) do
      if ui_element.TYPE == "Label" then
        ui_element:draw()
      elseif ui_element.TYPE == "Stepper" then
        ui_element:draw()
      end
    end
  end
end

return Menu