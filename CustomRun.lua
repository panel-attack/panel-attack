
local CustomRun = {}
CustomRun.FRAME_RATE = 1 / 60
CustomRun.runMetrics = {}
CustomRun.runMetrics.previousSleepEnd = 0
CustomRun.runMetrics.dt = 0
CustomRun.runMetrics.sleepDuration = 0
CustomRun.runMetrics.updateDuration = 0
CustomRun.runMetrics.drawDuration = 0
CustomRun.runMetrics.presentDuration = 0
CustomRun.runTimeGraph = nil

leftover_time = 0

-- Sleeps just the right amount of time to make our next update step be one frame long.
-- If we have leftover time that hasn't been run yet, it will sleep less to catchup.
function CustomRun:sleep()

  local targetDelay = CustomRun.FRAME_RATE
  -- We want leftover time to be above 0 but less than a quarter frame.
  -- If it goes above that, only wait enough to get it down to that.
  local maxLeftOverTime = CustomRun.FRAME_RATE / 4
  if leftover_time > maxLeftOverTime then
    targetDelay = targetDelay - (leftover_time - maxLeftOverTime)
    targetDelay = math.max(targetDelay, 0)
  end

  local targetTime = CustomRun.runMetrics.previousSleepEnd + targetDelay
  local originalTime = love.timer.getTime()
  local currentTime = originalTime

  -- Sleep a percentage of our time to wait to save cpu
  local sleepRatio = .99
  local sleepTime = (targetTime - currentTime) * sleepRatio
  if love.timer and sleepTime > 0 then
    love.timer.sleep(sleepTime)
  end
  currentTime = love.timer.getTime()

  -- While loop the last little bit to be more accurate
  while currentTime < targetTime do
    currentTime = love.timer.getTime()
  end

  CustomRun.runMetrics.previousSleepEnd = currentTime
  CustomRun.runMetrics.sleepDuration = currentTime - originalTime
end

-- This is our custom version of run that uses a custom sleep and records metrics.
local dt = 0
function CustomRun.innerRun()

  if love.timer then
    CustomRun.sleep()
  end

  -- Process events.
  if love.event then
    love.event.pump()
    for name, a, b, c, d, e, f in love.event.poll() do
      if name == "quit" then
        if not love.quit or not love.quit() then
          return a or 0
        end
      end
      love.handlers[name](a, b, c, d, e, f)
    end
  end

  -- Update dt, as we'll be passing it to update
  if love.timer then
    dt = love.timer.step()
    CustomRun.runMetrics.dt = dt
  end

  -- Call update and draw
  if love.update then
    local preUpdateTime = love.timer.getTime()
    love.update(dt) -- will pass 0 if love.timer is disabled
    CustomRun.runMetrics.updateDuration = love.timer.getTime() - preUpdateTime
  end

  local graphicsActive = love.graphics and love.graphics.isActive()
  if graphicsActive then
    love.graphics.origin()
    love.graphics.clear(love.graphics.getBackgroundColor())

    if love.draw then
      local preDrawTime = love.timer.getTime()
      love.draw()
      CustomRun.runMetrics.drawDuration = love.timer.getTime() - preDrawTime
    end

    local prePresentTime = love.timer.getTime()
    love.graphics.present()
    CustomRun.runMetrics.presentDuration = love.timer.getTime() - prePresentTime
  end

  if CustomRun.runTimeGraph ~= nil then
    CustomRun.runTimeGraph:updateWithMetrics(CustomRun.runMetrics)
  end
end

-- This is a copy of the outer run loop that love uses.
-- We have broken it up into calling a inner function so we can change the inner function in the game love file to override behavior
-- If you change this function also change DefaultLoveRunFunction's equivalent method
function CustomRun.run()
  if love.load then
    love.load(love.arg.parseGameArguments(arg), arg)
  end

  -- We don't want the first frame's dt to include time taken by love.load.
  if love.timer then
    love.timer.step()
  end

  dt = 0

  -- Main loop time.
  return function()
    if love.pa_runInternal then
      local result = love.pa_runInternal()
      if result then
        return result
      end
    end
  end
end

return CustomRun