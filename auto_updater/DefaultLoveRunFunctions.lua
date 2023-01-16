local DefaultLoveRunFunctions = {}

-- This is a copy of the default inner run loop from love
local dt = 0
function DefaultLoveRunFunctions.innerRun()
  -- Process events.
  if love.event then
    love.event.pump()
    for name, a,b,c,d,e,f in love.event.poll() do
      if name == "quit" then
        if not love.quit or not love.quit() then
          return a or 0
        end
      end
      love.handlers[name](a,b,c,d,e,f)
    end
  end

  -- Update dt, as we'll be passing it to update
  if love.timer then dt = love.timer.step() end

  -- Call update and draw
  if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

  if love.graphics and love.graphics.isActive() then
    love.graphics.origin()
    love.graphics.clear(love.graphics.getBackgroundColor())

    if love.draw then love.draw() end

    love.graphics.present()
  end

  if love.timer then love.timer.sleep(0.001) end
end

-- This is a copy of the outer run loop that love uses.
-- We have broken it up into calling a inner function so we can change the inner function in the game love file to override behavior
-- If you change this function also change CustomRun's equivalent method
function DefaultLoveRunFunctions.run()
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

return DefaultLoveRunFunctions