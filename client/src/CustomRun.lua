local manualGc = require("client.lib.batteries.manual_gc")
local prof = require("common.lib.jprof.jprof")

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
CustomRun.runMetrics.updateMemAlloc = 0
CustomRun.runMetrics.graphMemAlloc = 0
CustomRun.runMetrics.drawMemAlloc = 0
CustomRun.runMetrics.presentMemAlloc = 0

CustomRun.runTimeGraph = nil

local maxLeftOverTime = CustomRun.FRAME_RATE / 4
leftover_time = maxLeftOverTime

-- Sleeps just the right amount of time to make our next update step be one frame long.
-- If we have leftover time that hasn't been run yet, it will sleep less to catchup.
function CustomRun.sleep()
  local targetDelay = CustomRun.FRAME_RATE
  -- We want leftover time to be above 0 but less than a quarter frame.
  -- If it goes above that, only wait enough to get it down to that.
  if leftover_time > maxLeftOverTime then
    targetDelay = targetDelay - (leftover_time - maxLeftOverTime)
    targetDelay = math.max(targetDelay, 0)
  end

  local targetTime = CustomRun.runMetrics.previousSleepEnd + targetDelay
  local originalTime = love.timer.getTime()
  local currentTime = originalTime

  local idleTime = targetTime - currentTime
  -- actively collecting garbage is very CPU intensive
  -- only do it while a match is on-going
  -- and only while not profiling for memory allocations
  if not PROFILE_MEMORY and GAME and GAME.battleRoom and GAME.battleRoom.match and GAME.focused and not GAME.battleRoom.match.isPaused then
    local manualGcTime = math.max(0.001, idleTime * config.activeGarbageCollectionPercent)
    prof.push("manual gc", tostring(manualGcTime * 1000) .. "ms")
    -- Spend as much time as necessary collecting garbage, but at least 0.1ms
    -- manualGc itself has a ceiling at which it will stop
    manualGc(manualGcTime)
    currentTime = love.timer.getTime()
    CustomRun.runMetrics.gcDuration = currentTime - originalTime
    originalTime = currentTime
    idleTime = targetTime - currentTime
    prof.pop("manual gc")
  else
    CustomRun.runMetrics.gcDuration = 0
  end

  -- Sleep any remaining amount of time to fill up the frametime to 1/60 of a second
  -- don't sleep the entire remaining idle time though:
  -- calling sleep means to the OS "sleep for AT LEAST"
  -- that means it is never shorter and usually slightly longer
  if idleTime > 0.001 then
    local sleepTime = idleTime - 0.0005
    prof.push("sleep", sleepTime * 1000 .. "ms")
    love.timer.sleep(sleepTime)
    prof.pop("sleep")
  end
  currentTime = love.timer.getTime()

  -- While loop the last little bit to be more accurate
  prof.push("busy loop")
  while currentTime < targetTime do
    currentTime = love.timer.getTime()
  end
  prof.pop("busy loop")

  CustomRun.runMetrics.previousSleepEnd = currentTime
  CustomRun.runMetrics.sleepDuration = currentTime - originalTime
end

function CustomRun.processEvents()
  if love.event then
    love.event.pump()
    for name, a, b, c, d, e, f in love.event.poll() do
      if name == "quit" then
        if not love.quit or not love.quit() then
          return a or 0, b
        end
      end
      love.handlers[name](a, b, c, d, e, f)
    end
  end
end

-- This is our custom version of run that uses a custom sleep and records metrics.
local dt = 0
local mem = 0
local prevMem = 0
function CustomRun.innerRun()
  local shouldQuit = CustomRun.processEvents()
  if shouldQuit then
    return shouldQuit
  end
  mem = collectgarbage("count")
  prof.push("frame")

  -- Update dt, as we'll be passing it to update
  if love.timer then
    dt = love.timer.step()
    CustomRun.runMetrics.dt = dt
  end

  -- Call update and draw
  if love.update then
    local preUpdateTime = love.timer.getTime()
    prof.push("update")
    love.update(dt) -- will pass 0 if love.timer is disabled
    prof.pop("update")
    CustomRun.runMetrics.updateDuration = love.timer.getTime() - preUpdateTime
    prevMem = mem
    mem = collectgarbage("count")
    CustomRun.runMetrics.updateMemAlloc = mem - prevMem
  end

  local graphicsActive = love.graphics and love.graphics.isActive()
  if graphicsActive then
    love.graphics.origin()
    love.graphics.clear(love.graphics.getBackgroundColor())

    if love.draw then
      local preDrawTime = love.timer.getTime()
      prof.push("draw")
      love.draw()
      prof.pop("draw")
      CustomRun.runMetrics.drawDuration = love.timer.getTime() - preDrawTime
      prevMem = mem
      mem = collectgarbage("count")
      CustomRun.runMetrics.drawMemAlloc = mem - prevMem
    end

    -- draw the RunTimeGraph here so it doesn't contribute to the love.draw load
    if CustomRun.runTimeGraph then
      local preGraphDrawTime = love.timer.getTime()
      CustomRun.runTimeGraph:draw()
      CustomRun.runMetrics.graphDuration = CustomRun.runMetrics.graphDuration + (love.timer.getTime() - preGraphDrawTime)
      prevMem = mem
      mem = collectgarbage("count")
      CustomRun.runMetrics.graphMemAlloc = CustomRun.runMetrics.graphMemAlloc + mem - prevMem
    end

    local prePresentTime = love.timer.getTime()
    prof.push("present")
    love.graphics.present()
    prof.pop("present")
    CustomRun.runMetrics.presentDuration = love.timer.getTime() - prePresentTime
    prevMem = mem
    mem = collectgarbage("count")
    CustomRun.runMetrics.presentMemAlloc = mem - prevMem
  end

  if love.timer then
    prof.push("sleep")
    CustomRun.sleep()
    prof.pop("sleep")
    mem = collectgarbage("count")
  end

  if CustomRun.runTimeGraph ~= nil then
    local preGraphUpdateTime = love.timer.getTime()
    CustomRun.runTimeGraph:updateWithMetrics(CustomRun.runMetrics)
    CustomRun.runMetrics.graphDuration = love.timer.getTime() - preGraphUpdateTime
    prevMem = mem
    mem = collectgarbage("count")
    CustomRun.runMetrics.graphMemAlloc = mem - prevMem
  end
  prof.pop("frame")
end

-- This is a copy of the outer run loop that love 12 uses.
-- We have broken it up into calling a inner function so we can change the inner function in the game love file to override behavior
-- If you change this function also change DefaultLoveRunFunction's equivalent method
function CustomRun.run()
  if love.load then love.load(love.parsedGameArguments, love.rawGameArguments) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

  dt = 0

  -- Main loop time.
  return function()
    if love.runInternal then
      local result = love.runInternal()
      if result then
        return result
      end
    end
  end
end

return CustomRun