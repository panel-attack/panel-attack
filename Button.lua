local class = require("class")
local button_manager = require("button_manager")

--@module Button
local Button = class(
  function(self, options)
    self.id = nil -- set in the button manager
    self.x = options.x or 0
    self.y = options.y or 0
    self.width = options.width or 100
    self.height = options.height or 30
    self.label = options.label or "Button"
    self.onClick = options.onClick or function() 
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
    end
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
  GAME.gfx_q:push({love.graphics.setColor, {dark_gray, dark_gray, dark_gray, alpha}})
  GAME.gfx_q:push({love.graphics.rectangle, {"fill", self.x, self.y, self.width, self.height}})
  GAME.gfx_q:push({love.graphics.setColor, {light_gray, light_gray, light_gray, alpha}})
  GAME.gfx_q:push({love.graphics.rectangle, {"line", self.x, self.y, self.width, self.height}})
  GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
  
  local font = love.graphics.getFont()
	local text_width = font:getWidth(self.label)
	local text_height = font:getHeight()
  GAME.gfx_q:push({love.graphics.print, {self.label, self.x + self.width / 2, self.y + self.height / 2, 0, 1, 1, text_width / 2, text_height / 2}})
end

return Button