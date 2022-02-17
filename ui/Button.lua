local class = require("class")
local button_manager = require("ui.button_manager")

--@module Button
local Button = class(
  function(self, options)
    self.id = nil -- set in the button manager
    self.x = options.x or 0
    self.y = options.y or 0
    self.width = options.width or 110
    self.height = options.height or 25
    self.text = options.text or love.graphics.newText(love.graphics.getFont(), "Button")
    self.is_visible = options.is_visible or options.is_visible == nil and true
    self.is_enabled = options.is_enabled or options.is_enabled == nil and true
    self.image = options.image
    self.color = options.color or {.3, .3, .3, .7}
    self.outline_color = options.outline_color or {.5, .5, .5, .7}
    self.halign = options.halign or 'center'
    self.valign = options.valign or 'center'
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
    
    local text_width, text_height = self.text:getDimensions()
    self.width = math.max(text_width + 6, self.width)
    self.height = math.max(text_height + 6, self.height)
    button_manager.add_button(self)
    self.TYPE = "Button"
  end
)

function Button:remove()
  button_manager.remove_button(self)
end

function Button:isSelected(x, y)
  return self.is_enabled and x > self.x and x < self.x + self.width and y > self.y and y < self.y + self.height
end

function Button:draw()
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
  
  
  
  local text_width, text_height = self.text:getDimensions()
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
  
  GAME.gfx_q:push({love.graphics.setColor, {0, 0, 0, 1}})
  GAME.gfx_q:push({love.graphics.draw, {self.text, self.x + x_pos_align - 1, self.y + y_pos_align - 1, 0, 1, 1, x_offset, y_offset}})
  GAME.gfx_q:push({love.graphics.draw, {self.text, self.x + x_pos_align - 1, self.y + y_pos_align + 1, 0, 1, 1, x_offset, y_offset}})
  GAME.gfx_q:push({love.graphics.draw, {self.text, self.x + x_pos_align + 2, self.y + y_pos_align - 1, 0, 1, 1, x_offset, y_offset}})
  GAME.gfx_q:push({love.graphics.draw, {self.text, self.x + x_pos_align + 2, self.y + y_pos_align + 1, 0, 1, 1, x_offset, y_offset}})
  GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
  --GAME.gfx_q:push({love.graphics.draw, {self.text, self.x + x_pos_align, self.y + y_pos_align, 0, 1, 1, x_offset, y_offset}})
  GAME.gfx_q:push({love.graphics.draw, {self.text, self.x + x_pos_align + 0, self.y + y_pos_align + 0, 0, 1, 1, x_offset, y_offset}})
  --GAME.gfx_q:push({love.graphics.draw, {self.text, self.x + self.width / 2 + 0, self.y + y_pos_align + 1, 0, 1, 1, x_offset, y_offset}})
  GAME.gfx_q:push({love.graphics.draw, {self.text, self.x + x_pos_align + 1, self.y + y_pos_align + 0, 0, 1, 1, x_offset, y_offset}})
  --GAME.gfx_q:push({love.graphics.draw, {self.text, self.x + x_pos_align + 1, self.y + y_pos_align + 1, 0, 1, 1, x_offset, y_offset}})
  
end

return Button