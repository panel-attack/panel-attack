local class = require("class")
local buttonManager = require("ui.buttonManager")
local Button = require("ui.Button")

local TEXT_WIDTH_PADDING = 15
local TEXT_HEIGHT_PADDING = 6

-- A TextButton is a button that sets itself apart from Button by automatically scaling its own size to fit the text inside
-- This is different from the regular button that scales its content to fit inside itself
local TextButton = class(function(self, options)
  -- text alignments settings
  -- must be one of the following values:
  -- left, right, center
  self.halign = options.halign or "center"
  self.valign = options.valign or "center"

  self.label = options.label
  self:addChild(self.label)

  -- stretch to fit text
  self.width = math.max(self.label.width + TEXT_WIDTH_PADDING, self.width)
  self.height = math.max(self.label.height + TEXT_HEIGHT_PADDING, self.height)

  local xAlignments = {
    center = self.width / 2,
    left = self.label.width / 2 + TEXT_WIDTH_PADDING,
    right = self.width - self.label.width / 2 - TEXT_WIDTH_PADDING,
  }
  local yAlignments = {
    center = self.height / 2,
    top = self.label.height / 2 + TEXT_HEIGHT_PADDING,
    bottom = self.height - self.label.height / 2 - TEXT_HEIGHT_PADDING
  }

  self.label.x = xAlignments[self.halign]
  self.label.y = yAlignments[self.valign]

  buttonManager.buttons[self.id] = self.isVisible and self or nil
  self.TYPE = "Button"
end, Button)

return TextButton
