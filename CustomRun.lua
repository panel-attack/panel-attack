local manualGc = require("libraries.batteries.manual_gc")

local CustomRun = {}
CustomRun.FRAME_RATE = 1 / 60
CustomRun.runMetrics = {}
CustomRun.runMetrics.previousSleepEnd = 0
CustomRun.runMetrics.dt = 0
CustomRun.runMetrics.updateDuration = 0
CustomRun.runMetrics.graphDuration = 0
CustomRun.runMetrics.drawDuration = 0
CustomRun.runMetrics.presentDuration = 0
CustomRun.runMetrics.gcDuration = 0
CustomRun.runMetrics.sleepDuration = 0

CustomRun.runTimeGraph = nil

leftover_time = 0

-- Sleeps just the right amount of time to make our next update step be one frame long.
-- If we have leftover time that hasn't been run yet, it will sleep less to catchup.
function CustomRun.sleep()

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

  local idleTime = targetTime - currentTime
  -- actively collecting garbage is very CPU intensive
  -- only do it if the game has uncharacteristally high memory 
  if collectgarbage("count") / 1024 > 20 or
  -- or while a match is on-going
    (GAME and GAME.match and not GAME.gameIsPaused and GAME.focused) then
    -- Spend as much time as necessary collecting garbage, but at least 0.1ms
    -- manualGc itself has a ceiling at which it will stop
    manualGc(math.max(0.0001, idleTime * 0.99))
    currentTime = love.timer.getTime()
    CustomRun.runMetrics.gcDuration = currentTime - originalTime
    originalTime = currentTime
    idleTime = targetTime - currentTime
  else
    CustomRun.runMetrics.gcDuration = 0
  end

  -- Sleep any remaining amount of time to fill up the frametime to 1/60 of a second
  -- On most machines GC will have reduced the remaining idle time to near nothing
  -- But strong machines may exit garbage collection early and need to sleep the remaining time
  if idleTime > 0 then
    love.timer.sleep(idleTime * 0.99)
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

    -- draw the RunTimeGraph here so it doesn't contribute to the love.draw load
    if CustomRun.runTimeGraph then
      local preGraphDrawTime = love.timer.getTime()
      CustomRun.runTimeGraph:draw()
      CustomRun.runMetrics.graphDuration = CustomRun.runMetrics.graphDuration + (love.timer.getTime() - preGraphDrawTime)
    end
    
    local prePresentTime = love.timer.getTime()
    love.graphics.present()
    CustomRun.runMetrics.presentDuration = love.timer.getTime() - prePresentTime
  end

  if love.timer then
    CustomRun.sleep()
  end

  if CustomRun.runTimeGraph ~= nil then
    local preGraphUpdateTime = love.timer.getTime()
    CustomRun.runTimeGraph:updateWithMetrics(CustomRun.runMetrics)
    CustomRun.runMetrics.graphDuration = love.timer.getTime() - preGraphUpdateTime
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