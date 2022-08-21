local class = require("class")
local replay_browser = require("replay_browser")
local logger = require("logger")
local options = require("options")
local utf8 = require("utf8")
local analytics = require("analytics")
local main_config_input = require("config_inputs")
local ServerQueue = require("ServerQueue")
local UIElement = require("ui.UIElement")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local scene_manager = require("scenes.scene_manager")
local input = require("inputManager")

local BUTTON_PADDING = 5

local function setMenuItems(self, menuItems)
  self.selectedIndex = 1
  if self.menuItems then
    for i, menuItem in ipairs(self.menuItems) do
      menuItem:detach()
    end
  end
  
  self.menuItems = {}
  
  for i, menuItem in ipairs(menuItems) do
    if i > 1 then 
       menuItem[1].y = menuItems[i - 1][1].y + menuItems[i - 1][1].height + BUTTON_PADDING
    end
    if menuItem[2] then
      menuItem[2].x = menuItem[1].width + BUTTON_PADDING
      menuItem[1]:addChild(menuItem[2])
    end
    self:addChild(menuItem[1])
    self.menuItems[#self.menuItems + 1] = menuItem[1]
  end
end

--@module MainMenu
local Menu = class(
  function(self, options)
    setMenuItems(self, options.menuItems)
  end,
  UIElement
)

local font = love.graphics.getFont()
local arrow = love.graphics.newText(font, ">")

Menu.setMenuItems = setMenuItems

function Menu:update()
  if input:isPressedWithRepeat("Up", .25, .05) then
    self.selectedIndex = ((self.selectedIndex - 2) % #self.menuItems) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end
  
  if input:isPressedWithRepeat("Down", .25, .05) then
    self.selectedIndex = (self.selectedIndex % #self.menuItems) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end

  local itemController = self.menuItems[self.selectedIndex].children[1]
  if itemController then
    if input:isPressedWithRepeat("Left", .25, .05) then
      if itemController.TYPE == "Slider" then
        itemController:setValue(itemController.value - 1)
      elseif itemController.TYPE == "ButtonGroup" then
        itemController:setActiveButton(itemController.selectedIndex - 1)
      elseif itemController.TYPE == "Stepper" then
        itemController:setState(itemController.selectedIndex - 1)
      end
    end

    if input:isPressedWithRepeat("Right", .25, .05) then
      if itemController.TYPE == "Slider" then
        itemController:setValue(itemController.value + 1)
      elseif itemController.TYPE == "ButtonGroup" then
        itemController:setActiveButton(itemController.selectedIndex + 1)
      elseif itemController.TYPE == "Stepper" then
        itemController:setState(itemController.selectedIndex + 1)
      end
    end
  end
  
  if input.isDown["Start"] or input.isDown["Swap1"]  then
    if self.menuItems[self.selectedIndex].TYPE == "Button" then
      self.menuItems[self.selectedIndex].onClick()
    end
  end
  
  if input.isDown["Swap2"] then
    if self.selectedIndex ~= #self.menuItems then
      self.selectedIndex = #self.menuItems
      play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    else
      self.menuItems[self.selectedIndex].onClick()
    end
  end
end

function Menu:draw()
  local animationX = (math.cos(6 * love.timer.getTime()) * 5) - 9
  local screenX, screenY = self.menuItems[self.selectedIndex]:getScreenPos()
  local arrowx = screenX - 10 + animationX
  local arrowy = screenY + self.menuItems[self.selectedIndex].height / 4
  GAME.gfx_q:push({love.graphics.draw, {arrow, arrowx, arrowy, 0, 1, 1, 0, 0}})
  
  for i, menuItem in ipairs(self.menuItems) do
    if menuItem.TYPE == "Label" then
      menuItem:draw()
    end
    if menuItem.children[1] and menuItem.children[1].TYPE == "Stepper" then
      menuItem.children[1]:draw()
    end
  end
end

return Menu