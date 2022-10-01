local consts = require("consts")
--@module transitions
local transitionUtils = {}

function transitionUtils.fade(alpha_start, alpha_end, duration)
  local start_time = love.timer.getTime()
  repeat 
    local now = love.timer.getTime()
    local t = (now - start_time) / duration
    local alpha = t * alpha_end + (1 - t) * alpha_start
    GAME.gfx_q:push({love.graphics.setColor, {0, 0, 0, alpha}})
    GAME.gfx_q:push({love.graphics.rectangle, {"fill", 0, 0, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT}})
    GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
    coroutine.yield()
  until now >= start_time + duration
end

return transitionUtils