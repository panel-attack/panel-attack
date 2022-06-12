local utf8 = require("utf8")
local util = require("util")

local class = require("class")
local input_field_manager = require("ui.input_field_manager")

--@module InputField
local InputField = class(
  function(self, options)
    self.id = nil -- set in the input field manager
    self.x = options.x or 0
    self.y = options.y or 0
    self.width = options.width or 200
    self.height = options.height or 25
    self.placeholder_text = options.placeholder_text or love.graphics.newText(love.graphics.getFont(), "Input Field")
    self.value = options.value or ""
    self.char_limit = 16
    self.is_visible = options.is_visible or options.is_visible == nil and true
    self.is_enabled = options.is_enabled or options.is_enabled == nil and true
    self.image = options.image
    self.color = options.color or {.3, .3, .3, .7}
    self.outline_color = options.outline_color or {.5, .5, .5, .7}
    self.halign = options.halign or 'left'
    self.valign = options.valign or 'center'
    self.has_focus = false
    self.onClick = options.onClick or function() 
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
    end
    self.onMouseDown = options.onMouseDown or function() end
    self.onMousePressed = options.onMousePressed or function() 
      GAME.gfx_q:push({love.graphics.setColor, {self.color[1], self.color[2], self.color[3], 1}})
      GAME.gfx_q:push({love.graphics.rectangle, {"fill", self.x, self.y, self.width, self.height}})
      GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
    end
    self.onMouseUp = options.onMouseUp or function() end
    
    self.text = love.graphics.newText(love.graphics.getFont(), self.value)
    local text_width, text_height = self.text:getDimensions()
    self.width = math.max(text_width + 6, self.width)
    self.height = math.max(text_height + 6, self.height)
    input_field_manager.add_input_field(self)
    self.TYPE = "InputField"
    
    self._offset = 0
    self._text_cursor_pos = nil
    self._value_text = love.graphics.newText(love.graphics.getFont(), self.value)
  end
)

local text_offset = 4
local text_cursor = love.graphics.newText(love.graphics.getFont(), "|")

function InputField:remove()
  input_field_manager.remove_input_field(self)
end

function InputField:isSelected(x, y)
  return self.is_enabled and x > self.x and x < self.x + self.width and y > self.y and y < self.y + self.height
end

local function getUtf8Substr(str, s, e)
  local byteoffset = utf8.offset(str, index)
  local text = string.sub(str, 1, byteoffset)
end

local function getTextWidth(str, index)
  local byteoffset = utf8.offset(str, index)
  local text = string.sub(str, 1, byteoffset)
  return love.graphics.newText(love.graphics.getFont(), text):getWidth()
end

function InputField:getCursorPos()
  if self._offset == 0 then
    return self.x + text_offset
  end

  local byteoffset = utf8.offset(self.value, self._offset)
  local text = string.sub(self.value, 1, byteoffset)
  return self.x + text_offset + love.graphics.newText(love.graphics.getFont(), text):getWidth()
end

function InputField:setFocus(x, y)
  self.has_focus = true
  self._offset = 0
  local prev_x = self:getCursorPos()
  local curr_x = self:getCursorPos()
  while self._offset < utf8.len(self.value) and x > curr_x do
    prev_x = curr_x
    self._offset = self._offset + 1
    curr_x = self:getCursorPos()
  end
  if math.abs(x - prev_x) < math.abs(x - curr_x) then
    self._offset = self._offset - 1
  end
end

function InputField:onBackspace()
  if self._offset == 0 then
    return 
  end

  -- get the byte offset to the last UTF-8 character in the string.
  local str_byte_length = utf8.offset(self.value, -1) or 0
  local byteoffset = utf8.offset(self.value, self._offset - 1) or 0
  local byteoffset2 = utf8.offset(self.value, self._offset) or 0

  -- remove the last UTF-8 character.
  -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
  local removed_char = string.sub(self.value, byteoffset, byteoffset2)
  if self._offset == 1 then
    self.value = string.sub(self.value, byteoffset2 + 1, str_byte_length)
  elseif self._offset == utf8.len(self.value) then
    self.value = string.sub(self.value, 1, byteoffset)
  else
    self.value = string.sub(self.value, 1, byteoffset) .. string.sub(self.value, byteoffset2 + 1, str_byte_length)
  end
  self._value_text = love.graphics.newText(love.graphics.getFont(), self.value)
  self._offset = self._offset - 1
end

function InputField:onMoveCursor(dir)
  self._offset = util.clamp(0, self._offset + dir, utf8.len(self.value))
end

