local table = table

local class = require("common.lib.class")
local UIElement = require("client.src.ui.UIElement")
local input = require("common.lib.inputManager")

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

    -- bogus this should be passed in?
    self.centerVertically = themes[config.theme].centerMenusVertically

    self.yOffset = 0
    self.firstActiveIndex = 1
    self.lastActiveIndex = 1
    self:setMenuItems(options.menuItems)
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
  if self.selectedIndex > 1 then
    self:setSelectedIndex(self.selectedIndex - 1)
    GAME.theme:playMoveSfx()
  end
end

function Menu:scrollDown()
  if self.selectedIndex < #self.menuItems then
    self:setSelectedIndex(self.selectedIndex + 1)
    GAME.theme:playMoveSfx()
  end
end

function Menu:update(dt)
  if not self.isEnabled then
    return
  end

  if input:isPressedWithRepeat("MenuUp") then
    self:scrollUp()
  end

  if input:isPressedWithRepeat("MenuDown") then
    self:scrollDown()
  end

  local selectedElement = self.menuItems[self.selectedIndex]

  if selectedElement then
    -- Right now back on a button is only allowed on the last item. Later we should make it more explicit.
    if not input.isDown["MenuEsc"] or self.selectedIndex == #self.menuItems then
      selectedElement:receiveInputs(input, dt)
    end
  end

  if input.isDown["MenuEsc"] then
    if self.selectedIndex ~= #self.menuItems then
      self:setSelectedIndex(#self.menuItems)
      GAME.theme:playCancelSfx()
    end
  end
end

function Menu:drawSelf()

end

function Menu:onTouch(x, y)
  self.swiping = true
  self.initialTouchY = y
  self.originalY = self.yOffset
end

function Menu:onDrag(x, y)
  local yOffset = y - self.initialTouchY
  if self.height < self.totalHeight then
    if yOffset > 0 then
      self.yOffset = math.max(self.originalY - yOffset, -50)-- - 2 * NAVIGATION_BUTTON_WIDTH)
    else
      self.yOffset = math.min(self.totalHeight - self.height + 50, self.originalY - yOffset)
    end
    self:layout()
  end
end

function Menu:onRelease(x, y)
  self:onDrag(x, y)
  self.swiping = false
end

return Menu