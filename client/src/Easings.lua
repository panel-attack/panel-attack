-- Easing functions are functions that calculate a value progress of a function at a certain time progress of a transformation
-- The time progress is measured as a relative time progress with 0 representing no time passed and 1 representing all time passed
-- The value progress is returned as a relative value between 0 (represents the start value) and 1 (represents the end value)
local Easings = {}

Easings.linear = function(progress)
  return progress
end

Easings.getQuadIn = function()
  -- progress is a number value between 0 and 1
  -- 0 is started, 1 is ended
  return function(progress)
    return progress * progress
  end
end

Easings.getSineIn = function()
  -- progress is a number value between 0 and 1
  -- 0 is started, 1 is ended
  return function(progress)
    return 1 - math.cos(progress * math.pi / 2)
  end
end

return Easings