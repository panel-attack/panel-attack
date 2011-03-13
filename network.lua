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

function network_init()
    TCP_sock = socket.tcp()
    TCP_sock:settimeout(7)
    if not TCP_sock:connect(--[["50.17.236.201"--]]"127.0.0.1",49569) then
        error("Failed to connect =(")
    end
    TCP_sock:settimeout(0)
    TCP_sock:send("Hlol")
end

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
