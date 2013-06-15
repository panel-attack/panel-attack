socket = require("socket")
json = require("dkjson")
require("util")
require("class")
require("queue")
require("globals")
require("save")
require("engine")
require("graphics")
require("input")
require("network")
require("puzzles")
require("mainloop")

local N_FRAMES = 0
local tau = 10/1000
local dt_for_delay = 0
local min = math.min

local love_timer_sleep = love.timer.sleep -- in s (like >=0.8.0)
if love._version:find("^0%.[0-7]%.") then -- if version < 0.8.0
   -- love.timer.sleep in ms
   love_timer_sleep = function(s) love.timer.sleep(s*1000) end
end

--[[function love.run()
  love.load(arg)

  local dt  = 0        -- time for current frame
  local tau = 10       -- initial value for delay between frames
  local USE_FB = false
  if USE_FB then
    local fb = love.graphics.newFramebuffer()
    local fb2 = love.graphics.newFramebuffer()
  end

  while true do
    love.timer.step()
    dt = min(0.1, love.timer.getDelta() )

    if USE_FB then
      love.graphics.setRenderTarget(fb)
    end
    love.graphics.clear()
    love.update(dt)
    love.draw()
    if USE_FB then
      love.graphics.setRenderTarget()
      love.graphics.draw(fb,0,0)
    end
    if true then else
      love.graphics.setRenderTarget(fb2)
      love.graphics.draw(fb,0,615,0,1,-1)
      local fnum = N_FRAMES..""
      while string.len(fnum) < 5 do
        fnum = "0" .. fnum
      end
      love.graphics.setRenderTarget()
      love.filesystem.write("frame"..fnum..".png",
          fb2:getImageData():encode("png"))
    end

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
    joystick_ax()
    key_counts()

    love_timer_sleep(tau)
    love.graphics.present()

    N_FRAMES = N_FRAMES + 1

  end
end--]]

function love.load()
  math.randomseed(os.time())
  for i=1,4 do math.random() end
  read_key_file()
  read_conf_file() -- TODO: stop making new config files
  replay = {}
  read_replay_file()
  graphics_init() -- load images and set up stuff
  mainloop = coroutine.create(fmainloop)
end

function love.update(dt)
  dt_for_delay = dt
  joystick_ax()
  key_counts()
  gfx_q:clear()
  local status, err = coroutine.resume(mainloop)
  if not status then
    error(err..'\n'..debug.traceback(mainloop))
  end
  this_frame_keys = {}
  this_frame_unicodes = {}
  this_frame_messages = {}
end

function love.draw()
  love.graphics.setColor(28, 28, 28)
  love.graphics.rectangle("fill",-5,-5,900,900)
  love.graphics.setColor(255, 255, 255)
  for i=gfx_q.first,gfx_q.last do
    gfx_q[i][1](unpack(gfx_q[i][2]))
  end
  love.graphics.print("FPS: "..love.timer.getFPS(),315,115)


  if(N_FRAMES > 300) then
    tau = tau + (love.timer.getFPS()-60)*0.2*dt_for_delay
  end
  love_timer_sleep(tau)
  N_FRAMES = N_FRAMES + 1
end
