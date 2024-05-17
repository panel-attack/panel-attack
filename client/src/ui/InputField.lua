local utf8 = require("common.lib.utf8Additions")
local util = require("common.lib.util")

local class = require("class")
local UIElement = require("ui.UIElement")
local inputFieldManager = require("ui.inputFieldManager")
local GraphicsUtil = require("graphics_util")

--@module InputField
local InputField = class(
  function(self, options)
    self.placeholderText = love.graphics.newTextBatch(love.graphics.getFont(), options.placeholder) or love.graphics.newTextBatch(love.graphics.getFont(), "Input Field")
    self.value = options.value or ""
    self.charLimit = options.charLimit or NAME_LENGTH_LIMIT
    self.filterAlphanumeric = options.filterAlphanumeric or (options.filterAlphanumeric == nil and true)

    self.backgroundColor = options.backgroundColor or {.3, .3, .3, .7}
    self.outlineColor = options.outlineColor or {.5, .5, .5, .7}

    -- text alignments settings
    -- must be one of the following values:
    -- left, right, center
    self.hAlign = options.hAlign or 'left'
    self.vAlign = options.vAlign or 'center'
    
    self.text = love.graphics.newTextBatch(love.graphics.getFont(), self.value)
    -- stretch to fit text
    local textWidth, textHeight = self.text:getDimensions()
    self.width = math.max(textWidth + 6, self.width)
    self.height = math.max(textHeight + 6, self.height)

    self.hasFocus = false
    self.offset = 0
    self.textCursorPos = nil

    inputFieldManager.inputFields[self.id] = self.isVisible and self or nil
    self.TYPE = "InputField"
  end,
  UIElement
)

function InputField:onTouch(x, y)
  self:setFocus()
end

function InputField:onDrag(x, y)
  if self:inBounds(x, y) then
    self:setFocus()
  end
end

function InputField:onRelease(x, y)
  if self:inBounds(x, y) then
    self:setFocus()
  end
end

local textOffset = 4
local textCursor = love.graphics.newTextBatch(love.graphics.getFont(), "|")

function InputField:onVisibilityChanged()
  if self.isVisible then
    inputFieldManager.inputFields[self.id] = self
  else
    inputFieldManager.inputFields[self.id] = nil
  end
end

function InputField:getCursorPos()
  if self.offset == 0 then
    return self.x + textOffset
  end

  local byteoffset = utf8.offset(self.value, self.offset)
  local text = string.sub(self.value, 1, byteoffset)
  return self.x + textOffset + love.graphics.newTextBatch(love.graphics.getFont(), text):getWidth()
end

function InputField:unfocus()
  inputFieldManager.selectedInputField = nil
  love.keyboard.setTextInput(false)
  self.hasFocus = false
end

function InputField:setFocus()
  inputFieldManager.selectedInputField = self
  love.keyboard.setTextInput(true)
  self.hasFocus = true
  self.offset = utf8.len(self.value)
end

function InputField:onBackspace()
  if self.offset == 0 then
    return
  end

  -- get the byte offset to the last UTF-8 character in the string.
  local strByteLength = utf8.offset(self.value, -1) or 0
  local byteoffset = utf8.offset(self.value, self.offset - 1) or 0
  local byteoffset2 = utf8.offset(self.value, self.offset) or 0

  if self.offset == 1 then
    self.value = string.sub(self.value, byteoffset2 + 1, strByteLength)
  elseif self.offset == utf8.len(self.value) then
    self.value = string.sub(self.value, 1, byteoffset)
  else
    self.value = string.sub(self.value, 1, byteoffset) .. string.sub(self.value, byteoffset2 + 1, strByteLength)
  end
  self.text:set(self.value)
  self.offset = self.offset - 1
end

function InputField:onMoveCursor(dir)
  self.offset = util.bound(0, self.offset + dir, utf8.len(self.value))
end

function InputField:textInput(t)
  if self.filterAlphanumeric and string.find(t, "[^%w]+") then
    return
  end
  if utf8.len(self.value) + utf8.len(t) <= self.charLimit then
    local strByteLength = utf8.offset(self.value, -1) or 0
    local byteoffset = utf8.offset(self.value, self.offset) or 0
    if self.offset == 0 then
      self.value = t .. string.sub(self.value, 1, strByteLength)
    elseif self.offset == utf8.len(self.value) then
      self.value = string.sub(self.value, 1, strByteLength) .. t
    else
      self.value = string.sub(self.value, 1, byteoffset) .. t .. string.sub(self.value, byteoffset + 1, strByteLength)
    end
    self.text:set(self.value)
    self.offset = self.offset + utf8.len(t)
  end
end

local valueColor = {1, 1, 1, 1}
local placeholderColor = {.5, .5, .5, 1}
function InputField:drawSelf()
  GraphicsUtil.setColor(self.outlineColor)
  GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
  GraphicsUtil.setColor(self.backgroundColor)
  GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height)

  local text = self.value ~= "" and self.text or self.placeholderText
  local textColor = self.value ~= "" and valueColor or placeholderColor
  local textHeight = text:getHeight()

  GraphicsUtil.setColor(textColor)
  GraphicsUtil.draw(text, self.x + textOffset, self.y + (self.height - textHeight) / 2, 0, 1, 1)

  if self.hasFocus then
    local cursorFlashPeriod = .5
    if (math.floor(love.timer.getTime() / cursorFlashPeriod)) % 2 == 0 then
      GraphicsUtil.setColor(1, 1, 1, 1)
      GraphicsUtil.draw(textCursor, self:getCursorPos(), self.y + (self.height - textHeight) / 2, 0, 1, 1)
    end
  end
  GraphicsUtil.setColor(1, 1, 1, 1)
end

return InputField