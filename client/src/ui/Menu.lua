local table = table

local class = require("common.lib.class")
local UIElement = require("client.src.ui.UIElement")
local input = require("common.lib.inputManager")
local Label = require("client.src.ui.Label")
local directsFocus = require("client.src.ui.FocusDirector")

local NAVIGATION_BUTTON_WIDTH = 30

-- Menu is a collection of buttons that stack vertically and supports scrolling and keyboard navigation.
-- It requires the passed in menu items to have valid widths and adds padding between each. The height also must be passed in
-- and the width is the maximum of all buttons.
local Menu = class(
  function(self, options)
    self.TYPE = "VerticalScrollingButtonMenu"

    self.selectedIndex = 1
    self.yMin = self.y
    self.totalHeight = 0
    self.menuItemYOffsets = {}
    self.allContentShowing = true

    self.upIndicator = Label({text = "^", translate = false, isVisible = false, vAlign = "top", hAlign = "center", y = -14})
    self.downIndicator = Label({text = "v", translate = false, isVisible = false, vAlign = "bottom", hAlign = "center"})
    self:addChild(self.upIndicator)
    self:addChild(self.downIndicator)

    -- bogus this should be passed in?
    self.centerVertically = themes[config.theme].centerMenusVertically

    self.yOffset = 0
    self.firstActiveIndex = 1
    self.lastActiveIndex = 1
    self:setMenuItems(options.menuItems)
    directsFocus(self)
  end,
  UIElement
)

Menu.NAVIGATION_BUTTON_WIDTH = NAVIGATION_BUTTON_WIDTH
Menu.BUTTON_HORIZONTAL_PADDING = 0
Menu.BUTTON_VERTICAL_PADDING = 8

function Menu.createCenteredMenu(items) 
  local menu = Menu({
    x = 0,
    y = 0,
    hAlign = "center",
    vAlign = "center",
    menuItems = items,
    height = themes[config.theme].main_menu_max_height
  })

  return menu
end

