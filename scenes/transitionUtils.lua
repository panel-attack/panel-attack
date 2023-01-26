local consts = require("consts")
local globals = require("globals")
--@module transitionUtils
local transitionUtils = {}

function transitionUtils.fade(alphaStart, alphaEnd, duration)
  local startTime = love.timer.getTime()
  repeat 
    local now = love.timer.getTime()
    local fadePercent = (now - startTime) / duration
    local alpha = fadePercent * alphaEnd + (1 - fadePercent) * alphaStart
    GAME.gfx_q:push({love.graphics.setColor, {0, 0, 0, alpha}})
    GAME.gfx_q:push({love.graphics.rectangle, {"fill", 0, 0, canvas_width, canvas_height}})
    GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
    coroutine.yield()
  until now >= startTime + duration
end

return transitionUtils