------------
--- Main Module
--- Draw windown in screen and set up the game
-- @module main

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
require("consts")
require("sound")
require("timezones")
require("gen_panels")

--- This function create a routine and load the game
-- @function love.load
-- @param nil
-- @return nil
function love.load()

    read_key_file()

    mainloop = coroutine.create(load_game_resources)

end

-- These variables represent x and y axis
-- The values then between 0 and default_width and default_height
local last_x = 0
local last_y = 0

-- variation of arrow
local input_delta = 0.0

-- flag for hidden arrow
local pointer_hidden = false

--- This function update the game state for each frame
-- @function love.update
-- @param time since the last update
-- @return nil
function love.update(dt)

    -- Verify if time has no negative values
    assert(dt > 0, "Update screen interval is negative")

    -- Hidden arrow or make then visible
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

    if consuming_timesteps then
        leftover_time = leftover_time + dt
    end

    joystick_ax()

    if not consuming_timesteps then
        key_counts()
    end

    gfx_q:clear()

    -- View if mainloop has no nil value
    assert(mainloop ~= nil)

    local status, err = coroutine.resume(mainloop)

    if not status then
        error(err..'\n'..debug.traceback(mainloop))
    end

    if not consuming_timesteps then
        this_frame_keys = {}
        this_frame_unicodes = {}
    end

    this_frame_messages = {}

end

-- count frames
local N_FRAMES = 0

-- Screen of the game
local canvas = love.graphics.newCanvas(default_width, default_height)

--- Write objects in canvas
-- @function love.draw
-- @param nil
-- @return nil
function love.draw()

    -- Verify if type is correct
    assert(type(canvas) == "userdata", "Canvas is not userdata")
    love.graphics.setCanvas(canvas)

    -- Default background color for canvas
    local RED_VALUE = 28
    local GREEN_VALUE = 28
    local BLUE_VALUE = 28

    love.graphics.setBackgroundColor(RED_VALUE, GREEN_VALUE, BLUE_VALUE)
    love.graphics.clear()

    for index=gfx_q.first, gfx_q.last do
        gfx_q[index][1](unpack(gfx_q[index][2]))
    end

    -- position of box for FPS information
    local X_AXIS_PRINT = 315
    local Y_AXIS_PRINT = 115

    love.graphics.print("FPS: "..love.timer.getFPS(), X_AXIS_PRINT, Y_AXIS_PRINT)

    -- update number of frames
    N_FRAMES = N_FRAMES + 1

    love.graphics.setCanvas()
    love.graphics.clear()

    x, y, width, height = scale_letterbox(love.graphics.getWidth(), love.graphics.getHeight(), 4, 3)
    love.graphics.draw(canvas, x, y, 0, width/default_width, height/default_height)

end
