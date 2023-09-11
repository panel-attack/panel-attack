local Label = require("ui.Label")
local consts = require("consts")

-- @module uiUtils
local uiUtils = {}

function uiUtils.createCenteredLabel(labelText)
  local label = Label({label = labelText, translate = false})
  local x = consts.CANVAS_WIDTH / 2
  local y = consts.CANVAS_HEIGHT / 2
  local backgroundPadding = 10
  local width = label.text:getWidth()
  local height = label.text:getHeight()
  
  label.x = x - (width/2) - backgroundPadding
  label.y = y - (height/2) - backgroundPadding
  
  return label
end

return uiUtils