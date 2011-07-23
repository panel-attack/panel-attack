socket = require("socket")
require("class")
require("queue")
require("globals")
require("engine")
require("graphics")
require("input")
require("network")
require("mainloop")

local N_FRAMES = 0

function love.run()
  love.load(arg)

  local dt  = 0        -- time for current frame
  local tau = 10       -- initial value for delay between frames

  while true do
    love.timer.step()
    dt = math.min(0.1, love.timer.getDelta() )

    love.graphics.clear()
    love.update(dt)
    love.draw()
    --love.graphics.print("FPS: ["..love.timer.getFPS().."] delay: ["..math.floor(tau).."ms] idle:["..math.floor(100 * (tau/1000)/dt).."%]", 10, 10)

    if(N_FRAMES > 100) then
      tau = tau + (love.timer.getFPS()-60)*0.2*dt
    end

    for e,a,b,c in love.event.poll() do
      if e == "q" then
        if love.audio then love.audio.stop() end
        return
      end
      love.handlers[e](a,b,c)
    end

    love.timer.sleep(tau)
    love.graphics.present()

    N_FRAMES = N_FRAMES + 1
  end
end


function love.load()
  math.randomseed(os.time(os.date("*t")))
  graphics_init() -- load images and set up stuff
  mainloop = coroutine.create(fmainloop)
end

function love.update()
  local status, err = coroutine.resume(mainloop)
  if not status then
    error(err)
  end
  this_frame_keys = {}
end

function love.draw()
  for i=gfx_q.first,gfx_q.last do
    gfx_q[i][1](unpack(gfx_q[i][2]))
  end
  gfx_q:clear()
  love.graphics.print("FPS: "..love.timer.getFPS(),315,115)
end
