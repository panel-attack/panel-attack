local class = require("class")
local UIElement = require("ui.UIElement")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local input = require("inputManager")
local consts = require("consts")

local GraphicsUtil = require("graphics_util")

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
    self.selecteIndex = nil
    -- list of menu items
    -- set from options.menuItems, which consists of a list of UIElement tuples of the form:
    -- {{Label/Button, ButtonGroup/Stepper/Slider}, ...}
    -- the actual self.menuItems list is formated slightly differently, consisting of a list of Labels or Buttons
    -- each of which may have a ButtonGroup, Stepper, or Slider child element which controls the action for that item
    self.menuItems = nil
    setMenuItems(self, options.menuItems)
  end,
  UIElement
)

local font = GraphicsUtil.getGlobalFont()
local arrow = love.graphics.newText(font, ">")

Menu.setMenuItems = setMenuItems

function Menu:update()
  if not self.isEnabled then
    return
  end
  
  if input:isPressedWithRepeat("MenuUp", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self.selectedIndex = ((self.selectedIndex - 2) % #self.menuItems) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end
  
  if input:isPressedWithRepeat("MenuDown", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self.selectedIndex = (self.selectedIndex % #self.menuItems) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end

  local itemController = self.menuItems[self.selectedIndex].children[1]
  if itemController then
    if input:isPressedWithRepeat("MenuLeft", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      if itemController.TYPE == "Slider" then
        itemController:setValue(itemController.value - 1)
      elseif itemController.TYPE == "ButtonGroup" then
        itemController:setActiveButton(itemController.selectedIndex - 1)
      elseif itemController.TYPE == "Stepper" then
        itemController:setState(itemController.selectedIndex - 1)
      end
    end

    if input:isPressedWithRepeat("MenuRight", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      if itemController.TYPE == "Slider" then
        itemController:setValue(itemController.value + 1)
      elseif itemController.TYPE == "ButtonGroup" then
        itemController:setActiveButton(itemController.selectedIndex + 1)
      elseif itemController.TYPE == "Stepper" then
        itemController:setState(itemController.selectedIndex + 1)
      end
    end
  end
  
  if input.isDown["MenuSelect"]  then
    if self.menuItems[self.selectedIndex].TYPE == "Button" then
      self.menuItems[self.selectedIndex].onClick()
    end
  end
  
  if input.isDown["MenuEsc"] then
    if self.selectedIndex ~= #self.menuItems then
      self.selectedIndex = #self.menuItems
      play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    else
      self.menuItems[self.selectedIndex].onClick()
    end
  end
end

function Menu:draw()
  if not self.isVisible then
    return
  end

  local animationX = (math.cos(6 * love.timer.getTime()) * 5) - 9
  local screenX, screenY = self.menuItems[self.selectedIndex]:getScreenPos()
  local arrowx = screenX - 10 + animationX
  local arrowy = screenY + self.menuItems[self.selectedIndex].height / 4
  GAME.gfx_q:push({love.graphics.draw, {arrow, arrowx, arrowy, 0, 1, 1, 0, 0}})
  
  -- draw children
  UIElement.draw(self)
end


-- sound effects
function Menu.playValidationSfx()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
end

function Menu.playMoveSfx()
  play_optional_sfx(themes[config.theme].sounds.menu_move)
end

return Menu