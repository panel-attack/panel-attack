local consts = require("consts")
--@module transitions
local transitions = {}

function transitions.fade(alpha_start, alpha_end, step)
  for alpha = alpha_start, alpha_end, step do
    GAME.gfx_q:push({love.graphics.setColor, {0, 0, 0, alpha}})
    GAME.gfx_q:push({love.graphics.rectangle, {"fill", 0, 0, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT}})
    GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
    coroutine.yield()
  end
end

return transitions