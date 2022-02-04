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
    self.color = {.3, .3, .3, .7}
    self.onClick = options.onClick or function() 
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
    end
    
    local text_width, text_height = self.text:getDimensions()
    self.width = math.max(text_width + 6, self.width)
    self.height = math.max(text_height + 6, self.height)
    button_manager.add_button(self)
  end
)

function Button:remove()
  button_manager.remove_button(self)
end

function Button:isSelected(x, y)
  return x > self.x and x < self.x + self.width and y > self.y and y < self.y + self.height
end

function Button:draw()
  local dark_gray = .3
  local light_gray = .5
  local alpha = .7
  GAME.gfx_q:push({love.graphics.setColor, self.color})
  GAME.gfx_q:push({love.graphics.rectangle, {"fill", self.x, self.y, self.width, self.height}})
  GAME.gfx_q:push({love.graphics.setColor, {math.min(self.color[1] + .2, 1), math.min(self.color[2] + .2, 1), math.min(self.color[3] + .2, 1), self.color[4]}})
  GAME.gfx_q:push({love.graphics.rectangle, {"line", self.x, self.y, self.width, self.height}})
  GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
  
  local text_width, text_height = self.text:getDimensions()
  GAME.gfx_q:push({love.graphics.draw, {self.text, self.x + self.width / 2, self.y + self.height / 2, 0, 1, 1, text_width / 2, text_height / 2}})
end

return Button