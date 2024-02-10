local Label = require("ui.Label")
local TextButton = require("ui.TextButton")
local UiElement = require("ui.UIElement")
local class = require("class")
local tableUtils = require("tableUtils")
local GraphicsUtil = require("graphics_util")

-- MenuItem is a specific UIElement that all children of Menu should be
local MenuItem = class(function(self, options)
  self.selected = false
  self.TYPE = "MenuItem"
end,
UiElement)

MenuItem.PADDING = 2

-- Takes a label and an optional extra element and makes and combines them into a menu item
-- which is suitable for inserting into a menu
function MenuItem.createMenuItem(label, item)
  assert(label ~= nil)

  local menuItem = MenuItem({x = 0, y = 0})

  label.vAlign = "center"
  label.x = MenuItem.PADDING

  menuItem:addChild(label)
  menuItem.width = label.width + (2 * MenuItem.PADDING)
  menuItem.height = label.height + (2 * MenuItem.PADDING)

  if item ~= nil then
    local spaceBetween = 16
    item.vAlign = "center"
    item.x = label.width + spaceBetween
    menuItem:addChild(item)
    menuItem.width = item.x + item.width + MenuItem.PADDING
    menuItem.height = math.max(menuItem.height, item.height + (2 * MenuItem.PADDING))
  end

  return menuItem
end

-- Creates a menu item with just a button
function MenuItem.createButtonMenuItem(text, replacements, translate, onClick)
  assert(text ~= nil)
  local BUTTON_WIDTH = 140
  if translate == nil then
    translate = true
  end
  local textButton = TextButton({label = Label({text = text, replacements = replacements, translate = translate, hAlign = "center", vAlign = "center"}), onClick = onClick, width = BUTTON_WIDTH})

  local menuItem = MenuItem.createMenuItem(textButton)
  menuItem.textButton = textButton

  return menuItem
end

-- Creates a menu item with a label followed by a button
function MenuItem.createLabeledButtonMenuItem(labelText, labelTextReplacements, labelTextTranslate, buttonText, buttonTextReplacements, buttonTextTranslate, buttonOnClick)
  assert(labelText ~= nil)
  assert(buttonText ~= nil)
  assert(buttonOnClick ~= nil)
  local BUTTON_WIDTH = 140
  if labelTextTranslate == nil then
    labelTextTranslate = true
  end
  if buttonTextTranslate == nil then
    buttonTextTranslate = true
  end

  local label = Label({text = labelText, replacements = labelTextReplacements, translate = labelTextTranslate, vAlign = "center"})
  local textButton = TextButton({label = Label({text = buttonText, replacements = buttonTextReplacements, translate = buttonTextTranslate, hAlign = "center", vAlign = "center"}), onClick = buttonOnClick, width = BUTTON_WIDTH})

  local menuItem = MenuItem.createMenuItem(label, textButton)
  menuItem.textButton = textButton

  return menuItem
end

function MenuItem.createStepperMenuItem(text, replacements, translate, stepper)
  assert(text ~= nil)
  assert(stepper ~= nil)
  if translate == nil then
    translate = true
  end
  local label = Label({text = text, replacements = replacements, translate = translate, vAlign = "center"})
  local menuItem = MenuItem.createMenuItem(label, stepper)
  
  return menuItem
end

function MenuItem.createToggleButtonGroupMenuItem(text, replacements, translate, toggleButtonGroup)
  assert(text ~= nil)
  assert(toggleButtonGroup ~= nil)
  if translate == nil then
    translate = true
  end
  local label = Label({text = text, replacements = replacements, translate = translate, vAlign = "center"})
  local menuItem = MenuItem.createMenuItem(label, toggleButtonGroup)
  
  return menuItem
end

function MenuItem.createSliderMenuItem(text, replacements, translate, slider)
  assert(text ~= nil)
  assert(slider ~= nil)
  if translate == nil then
    translate = true
  end
  local label = Label({text = text, replacements = replacements, translate = translate, vAlign = "center"})
  local menuItem = MenuItem.createMenuItem(label, slider)
  
  return menuItem
end

function MenuItem:setSelected(selected)
  self.selected = selected
end

function MenuItem:drawSelf()
  local currentColor = {1, 1, 1}
  if self.selected then
    currentColor = {0.6, 0.6, 1}
    local animationOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 16 + 0.05
    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height, currentColor[1], currentColor[2], currentColor[3], animationOpacity)
  end

  GraphicsUtil.setColor(currentColor[1], currentColor[2], currentColor[3], 0.7)
  GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

-- inputs as a passthrough in case we ever implement player specific menus
function MenuItem:receiveInputs(inputs)
  for _, child in ipairs(self.children) do
    if child.receiveInputs then
      child:receiveInputs(inputs)
      return
    end
  end
end

return MenuItem
