socket = require "socket"

function love.load()
    math.randomseed(os.time(os.date("*t")))

    -- set resolution!
    love.graphics.setMode(820,615)

    -- load files!
    love.filesystem.load("class.lua")()
    love.filesystem.load("globals.lua")()
    love.filesystem.load("engine.lua")()
    love.filesystem.load("graphics.lua")()
    love.filesystem.load("input.lua")()

    -- load images and set up stuff
    graphics_init()
    -- sets key repeat (well that was a bad idea)
    -- input_init()

    TCP_sock = socket.tcp()
    TCP_sock:settimeout(7)
    if not TCP_sock:connect("50.17.236.201"--[["127.0.0.1"--]],49569) then
        error("Failed to connect =(")
    end
    TCP_sock:settimeout(0)
    TCP_sock:send("Hlol")

    -- create mainloop coroutine
    mainloop = coroutine.create(fmainloop)
end

function love.draw()
    coroutine.resume(mainloop)
    if(crash_now) then
        error(crash_error)
    end
end

function flush_socket()
    junk,err,data = TCP_sock:receive('*a')
    -- lol, if it returned successfully then that's bad!
    if not err then
        error("the connection closed unexpectedly")
    end
    leftovers = leftovers..data
end

function get_message()
    if string.len(leftovers) == 0 then
        return nil
    end
    local typ = string.sub(leftovers,1,1)
    local len = type_to_length[typ]
    if len > string.len(leftovers) then
        return nil
    end
    local ret = string.sub(leftovers,2,type_to_length[typ])
    leftovers = string.sub(leftovers,type_to_length[typ]+1)
    return typ, ret
end

process_message = {
    G=function(s)
        opponent_ready = true
        ask_for_panels("000000")
    end,
    H=function(s) end,
    N=function(s) error("Server told us to fuck off") end,
    P=function(s) P1.panel_buffer = P1.panel_buffer..s end,
    O=function(s) P2.panel_buffer = P2.panel_buffer..s end,
    I=function(s) P2.input_buffer = P2.input_buffer..s end}

function do_messages()
    flush_socket()
    while true do
        typ, data = get_message()
        if typ then
            process_message[typ](data)
        else
            break
        end
    end
end

function ask_for_panels(prev_panels)
    TCP_sock:send("P"..tostring(P1.NCOLORS)..prev_panels)
end

function send_controls()
    local t = function(k) if k then return "1" end return "0" end
    local framecount = P1.CLOCK..""
    while string.len(framecount) ~= 6 do
        framecount = "0"..framecount
    end
    TCP_sock:send("I"..framecount..
        t(keys[k_up])..t(keys[k_down])..t(keys[k_left])..t(keys[k_right])..
        t(keys[k_swap1])..t(keys[k_swap2])..t(keys[k_raise1])..t(keys[k_raise2])..
        t(protected_keys[k_up])..t(protected_keys[k_down])..t(protected_keys[k_left])..
        t(protected_keys[k_right])..t(protected_keys[k_swap1])..t(protected_keys[k_swap2])..
        t(protected_keys[k_raise1])..t(protected_keys[k_raise2]))
end

function fmainloop()
    P1 = Stack()
    P2 = Stack()
    P2.pos_x = 172

    while P1.panel_buffer == "" or P2.panel_buffer == "" do
        local status, err = pcall(function ()
            do_messages()
        end)
        if not status then
            crash_error = err
            crash_now = true
        end
        coroutine.yield()
    end
    while true do
        local status, err = pcall(function ()
            do_messages()
            --stage_background()
            P1:local_run()
            P2:foreign_run()
            if P1.game_over then
                error("game over lol")
            end
            --local data,err,leftovers = TCP_sock:receive('*a')
            --sock_buffer = sock_buffer + leftovers
            --love.graphics.print("from server: "..tostring(data).." "..tostring(err).." "..tostring(leftovers), 400, 440)
            --love.graphics.print(tostring(TCP_sock:send("blah")), 400, 460)
        end)
        if not status then
            crash_error = err
            crash_now = true
        end
        coroutine.yield()
    end
end
