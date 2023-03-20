local class = require("class")
local UIElement = require("ui.UIElement")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local input = require("inputManager")
local consts = require("consts")

local BUTTON_HORIZONTAL_PADDING = 6
local BUTTON_VERTICAL_PADDING = 4 -- increase this when we have scrolling menus 8?
local NAV_BUTTON_WIDTH = 30

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
       menuItem[1].y = menuItems[i - 1][1].y + menuItems[i - 1][1].height + BUTTON_VERTICAL_PADDING
    end
    if menuItem[2] then
      menuItem[2].x = menuItem[1].width + BUTTON_HORIZONTAL_PADDING
      menuItem[1]:addChild(menuItem[2])
    end
    self.menuItemContainer:addChild(menuItem[1])
    self.menuItems[#self.menuItems + 1] = menuItem[1]
  end
end

-- Updates the visibility state of each menu items based on the current scroll state.
-- Use when adding new items to the menu or when the menu wraps.
local function resetMenuScroll(self)
  for i, menuItem in ipairs(self.menuItems) do
    self.menuItems[i]:setVisibility(i >= self.firstActiveIndex and i < self.firstActiveIndex + self.maxItems)
  end
  
  self.menuItemContainer.y = -self.menuItems[self.firstActiveIndex].y
end

local function scrollMenu(self)
  -- scroll up
  if self.selectedIndex >= 1 and self.selectedIndex < self.firstActiveIndex then
    self.firstActiveIndex = self.firstActiveIndex - 1
    self.menuItems[self.firstActiveIndex + self.maxItems]:setVisibility(false)
    self.menuItems[self.firstActiveIndex]:setVisibility(true)
  end

  -- scroll down
  if self.selectedIndex <= #self.menuItems and self.selectedIndex >= self.firstActiveIndex + self.maxItems then
    self.menuItems[self.firstActiveIndex]:setVisibility(false)
    self.menuItems[self.firstActiveIndex + self.maxItems]:setVisibility(true)
    self.firstActiveIndex = self.firstActiveIndex + 1
  end
  
  self.menuItemContainer.y = -self.menuItems[self.firstActiveIndex].y
end

local function updateNavButtonPos(self)
  self.upButton.x = self.menuItems[1].width - self.upButton.width
  self.upButton.y = self.menuItems[self.firstActiveIndex].y - (self.downButton.height + BUTTON_VERTICAL_PADDING)
  
  self.downButton.x = self.menuItems[#self.menuItems].width - self.downButton.width
  self.downButton.y = self.menuItems[self.firstActiveIndex + self.maxItems - 1].y + self.menuItems[self.firstActiveIndex + self.maxItems - 1].height + BUTTON_VERTICAL_PADDING
end

local function scrollUp(self)
  self.selectedIndex = ((self.selectedIndex - 2) % #self.menuItems) + 1
  if self.selectedIndex == #self.menuItems then
    self.firstActiveIndex = #self.menuItems - self.maxItems + 1
    self:resetMenuScroll()
  else
    self:scrollMenu()
  end
  self:updateNavButtonPos()
  play_optional_sfx(themes[config.theme].sounds.menu_move)
end

local function scrollDown(self)
  self.selectedIndex = (self.selectedIndex % #self.menuItems) + 1
  if self.selectedIndex == 1 then
    self.firstActiveIndex = 1
    self:resetMenuScroll()
  else
    self:scrollMenu()
  end
  self:updateNavButtonPos()
  play_optional_sfx(themes[config.theme].sounds.menu_move)
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
    self.maxItems = options.maxItems or #options.menuItems
    self.firstActiveIndex = 1
    self.menuItemContainer = UIElement({})
    self:addChild(self.menuItemContainer)
    setMenuItems(self, options.menuItems)
    
    self.upButton = Button({width = NAV_BUTTON_WIDTH, label = "/\\", translate = false, onClick = function() scrollUp(self) end})
    self.downButton = Button({width = NAV_BUTTON_WIDTH, label = "\\/", translate = false, onClick = function() scrollDown(self) end})
    
    updateNavButtonPos(self)
    self.menuItemContainer:addChild(self.upButton)
    self.menuItemContainer:addChild(self.downButton)
  end,
  UIElement
)

local font = love.graphics.getFont()
local arrow = love.graphics.newText(font, ">")

Menu.setMenuItems = setMenuItems
Menu.resetMenuScroll = resetMenuScroll
Menu.scrollMenu = scrollMenu
Menu.scrollUp = scrollUp
Menu.scrollDown = scrollDown
Menu.updateNavButtonPos = updateNavButtonPos

function Menu:setVisibility(isVisible)
  self.isVisible = isVisible
  for _, uiElement in ipairs(self.children) do
    uiElement:setVisibility(isVisible)
  end
  if isVisible then
    self:resetMenuScroll()
    self.upButton:setVisibility(self.maxItems ~= #self.menuItems)
    self.downButton:setVisibility(self.maxItems ~= #self.menuItems)
  end
end

function Menu:update()
  if not self.isEnabled then
    return
  end
  
  if input:isPressedWithRepeat("MenuUp", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self:scrollUp()
  end
  
  if input:isPressedWithRepeat("MenuDown", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self:scrollDown()
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
function Menu.playCancelSfx()
  play_optional_sfx(themes[config.theme].sounds.menu_cancel)
end

function Menu.playValidationSfx()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
end

function Menu.playMoveSfx()
  play_optional_sfx(themes[config.theme].sounds.menu_move)
end

return Menu