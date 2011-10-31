local TCP_sock = nil
local type_to_length = {G=1, H=1, N=1, P=121, O=121, I=2, Q=121, R=121, L=2}
local leftovers = ""

function flush_socket()
  local junk,err,data = TCP_sock:receive('*a')
  -- lol, if it returned successfully then that's bad!
  if not err then
    error("the connection closed unexpectedly")
  end
  leftovers = leftovers..data
end

function close_socket()
  TCP_sock:close()
  TCP_sock = nil
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

local lag_q = Queue()
function net_send(...)
  if not STONER_MODE then
    TCP_sock:send(...)
  else
    lag_q:push({...})
    if lag_q:len() == 70 then
      TCP_sock:send(unpack(lag_q:pop()))
    end
  end
end

function undo_stonermode()
  while lag_q:len() ~= 0 do
    TCP_sock:send(unpack(lag_q:pop()))
  end
end

local process_message = {
  L=function(s) P2_level = ({["0"]=10})[s] or (s+0) end,
  G=function(s) got_opponent = true end,
  H=function(s) end,
  N=function(s) error("Server told us to fuck off") end,
  P=function(s) P1.panel_buffer = P1.panel_buffer..s end,
  O=function(s) P2.panel_buffer = P2.panel_buffer..s end,
  I=function(s) P2.input_buffer = P2.input_buffer..s end,
  Q=function(s) P1.gpanel_buffer = P1.gpanel_buffer..s end,
  R=function(s) P2.gpanel_buffer = P2.gpanel_buffer..s end}

function network_init(ip)
  TCP_sock = socket.tcp()
  TCP_sock:settimeout(7)
  if not TCP_sock:connect(ip,49569) then
    error("Failed to connect =(")
  end
  TCP_sock:settimeout(0)
  net_send("H003")
end

function do_messages()
  flush_socket()
  while true do
    local typ, data = get_message()
    if typ then
      process_message[typ](data)
      if P1 and replay[P1.mode][typ] then
        replay[P1.mode][typ]=replay[P1.mode][typ]..data
      end
    else
      break
    end
  end
end

function ask_for_panels(prev_panels)
  if TCP_sock then
    net_send("P"..tostring(P1.NCOLORS)..prev_panels)
  else
    make_local_panels(P1, prev_panels)
  end
end

function ask_for_gpanels(prev_panels)
  if TCP_sock then
    net_send("Q"..tostring(P1.NCOLORS)..prev_panels)
  else
    make_local_gpanels(P1, prev_panels)
  end
end

function make_local_panels(stack, prev_panels)
  local ncolors = stack.NCOLORS
  local ret = prev_panels
  for x=0,19 do
    for y=0,5 do
      local prevtwo = y>1 and string.sub(ret,-1,-1) == string.sub(ret,-2,-2)
      local nogood = true
      while nogood do
        color = tostring(math.random(1,ncolors))
        nogood = (prevtwo and color == string.sub(ret,-1,-1)) or
          color == string.sub(ret,-6,-6)
      end
      ret = ret..color
    end
  end
  stack.panel_buffer = stack.panel_buffer..string.sub(ret,7,-1)
  local replay = replay[P1.mode]
  if replay and replay.pan_buf then
    replay.pan_buf = replay.pan_buf .. string.sub(ret,7,-1)
  end
end

function make_local_gpanels(stack, prev_panels)
  local ncolors = stack.NCOLORS
  local ret = prev_panels
  for x=0,19 do
    for y=0,5 do
      local nogood = true
      while nogood do
        color = tostring(math.random(1,ncolors))
        nogood = (y>0 and color == string.sub(ret,-1,-1)) or
          color == string.sub(ret,-6,-6)
      end
      ret = ret..color
    end
  end
  stack.gpanel_buffer = stack.gpanel_buffer..string.sub(ret,7,-1)
  local replay = replay[P1.mode]
  if replay and replay.gpan_buf then
    replay.gpan_buf = replay.gpan_buf .. string.sub(ret,7,-1)
  end
end

function send_controls()
  local t = function(k) if k then return "1" end return "0" end
  local framecount = P1.CLOCK..""
  while string.len(framecount) ~= 6 do
    framecount = "0"..framecount
  end
  local to_send = base64encode[
    ((keys[k_raise1] or keys[k_raise2] or this_frame_keys[k_raise1]
      or this_frame_keys[k_raise2]) and 32 or 0) +
    ((this_frame_keys[k_swap1] or this_frame_keys[k_swap2]) and 16 or 0) +
    ((keys[k_up] or this_frame_keys[k_up]) and 8 or 0) +
    ((keys[k_down] or this_frame_keys[k_down]) and 4 or 0) +
    ((keys[k_left] or this_frame_keys[k_left]) and 2 or 0) +
    ((keys[k_right] or this_frame_keys[k_right]) and 1 or 0)+1]
  if TCP_sock then
    net_send("I"..to_send)
  end
  local replay = replay[P1.mode]
  if replay and replay.in_buf then
    replay.in_buf = replay.in_buf .. to_send
  end
  return to_send
end
