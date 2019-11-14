local analytics_version = 2

analytics = {
             -- The lastly used version
             version                       = analytics_version,
             
             last_game = 
               {
                  -- the amount of destroyed panels
                  destroyed_panels = 0,
                  -- the amount of sent garbage
                  sent_garbage_lines = 0,
                  -- 1 to 12, then 13+, 1 is obviously meaningless
                  reached_chains = { },
                  -- 1 to 40, 1 to 3 being meaningless
                  used_combos = { }
               },

             overall = 
               {
                  -- the amount of destroyed panels
                  destroyed_panels = 0,
                  -- the amount of sent garbage
                  sent_garbage_lines = 0,
                  -- 1 to 12, then 13+, 1 is obviously meaningless
                  reached_chains = { },
                  -- 1 to 40, 1 to 3 being meaningless
                  used_combos = { }
               }
           }

local function analytic_clear(analytic)
  analytic.destroyed_panels = 0
  analytic.sent_garbage_lines = 0
  analytic.reached_chains = {}
  analytic.used_combos = {}
end

local amount_of_garbages_lines_per_combo = {0, 0, 0, 0.5, 1, 1, 1, 2, 2, 2, 2, 2, 3, 4, [20]=6, [27]=8 }
for i=1,72 do
  amount_of_garbages_lines_per_combo[i] = amount_of_garbages_lines_per_combo[i] or amount_of_garbages_lines_per_combo[i-1]
end

local function compute_above_13(analytic)
  --computing chain ? count
  local chain_above_13 = 0
  for k,v in pairs(analytic.reached_chains) do
    if k > 13 then
      chain_above_13 = chain_above_13 + v
    end
  end
  return chain_above_13
end

local function refresh_sent_garbage_lines(analytic)
  local sent_garbage_lines_count = 0
  for k,v in pairs(analytic.used_combos) do
    if k then
      sent_garbage_lines_count = sent_garbage_lines_count + amount_of_garbages_lines_per_combo[k]*v
    end
  end
  for i=2,13 do
    if analytic.reached_chains[i] then
      sent_garbage_lines_count = sent_garbage_lines_count + (i-1)*analytic.reached_chains[i]
    end
  end
  local chain_above_13 = compute_above_13(analytics.last_game)
  sent_garbage_lines_count = sent_garbage_lines_count + 13*chain_above_13
  analytic.sent_garbage_lines = sent_garbage_lines_count
end

function analytics_init() pcall(function()
  if not config.enable_analytics then
    return
  end

  local file = love.filesystem.newFile("analytics.json")
  file:open("r")

  local teh_json = file:read(file:getSize())
  for k,v in pairs(json.decode(teh_json)) do
    analytics[k] = v
  end
  
  analytic_clear(analytics.last_game)

  -- do stuff regarding version compatibility here, before we patch it
  if analytics.version < 2 then
    refresh_sent_garbage_lines(analytics.overall)
  end

  analytics.version = analytics_version
  file:close()
end) end

local function output_pretty_analytics() pcall(function()
  if not config.enable_analytics then
    return
  end

  local analytics_filters = { analytics.last_game, analytics.overall } 
  local titles = { "Last game\n-------------------------------------\n", "Overall\n-------------------------------------\n" }
  local text = ""
  for i,analytic in pairs(analytics_filters) do
    text = text..titles[i]
    text = text.."Destroyed "..analytic.destroyed_panels.." panels.\n"
    text = text.."Sent "..analytic.sent_garbage_lines.." lines of garbage.\n"
    text = text.."Performed combos:\n"
    for k,v in pairs(analytic.used_combos) do
      if k then
        text = text.."\t"..v.." combo(s) of size "..k.."\n"
      end
    end
    text = text.."Reached chains:\n"
    for k,v in pairs(analytic.reached_chains) do
      if k then
        text = text.."\t"..v.." chain(s) have ended at length "..k.."\n"
      end
    end
    text = text.."\n\n"
  end

  local file = love.filesystem.newFile("analytics.txt")
  file:open("w")
  file:write(text)
  file:close()
end) end


function analytics_draw(x,y)  
  if not config.enable_analytics then
    return
  end

  gprint("Panels destroyed: "..analytics.last_game.destroyed_panels, x, y)
  y = y+15

  gprint("Sent garbage lines: "..analytics.last_game.sent_garbage_lines, x, y)
  y = y+15

  local ycombo = y
  for i=2,13 do
    local chain_amount = analytics.last_game.reached_chains[i] or 0
    gprint("x"..i..": "..chain_amount, x, y)
    y = y+15
  end

  local chain_above_13 = compute_above_13(analytics.last_game)
  gprint("x?: "..chain_above_13, x, y)

  local xcombo = x + 50
  for i=4,15 do
    local combo_amount = analytics.last_game.used_combos[i] or 0
    gprint("c"..i..": "..combo_amount, xcombo, ycombo)
    ycombo = ycombo+15
  end
end

function write_analytics_files() pcall(function()
  if not config.enable_analytics then
    return
  end

  local file = love.filesystem.newFile("analytics.json")
  file:open("w")
  file:write(json.encode(analytics))
  file:close()

  output_pretty_analytics()
end) end

function analytics_register_destroyed_panels(amount)
  if not config.enable_analytics then
    return
  end
  
  local analytics_filters = { analytics.last_game, analytics.overall }
  for _,analytic in pairs(analytics_filters) do
    analytic.destroyed_panels = analytic.destroyed_panels + amount
    if amount > 3 then
      if not analytic.used_combos[amount] then
        analytic.used_combos[amount] = 1
      else
        analytic.used_combos[amount] = analytic.used_combos[amount] + 1
      end
      analytic.sent_garbage_lines = analytic.sent_garbage_lines + amount_of_garbages_lines_per_combo[amount]
    end
  end
end

function analytics_register_chain(size)
  if not config.enable_analytics then
    return
  end

  local max_size = math.min(size, 13)

  local analytics_filters = { analytics.last_game, analytics.overall }
  for _,analytic in pairs(analytics_filters) do
    if not analytic.reached_chains[size] then
      analytic.reached_chains[size] = 1
    else
      analytic.reached_chains[size] = analytic.reached_chains[size]+1
    end
    size = math.min(size, 13)
    analytic.sent_garbage_lines = analytic.sent_garbage_lines + (max_size-1)
  end
end

function analytics_game_ends()
  if not config.enable_analytics then
    return
  end

  write_analytics_files()
  analytic_clear(analytics.last_game)
end