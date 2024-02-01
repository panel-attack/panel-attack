local table = table
local love = love

local class = require("class")
local UIElement = require("ui.UIElement")
local TextButton = require("ui.TextButton")
local Label = require("ui.Label")
local input = require("inputManager")
local consts = require("consts")
local GraphicsUtil = require("graphics_util")

local NAVIGATION_BUTTON_WIDTH = 30

--@module MainMenu
local Menu = class(
  function(self, options)
    self.selectedIndex = nil
    self.yMin = self.y
    self.menuItemYOffsets = {}
    self.allContentShowing = true

    -- bogus this should be passed in?
    self.centerVertically = themes[config.theme].centerMenusVertically 

    self.yOffset = 0
    self.firstActiveIndex = nil
    self.lastActiveIndex = nil
    self.menuItemContainer = UIElement({})
    self:addChild(self.menuItemContainer)
    self.itemHeight = options.itemHeight or 30
    self:setMenuItems(options.menuItems)
    
    self.upButton = TextButton({width = NAVIGATION_BUTTON_WIDTH, label = Label({text = "/\\"}), translate = false, onClick = function() self:scrollUp() end})
    self.downButton = TextButton({width = NAVIGATION_BUTTON_WIDTH, label = Label({text = "\\/"}), translate = false, onClick = function() self:scrollDown() end})
    
    self.menuItemContainer:addChild(self.upButton)
    self.menuItemContainer:addChild(self.downButton)

    self:layout()

    self.TYPE = "VerticalScrollingButtonMenu"
  end,
  UIElement
)

Menu.BUTTON_HORIZONTAL_PADDING = 0
Menu.BUTTON_VERTICAL_PADDING = 8

-- Sets the menu items for this menu
-- menuItems: a list of UIElement tuples of the form:
--   {{Label/Button, ButtonGroup/Stepper/Slider}, ...}
-- the actual self.menuItems list is formated slightly differently, consisting of a list of Labels or Buttons
-- each of which may have a ButtonGroup, Stepper, or Slider child element which controls the action for that item
function Menu:setMenuItems(menuItems)
  self.selectedIndex = 1
  if self.menuItems then
    for i, menuItem in ipairs(self.menuItems) do
      menuItem:detach()
    end
  end
  
  self.menuItems = {}
  
  for i, menuItem in ipairs(menuItems) do
    if i > 1 then 
       menuItem[1].y = menuItems[i - 1][1].y + menuItems[i - 1][1].height + Menu.BUTTON_VERTICAL_PADDING
    end
    menuItem[1].height = math.max(self.itemHeight, menuItem[1].height)
    if menuItem[2] then
      menuItem[2].x = menuItem[1].width + Menu.BUTTON_HORIZONTAL_PADDING
      menuItem[2].height = math.max(self.itemHeight, menuItem[2].height)
      menuItem[1]:addChild(menuItem[2])
    end
    self.menuItemContainer:addChild(menuItem[1])
    self.menuItems[#self.menuItems + 1] = menuItem[1]
  end
end

function Menu:layout()

  self.allContentShowing = self.yOffset == 0
  self.firstActiveIndex = nil
  self.lastActiveIndex = nil
  self.width = 0
  
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
      totalMenuHeight = realY
    end
    self.width = math.max(self.width, menuItem.width)
  end
  
  self:updateNavButtonPos()

  if self.centerVertically then
    self.y = self.yMin + (self.height / 2) - (totalMenuHeight / 2)
  else
    self.y = self.yMin
  end
end

function Menu:addMenuItem(index, menuItem)
  assert(type(menuItem) == "table")
  if menuItem[2] then
    menuItem[2].x = menuItem[1].width + Menu.BUTTON_HORIZONTAL_PADDING
    menuItem[1]:addChild(menuItem[2])
  end
  table.insert(self.menuItems, index, menuItem[1])
  self.menuItemContainer:addChild(menuItem[1])

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

  local menuItem = {table.remove(self.menuItems, menuItemIndex)}
  if menuItem[1].children[1] then
    menuItem[2] = menuItem[1].children[1]
    menuItem[2]:detach()
  end
  menuItem[1]:detach()
  
  self:layout()
  return menuItem
end

-- Updates the selected index of the menu
-- Also updates the scroll state to show the button if off screen
function Menu:setSelectedIndex(index)
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
  self:layout()
end

function Menu:updateNavButtonPos()
  self.upButton:setVisibility(false)
  self.downButton:setVisibility(false)
  if self.allContentShowing then
    return
  end
  
  self.upButton:setVisibility(true)
  self.downButton:setVisibility(true)

  self.upButton.x = self.menuItems[1].width - self.upButton.width
  self.upButton.y = self.menuItems[self.firstActiveIndex].y - (self.downButton.height + Menu.BUTTON_VERTICAL_PADDING)
  
  self.downButton.x = self.menuItems[#self.menuItems].width - self.downButton.width
  self.downButton.y = self.menuItems[self.lastActiveIndex].y + self.menuItems[self.lastActiveIndex].height + Menu.BUTTON_VERTICAL_PADDING
end

function Menu:scrollUp()
  self:setSelectedIndex(((self.selectedIndex - 2) % #self.menuItems) + 1)
  play_optional_sfx(themes[config.theme].sounds.menu_move)
end

function Menu:scrollDown()
  self:setSelectedIndex((self.selectedIndex % #self.menuItems) + 1)
  play_optional_sfx(themes[config.theme].sounds.menu_move)
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

  -- apparently this can crash here with the offset bug
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
      self:setSelectedIndex(#self.menuItems)
      play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    else
      self.menuItems[self.selectedIndex].onClick()
    end
  end
end

function Menu:drawSelf()
  local selectedItem = self.menuItems[self.selectedIndex]
  local animationOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 8 + 0.4
  GraphicsUtil.drawRectangle("fill", self.x + selectedItem.x, self.y + selectedItem.y, selectedItem.width, selectedItem.height, 1, 1, 1, animationOpacity)
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