-- Sets the menu items for this menu
-- menuItems: a list of UIElement tuples of the form:
--   {{Label/Button, ButtonGroup/Stepper/Slider}, ...}
-- the actual self.menuItems list is formated slightly differently, consisting of a list of Labels or Buttons
-- each of which may have a ButtonGroup, Stepper, or Slider child element which controls the action for that item
function Menu:setMenuItems(menuItems)
  if self.menuItems then
    for i, menuItem in ipairs(self.menuItems) do
      menuItem:detach()
    end
  end
  
  self.menuItems = {}
  
  for i, menuItem in ipairs(menuItems) do
    self:addChild(menuItem)
    self.menuItems[#self.menuItems + 1] = menuItem
  end
  self:setSelectedIndex(1)
end

function Menu:layout()
  self.upIndicator:setVisibility(false)
  self.downIndicator:setVisibility(false)
  self.allContentShowing = self.yOffset == 0
  self.firstActiveIndex = nil
  self.lastActiveIndex = nil
  self.width = 0
  self.totalHeight = 0

  if #self.menuItems == 0 then
    return
  end

  local currentY = 0
  local totalMenuHeight = 0
  local menuFull = false
  for i, menuItem in ipairs(self.menuItems) do
    self.menuItemYOffsets[i] = currentY
    menuItem:setVisibility(false)
    local realY = currentY - self.yOffset
    if realY < 0 then
      self.upIndicator:setVisibility(true)
    end
    if menuFull == false and realY >= 0 then
      if realY + menuItem.height < self.height then
        if self.firstActiveIndex == nil then
          self.firstActiveIndex = i
        end
        menuItem.x = Menu.BUTTON_HORIZONTAL_PADDING
        menuItem.y = realY
        menuItem:setVisibility(true)
      else
        self.allContentShowing = false
        self.downIndicator:setVisibility(true)
        menuFull = true
      end
    end
    currentY = currentY + menuItem.height + Menu.BUTTON_VERTICAL_PADDING
    if menuFull == false then
      self.lastActiveIndex = i
      totalMenuHeight = realY + menuItem.height
    end
    self.width = math.max(self.width, menuItem.width)
    self.totalHeight = self.totalHeight + menuItem.height + Menu.BUTTON_VERTICAL_PADDING
  end

  if self.centerVertically then
    self.y = self.yMin + (self.height / 2) - (totalMenuHeight / 2)
  else
    self.y = self.yMin
  end
end

function Menu:addMenuItem(index, menuItem)
  local needsIncreasedIndex = false
  if index <= self.selectedIndex then
    needsIncreasedIndex = true
  end
  table.insert(self.menuItems, index, menuItem)
  self:addChild(menuItem)
  if needsIncreasedIndex then
    self:setSelectedIndex(self.selectedIndex + 1)
  end
  self:layout()
end

function Menu:removeMenuItemAtIndex(index)
  return self:removeMenuItem(self.menuItems[index].id)
end

function Menu:indexOfMenuItemID(menuItemId)
  local menuItemIndex = nil
  for i, menuItem in ipairs(self.menuItems) do
    if menuItemId == menuItem.id then
      menuItemIndex = i
      break
    end
  end
  return menuItemIndex
end

function Menu:containsMenuItemID(menuItemId)
  return self:indexOfMenuItemID(menuItemId) ~= nil
end

function Menu:removeMenuItem(menuItemId)
  local menuItemIndex = self:indexOfMenuItemID(menuItemId)

  if menuItemIndex == nil then
    return
  end

  local needsDecreasedIndex = false
  if menuItemIndex <= self.selectedIndex then
    needsDecreasedIndex = true
  end

  local menuItem = table.remove(self.menuItems, menuItemIndex)
  menuItem:detach()

  if needsDecreasedIndex then
    self:setSelectedIndex(self.selectedIndex - 1)
  end

  self:layout()
  return menuItem
end

-- Updates the selected index of the menu
-- Also updates the scroll state to show the button if off screen
function Menu:setSelectedIndex(index)
  if index <= 0 then
    index = 1 -- 1 index is the default if no items
  end

  if #self.menuItems >= self.selectedIndex then
    self.menuItems[self.selectedIndex]:setSelected(false)
  end
  if self.firstActiveIndex > index then
    self.yOffset = self.menuItemYOffsets[index]
  elseif self.lastActiveIndex < index then
    local currentIndex = 1
    local bottomOfDesiredIndex = self.menuItemYOffsets[index] + self.menuItems[index].height
    while self.menuItemYOffsets[currentIndex] + self.height < bottomOfDesiredIndex do
      currentIndex = currentIndex + 1
      if currentIndex >= #self.menuItems then
        break
      end
    end
    self.yOffset = self.menuItemYOffsets[currentIndex]
  end
  self.selectedIndex = index
  if #self.menuItems > 0 then
    self.menuItems[self.selectedIndex]:setSelected(true)
  end
  self:layout()
end

function Menu:scrollUp()
  self:setSelectedIndex(wrap(1, self.selectedIndex - 1, #self.menuItems))
  GAME.theme:playMoveSfx()
end

function Menu:scrollDown()
  self:setSelectedIndex(wrap(1, self.selectedIndex + 1, #self.menuItems))
  GAME.theme:playMoveSfx()
end

function Menu:receiveInputs(inputs, dt)
  if not self.isEnabled then
    return
  end

  if not inputs then
    -- if we don't get inputs passed, use the global input table
    inputs = input
  end

  local selectedElement = self.menuItems[self.selectedIndex]

  if self.focused then
    self.focused:receiveInputs(inputs, dt)
  elseif inputs.isDown["MenuEsc"] then
    if self.selectedIndex ~= #self.menuItems then
      self:setSelectedIndex(#self.menuItems)
      GAME.theme:playCancelSfx()
    else
      selectedElement:receiveInputs(inputs, dt)
    end
  elseif inputs:isPressedWithRepeat("MenuUp") then
    self:scrollUp()
  elseif inputs:isPressedWithRepeat("MenuDown") then
    self:scrollDown()
  else
    if inputs.isDown["MenuSelect"] and selectedElement.isFocusable then
      self:setFocus(selectedElement)
    else
      selectedElement:receiveInputs(inputs, dt)
    end
  end
end

function Menu:update(dt)

end

function Menu:drawSelf()

end

function Menu:onTouch(x, y)
  self.swiping = true
  self.initialTouchX = x
  self.initialTouchY = y
  self.originalY = self.yOffset
  local realTouchedElement = UIElement.getTouchedElement(self, x, y)
  if realTouchedElement and realTouchedElement ~= self then
    self.touchedChild = realTouchedElement
    self.touchedChild:onTouch(x, y)
  end
end

function Menu:onDrag(x, y)
  if not self.touchedChild or not self.touchedChild.onDrag then
    local yOffset = y - self.initialTouchY
    if self.height < self.totalHeight then
      if yOffset > 0 then
        self.yOffset = math.max(self.originalY - yOffset, -50)-- - 2 * NAVIGATION_BUTTON_WIDTH)
      else
        self.yOffset = math.min(self.totalHeight - self.height + 50, self.originalY - yOffset)
      end
      self:layout()
    end
  else
    self.touchedChild:onDrag(x, y)
  end
end

function Menu:onRelease(x, y)
  if not self.touchedChild or not self.touchedChild.onRelease then
    self:onDrag(x, y)
  else
    if self.yOffset ~= self.originalY then
      -- we dragged so trigger with the original touch coordinates
      -- that way the button will only trigger its on-click if it still touches the start coords
      self.touchedChild:onRelease(self.initialTouchX, self.initialTouchY)
    else
      self.touchedChild:onRelease(x, y)
    end
  end

  self.swiping = false
  self.touchedChild = nil
end

-- overwrite the default callback to always return itself
-- while keeping a reference to the really touched element
function Menu:getTouchedElement(x, y)
  if self.isVisible and self.isEnabled and self:inBounds(x, y) then
    if self.allContentShowing then
      local touchedElement
      for i = 1, #self.children do
        touchedElement = self.children[i]:getTouchedElement(x, y)
        if touchedElement then
          return touchedElement
        end
      end
    else
      return self
    end
  end
end

return Menu