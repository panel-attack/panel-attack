local TCP_sock = nil
local leftovers = ''

function flush_socket()
    local success 
    -- lol, if it returned successfully then that's bad!
    if not success then
        error('the connection closed unexpectedly')
    end

	local data = TCP_sock:receive('*a')
    leftovers = leftovers .. data
end

function close_socket()
    if TCP_sock then
        TCP_sock:close()
    end

    TCP_sock = nil
end

function get_message()
    if string.len(leftovers) == 0 then
        return nil
    end

    local kind, gap, length = string.sub(leftovers,1,1), 0
    local byte = string.byte
    local type_to_length = {G=1, H=1, N=1, E=4, P=121, O=121, I=2, Q=121, 
						R=121, L=2, U=2}

    if kind == 'J' then
        if string.len(leftovers) >= 4 then
            length = byte(string.sub(leftovers,2,2)) * 65536 +
            	byte(string.sub(leftovers,3,3)) * BITS_256 +
            	byte(string.sub(leftovers,4,4))
            print('json message has length '.. length)
            gap = 3
        else
            return nil
        end
    else
        length = type_to_length[kind] - 1
    end

    if length + gap + 1 > string.len(leftovers) then
        return nil
    end

    local devolution = string.sub(leftovers,2+gap,length+gap+1)
    leftovers = string.sub(leftovers,length+gap+2)

    return kind, devolution
end

local lag_queue = Queue()

function send_net(...)
    if not STONER_MODE then
        TCP_sock:send(...)
    else
        lag_queue:push({...})

        if lag_queue:len() == 70 then
            TCP_sock:send(unpack(lag_queue:pop()))
        end
    end
end

BITS_256 = 256

function send_json(obj)
    local json = json.encode(obj)
    local json_length = json:len()
    local floor = math.floor
    local char = string.char
    local prefix = 'J' .. char(floor(json_length/65536)) .. 
		char(floor((json_length/BITS_256)%BITS_256)) .. char(json_length%BITS_256)

    send_net(prefix..json)
end

function undo_stonermode()
    while lag_queue:len() ~= 0 do
        TCP_sock:send(unpack(lag_queue:pop()))
    end
end

local got_H = false

local process_message = {
    L = function(s) P2_level = ({['0']=10})[s] or (s+0) end,
    --G=function(s) got_opponent = true end,
    H = function(s) got_H = true end,
    N = function(s) error('Server told us to upgrade the game at ' .. 
        'burke.ro/panel.zip (for burke.ro server) or the TetrisAttackOnline ' ..
        "Discord (for Jon's Server)") end,
    P = function(s) P1.panel_buffer = P1.panel_buffer..s end,
    O = function(s) P2.panel_buffer = P2.panel_buffer..s end,
    -- used for P1's inputs when spectating.
    U = function(s) P1.input_buffer = P1.input_buffer..s end,  
    I = function(s) P2.input_buffer = P2.input_buffer..s end,
    Q = function(s) P1.gpanel_buffer = P1.gpanel_buffer..s end,
    R = function(s) P2.gpanel_buffer = P2.gpanel_buffer..s end,
    --connection_up_time counts 'E' messages, not seconds
    E = function(s) send_net('F'..s) connection_up_time = connection_up_time + 1 end,  
    J = function(s)
        local current_message = json.decode(s)
        this_frame_messages[#this_frame_messages+1] = current_message
        print('JSON LOL '..s)

        if not current_message then
            error('Error in network.lua process_message\nMessage: \''..
            (s or 'nil')..'\'\ncould not be decoded')
        end

        if current_message.spectators then
            spectator_list = current_message.spectators
            spectators_string = spectator_list_string(
                current_message.spectators)
        end

    end
}

function network_init(ip)
    TCP_sock = socket.tcp()
    TCP_sock:settimeout(7)

    if not TCP_sock:connect(ip,49569) then
        error('Failed to connect =(')
    end

    TCP_sock:settimeout(0)
    got_H = false
    send_net('H'..VERSION)
    assert(config.name and config.level and config.character and 
           config.save_replays_publicly)

    send_json({name=config.name, level=config.level, character=config.character, 
              save_replays_publicly = config.save_replays_publicly})
end

function connection_is_ready()
    return got_H and #this_frame_messages > 0
end

function do_messages()
    flush_socket()

    while true do
        local kind, data = get_message()

        if typ then
            if kind ~= 'I' and kind ~= 'U' then
                print('Got message '.. kind ..' '..data)
            end

            process_message[kind](data)

            if kind == 'J' then
                if this_frame_messages[#this_frame_messages].replay_of_match_so_far then
                    --print('***BREAKING do_messages because received a replay')
                    break  -- don't process any more messages this frame
                   -- we need to initialize P1 and P2 before we do any 
				   --I or U messages
                end
            end

            if kind == 'U' then
                kind = 'in_buf'
            end

            if P1 and P1.mode and replay[P1.mode][kind] then
                replay[P1.mode][kind]=replay[P1.mode][kind]..data
            end
        else
            break
        end
    end
end

function request_game(name)
    send_json({game_request={sender=config.name, receiver=name}})
end

function request_spectate(roomNr)
    send_json({spectate_request={sender=config.name, roomNumber = roomNr}})
end

function ask_for_panels(prev_panels)
    if TCP_sock then
        send_net('P'..tostring(P1.NCOLORS)..prev_panels)
    else
        make_local_panels(P1, prev_panels)
    end
end

function ask_for_gpanel(prev_panels)
    if TCP_sock then
        send_net('Q'..tostring(P1.NCOLORS)..prev_panels)
    else
        make_local_gpanels(P1, prev_panels)
    end
end

function make_local_panels(stack, prev_panels)
    local ret = make_panels(stack.NCOLORS, prev_panels, stack)

    stack.panel_buffer = stack.panel_buffer .. ret
    
	local replay = replay[P1.mode]

    if replay and replay.pan_buf then
        replay.pan_buf = replay.pan_buf .. ret
    end
end

function make_local_gpanels(stack, prev_panels)
    ret = make_gpanels(stack.NCOLORS, prev_panels)
    stack.gpanel_buffer = stack.gpanel_buffer .. ret
    local replay = replay[P1.mode]

    if replay and replay.gpan_buf then
        replay.gpan_buf = replay.gpan_buf .. ret
    end
end

function Stack.send_controls(self)
  local k = keyboard[self.which]
  local to_send = base64encode[
    ((keys[k.raise_faster1] or keys[k.raise_faster2] or this_frame_keys[k.raise_faster1]
      or this_frame_keys[k.raise_faster2]) and 32 or 0) +
    ((this_frame_keys[k.swap1] or this_frame_keys[k.swap2]) and 16 or 0) +
    ((keys[k.up] or this_frame_keys[k.up]) and 8 or 0) +
    ((keys[k.down] or this_frame_keys[k.down]) and 4 or 0) +
    ((keys[k.left] or this_frame_keys[k.left]) and 2 or 0) +
    ((keys[k.right] or this_frame_keys[k.right]) and 1 or 0)+1]

    if TCP_sock then
        send_net('I'..to_send)
    end

    local replay = replay[self.mode]

    if replay and replay.in_buf then
        replay.in_buf = replay.in_buf .. to_send
    end

    return to_send
end