function InputField:textInput(t)
  if utf8.len(self.value) < self.char_limit then
    local str_byte_length = utf8.offset(self.value, -1) or 0
    local byteoffset = utf8.offset(self.value, self._offset) or 0
    if self._offset == 0 then
      self.value = t .. string.sub(self.value, 1, str_byte_length)
    elseif self._offset == utf8.len(self.value) then
      self.value = string.sub(self.value, 1, str_byte_length) .. t
    else
      self.value = string.sub(self.value, 1, byteoffset) .. t .. string.sub(self.value, byteoffset + 1, str_byte_length)
    end
    self._value_text = love.graphics.newText(love.graphics.getFont(), self.value)
    self._offset = self._offset + 1
  end
end

function InputField:draw()
  GAME.gfx_q:push({love.graphics.setColor, self.outline_color})
  GAME.gfx_q:push({love.graphics.rectangle, {"line", self.x, self.y, self.width, self.height}})
  if self.image then
    GAME.gfx_q:push({love.graphics.draw, {self.image, self.x + 1, self.y + 1, 0, (self.width - 2) / self.image:getWidth(), (self.height - 2) / self.image:getHeight()}})
  else
    local dark_gray = .3
    local light_gray = .5
    local alpha = .7
    GAME.gfx_q:push({love.graphics.setColor, self.color})
    GAME.gfx_q:push({love.graphics.rectangle, {"fill", self.x, self.y, self.width, self.height}})
  end
  
  
  
  local text = self.value ~= "" and self._value_text or self.placeholder_text
  local text_color = self.value ~= "" and {1, 1, 1, 1} or {.5, .5, .5, 1}
  
  GAME.gfx_q:push({love.graphics.setColor, text_color})
  
  local text_width = self._value_text:getWidth()
  local text_height = text:getHeight()
  local x_alignments = {
    center = {self.width / 2, text_width / 2},
    left = {0, 0},
    right = {self.width, text_width},
  }
  local y_alignments = {
    center = {self.height / 2, text_height / 2},
    top = {0, 0},
    bottom = {self.height, text_height},
  }
  local x_pos_align, x_offset = unpack(x_alignments[self.halign])
  local y_pos_align, y_offset = unpack(y_alignments[self.valign])
  
  GAME.gfx_q:push({love.graphics.draw, {text, self.x + x_pos_align + text_offset, self.y + y_pos_align + 0, 0, 1, 1, x_offset, y_offset}})
  
  if self.has_focus then
    local cursor_flash_period = .5
    if (math.floor(love.timer.getTime() / .5)) % 2 == 0 then
      GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
      GAME.gfx_q:push({love.graphics.draw, {text_cursor, self:getCursorPos(), self.y + y_pos_align + 0, 0, 1, 1, x_offset, y_offset}})
    end
  end
  GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
  --[[GAME.gfx_q:push({love.graphics.setColor, {0, 0, 0, 1}})
  GAME.gfx_q:push({love.graphics.draw, {text, self.x + x_pos_align - 1, self.y + y_pos_align - 1, 0, 1, 1, x_offset, y_offset}})
  GAME.gfx_q:push({love.graphics.draw, {text, self.x + x_pos_align - 1, self.y + y_pos_align + 1, 0, 1, 1, x_offset, y_offset}})
  GAME.gfx_q:push({love.graphics.draw, {text, self.x + x_pos_align + 2, self.y + y_pos_align - 1, 0, 1, 1, x_offset, y_offset}})
  GAME.gfx_q:push({love.graphics.draw, {text, self.x + x_pos_align + 2, self.y + y_pos_align + 1, 0, 1, 1, x_offset, y_offset}})
  GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
  --GAME.gfx_q:push({love.graphics.draw, {text, self.x + x_pos_align, self.y + y_pos_align, 0, 1, 1, x_offset, y_offset}})
  GAME.gfx_q:push({love.graphics.draw, {text, self.x + x_pos_align + 0, self.y + y_pos_align + 0, 0, 1, 1, x_offset, y_offset}})
  --GAME.gfx_q:push({love.graphics.draw, {text, self.x + self.width / 2 + 0, self.y + y_pos_align + 1, 0, 1, 1, x_offset, y_offset}})
  GAME.gfx_q:push({love.graphics.draw, {text, self.x + x_pos_align + 1, self.y + y_pos_align + 0, 0, 1, 1, x_offset, y_offset}})
  --GAME.gfx_q:push({love.graphics.draw, {text, self.x + x_pos_align + 1, self.y + y_pos_align + 1, 0, 1, 1, x_offset, y_offset}})
  --]]
end

return InputField