local Label = require("client.src.ui.Label")
local TextButton = require("client.src.ui.TextButton")
local UiElement = require("client.src.ui.UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

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

  label.vAlign = "center"
  label.x = MenuItem.PADDING

  local menuItem = MenuItem({x = 0, y = 0})

  menuItem.width = label.width + (2 * MenuItem.PADDING)

  if love.system.getOS() == "Android" or DEBUG_ENABLED then
    label.height = math.max(30, label.height + (2 * MenuItem.PADDING))
    menuItem.height = math.max(30, label.height, item and item.height or 0)
  else
    menuItem.height = math.max(menuItem.height, math.max(label.height, item and item.height or 0) + (2 * MenuItem.PADDING))
  end

  if item ~= nil then
    local spaceBetween = 16
    item.x = label.width + spaceBetween
    item.vAlign = "center"
    if love.system.getOS() == "Android" or DEBUG_ENABLED then
      item.height = math.max(30, item.height)
    end
    menuItem.width = item.x + item.width + MenuItem.PADDING
    menuItem:addChild(item)
  end
  menuItem:addChild(label)


  return menuItem
end

-- Creates a menu item with just a button
function MenuItem.createButtonMenuItem(text, replacements, translate, onClick)
  assert(text ~= nil)
  local BUTTON_WIDTH = 140
  if translate == nil then
    translate = true
  end
  local textButton = TextButton({
    label = Label({
      text = text,
      replacements = replacements,
      translate = translate,
      hAlign = "center",
      vAlign = "center"
    }),
    onClick = onClick, width = BUTTON_WIDTH
  })

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


local DEFAULT_BACKGROUND_COLOR = {1, 1, 1}
local SELECTED_BACKGROUND_COLOR = {0.6, 0.6, 1}
local DEFAULT_BORDER_COLOR = {1, 1, 1}
local SELECTED_BORDER_COLOR = {0.6, 0.6, 1}

function MenuItem:drawSelf()
  local baseOpacity = 0.15
  if self.selected then
    local selectedAdditionalOpacity = 0.5
    local fillOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 16 + baseOpacity + selectedAdditionalOpacity
    local borderOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 4 + baseOpacity + selectedAdditionalOpacity
    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height, SELECTED_BACKGROUND_COLOR[1], SELECTED_BACKGROUND_COLOR[2], SELECTED_BACKGROUND_COLOR[3], fillOpacity)
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height, SELECTED_BORDER_COLOR[1], SELECTED_BORDER_COLOR[2], SELECTED_BORDER_COLOR[3], borderOpacity)
  else
    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height, DEFAULT_BACKGROUND_COLOR[1], DEFAULT_BACKGROUND_COLOR[2], DEFAULT_BACKGROUND_COLOR[3], baseOpacity)
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height, DEFAULT_BORDER_COLOR[1], DEFAULT_BORDER_COLOR[2], DEFAULT_BORDER_COLOR[3], baseOpacity)
  end
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
