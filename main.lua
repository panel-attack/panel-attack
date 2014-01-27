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

  N_FRAMES = N_FRAMES + 1
end
