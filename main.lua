socket = require("socket")
json = require("dkjson")
require("util")
require("consts")
require("class")
require("queue")
require("globals")
require("character") -- after globals!
require("stage") -- after globals!
require("save")
require("engine")
require("localization")
require("graphics")
require("input")
require("network")
require("puzzles")
require("mainloop")
require("sound")
require("timezones")
require("gen_panels")

global_canvas = love.graphics.newCanvas(canvas_width, canvas_height)

local last_x = 0
local last_y = 0
local input_delta = 0.0
local pointer_hidden = false

function love.load()
  math.randomseed(os.time())
  for i=1,4 do math.random() end
  read_key_file()
  mainloop = coroutine.create(fmainloop)
end

function love.update(dt)
  if love.mouse.getX() == last_x and love.mouse.getY() == last_y then
    if not pointer_hidden then
      if input_delta > mouse_pointer_timeout then
        pointer_hidden = true
        love.mouse.setVisible(false)
      else
       input_delta = input_delta + dt
      end
    end
  else
    last_x = love.mouse.getX()
    last_y = love.mouse.getY()
    input_delta = 0.0
    if pointer_hidden then
      pointer_hidden = false
      love.mouse.setVisible(true)
    end
  end

  leftover_time = leftover_time + dt

  local status, err = coroutine.resume(mainloop)
  if not status then
    error(err..'\n'..debug.traceback(mainloop))
  end
  this_frame_messages = {}

  update_music()
end

function love.draw()
  -- if not main_font then
    -- main_font = love.graphics.newFont("Oswald-Light.ttf", 15)
  -- end
  -- main_font:setLineHeight(0.66)
  -- love.graphics.setFont(main_font)
  if foreground_overlay then
    local scale = canvas_width/math.max(foreground_overlay:getWidth(),foreground_overlay:getHeight()) -- keep image ratio
    menu_drawf(foreground_overlay, canvas_width/2, canvas_height/2, "center", "center", 0, scale, scale )
  end

  love.graphics.setBlendMode("alpha", "alphamultiply")
  love.graphics.setCanvas(global_canvas)
  love.graphics.setBackgroundColor(unpack(global_background_color))
  love.graphics.clear()

  for i=gfx_q.first,gfx_q.last do
    gfx_q[i][1](unpack(gfx_q[i][2]))
  end
  gfx_q:clear()
  if config ~= nil and config.show_fps then
    love.graphics.print("FPS: "..love.timer.getFPS(),1,1)
  end

  love.graphics.setCanvas()
  love.graphics.clear(love.graphics.getBackgroundColor())
  x, y, w, h = scale_letterbox(love.graphics.getWidth(), love.graphics.getHeight(), 16, 9)
  love.graphics.setBlendMode("alpha","premultiplied")
  love.graphics.draw(global_canvas, x, y, 0, w / canvas_width, h / canvas_height)

  -- draw background and its overlay
  local scale = canvas_width/math.max(background:getWidth(),background:getHeight()) -- keep image ratio
  menu_drawf(background, canvas_width/2, canvas_height/2, "center", "center", 0, scale, scale )
  if background_overlay then
    local scale = canvas_width/math.max(background_overlay:getWidth(),background_overlay:getHeight()) -- keep image ratio
    menu_drawf(background_overlay, canvas_width/2, canvas_height/2, "center", "center", 0, scale, scale )
  end
end
