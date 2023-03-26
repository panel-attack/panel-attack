local consts = require("consts")
--@module transitionUtils
-- Helper functions for scene transition animations
local transitionUtils = {}

function transitionUtils.fade(alphaStart, alphaEnd, duration)
  local startTime = love.timer.getTime()
  repeat 
    local now = love.timer.getTime()
    local fadePercent = (now - startTime) / duration
    local alpha = fadePercent * alphaEnd + (1 - fadePercent) * alphaStart
    GAME.gfx_q:push({love.graphics.setColor, {0, 0, 0, alpha}})
    GAME.gfx_q:push({love.graphics.rectangle, {"fill", 0, 0, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT}})
    GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
    coroutine.yield()
  until now >= startTime + duration
end

return transitionUtils