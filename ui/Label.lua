local class = require("class")
local UIElement = require("ui.UIElement")

--@module Label
local Label = class(
  function(self, options)
    self.id = nil -- set in the button manager
    self.x = options.x or 0
    self.y = options.y or 0
    self.width = options.width or 110
    self.height = options.height or 25
    self.label = options.label or "Label"
    self.extra_labels = {}
    self.translate = options.translate or options.translate == nil and true
    self.is_visible = options.is_visible or options.is_visible == nil and true
    
    self.text = options.text or love.graphics.newText(love.graphics.getFont(), self.translate and loc(self.label, unpack(self.extra_labels)) or self.label)
    local text_width, text_height = self.text:getDimensions()
    self.width = math.max(text_width + 6, self.width)
    self.height = math.max(text_height + 6, self.height)
    self.TYPE = "Label"
  end,
  UIElement
)

function Label:draw()
  local dark_gray = .5
  local light_gray = .7
  local alpha = .7
  GAME.gfx_q:push({love.graphics.setColor, {dark_gray, dark_gray, 1, alpha}})
  GAME.gfx_q:push({love.graphics.rectangle, {"fill", self.x, self.y, self.width, self.height}})
  GAME.gfx_q:push({love.graphics.setColor, {light_gray, light_gray, 1, alpha}})
  GAME.gfx_q:push({love.graphics.rectangle, {"line", self.x, self.y, self.width, self.height}})
  GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
  
  local text_width, text_height = self.text:getDimensions()
  GAME.gfx_q:push({love.graphics.draw, {self.text, self.x + self.width / 2, self.y + self.height / 2, 0, 1, 1, text_width / 2, text_height / 2}})
end

return Label