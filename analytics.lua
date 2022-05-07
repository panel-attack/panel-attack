local analytics = {}

local analytics_version = 3

local function create_blank_data()
  return {
    -- the amount of destroyed panels
    destroyed_panels = 0,
    -- the amount of sent garbage
    sent_garbage_lines = 0,
    -- the amount of times the cursor was moved
    move_count = 0,
    -- the amount of times the panels were swapped
    swap_count = 0,
    -- 1 to X, mystery chains are recorded as whatever chain they were, 1 is obviously meaningless
    reached_chains = {},
    -- 1 to 40, 1 to 3 being meaningless
    used_combos = {}
  }
end

-- The class representing one set of analytics data
AnalyticsInstance =
  class(
  function(self, save_to_overall)
    self.save_to_overall = save_to_overall -- whether this data should count towards the overall
    self.data = create_blank_data()
    
    -- temporary
    self.lastGPM = 0
    self.lastAPM = 0
  end
)

local analytics_data = {
  -- The lastly used version
  version = analytics_version,
  last_game = create_blank_data(),
  overall = create_blank_data()
}

local function analytic_clear(analytic)
  analytic.destroyed_panels = 0
  analytic.sent_garbage_lines = 0
  analytic.move_count = 0
  analytic.swap_count = 0
  analytic.reached_chains = {}
  analytic.used_combos = {}
end

local amount_of_garbages_lines_per_combo = {0, 0, 0, 0.5, 1, 1, 1, 2, 2, 2, 2, 2, 3, 4, [20] = 6, [27] = 8}
for i = 1, 72 do
  amount_of_garbages_lines_per_combo[i] = amount_of_garbages_lines_per_combo[i] or amount_of_garbages_lines_per_combo[i - 1]
end

local function compute_above_13(analytic)
  --computing chain ? count
  local chain_above_13 = 0
  for k, v in pairs(analytic.reached_chains) do
    if k > 13 then
      chain_above_13 = chain_above_13 + v
    end
  end
  return chain_above_13
end

local function refresh_sent_garbage_lines(analytic)
  local sent_garbage_lines_count = 0
  for k, v in pairs(analytic.used_combos) do
    if k then
      sent_garbage_lines_count = sent_garbage_lines_count + amount_of_garbages_lines_per_combo[k] * v
    end
  end
  for i = 2, 13 do
    if analytic.reached_chains[i] then
      sent_garbage_lines_count = sent_garbage_lines_count + (i - 1) * analytic.reached_chains[i]
    end
  end
  local chain_above_13 = compute_above_13(analytics.last_game)
  sent_garbage_lines_count = sent_garbage_lines_count + 13 * chain_above_13
  analytic.sent_garbage_lines = sent_garbage_lines_count
end

function analytics.init()
  pcall(
    function()
      local read_data = {}
      local analytics_file, err = love.filesystem.newFile("analytics.json", "r")
      if analytics_file then
        local teh_json = analytics_file:read(analytics_file:getSize())
        for k, v in pairs(json.decode(teh_json)) do
          read_data[k] = v
        end
      end

      if read_data.version and type(read_data.version) == "number" then
        analytics_data.version = read_data.version
      end
      local analytics_filters = {"last_game", "overall"}
      local number_params = {"destroyed_panels", "sent_garbage_lines", "move_count", "swap_count"}
      local table_params = {"reached_chains", "used_combos"}
      for _, analytic in pairs(analytics_filters) do
        if read_data[analytic] and type(read_data[analytic]) == "table" then
          for n, param in pairs(number_params) do
            if read_data[analytic][param] and type(read_data[analytic][param]) == "number" then
              analytics_data[analytic][param] = read_data[analytic][param]
            end
          end
          for m, param in pairs(table_params) do
            if read_data[analytic][param] and type(read_data[analytic][param]) == "table" then
              analytics_data[analytic][param] = read_data[analytic][param]
            end
          end
        end
      end

      analytic_clear(analytics_data.last_game)

      -- do stuff regarding version compatibility here, before we patch it
      if analytics_data.version < 2 then
        refresh_sent_garbage_lines(analytics_data.overall)
      end

      analytics_data.version = analytics_version
      analytics_file:close()
    end
  )
end

local function output_pretty_analytics()
  pcall(
    function()
      if not config.enable_analytics then
        return
      end

      local analytics_filters = {analytics_data.last_game, analytics_data.overall}
      local titles = {"Last game\n-------------------------------------\n", "Overall\n-------------------------------------\n"}
      local text = ""
      for i, analytic in pairs(analytics_filters) do
        text = text .. titles[i]
        text = text .. "Destroyed " .. analytic.destroyed_panels .. " panels.\n"
        text = text .. "Sent " .. analytic.sent_garbage_lines .. " lines of garbage.\n"
        text = text .. "Moved " .. analytic.move_count .. " times.\n"
        text = text .. "Swapped " .. analytic.swap_count .. " times.\n"
        text = text .. "Performed combos:\n"
        for k, v in pairs(analytic.used_combos) do
          if k then
            text = text .. "\t" .. v .. " combo(s) of size " .. k .. "\n"
          end
        end
        text = text .. "Reached chains:\n"
        for k, v in pairs(analytic.reached_chains) do
          if k then
            text = text .. "\t" .. v .. " chain(s) have ended at length " .. k .. "\n"
          end
        end
        text = text .. "\n\n"
      end

      local file = love.filesystem.newFile("analytics.txt")
      file:open("w")
      file:write(text)
      file:close()
    end
  )
end

local function write_analytics_files()
  pcall(
    function()
      if not config.enable_analytics then
        return
      end

      local file = love.filesystem.newFile("analytics.json")
      file:open("w")
      file:write(json.encode(analytics_data))
      file:close()

      output_pretty_analytics()
    end
  )
end

function AnalyticsInstance.compute_above_13(self)
  return compute_above_13(self.data)
end

function AnalyticsInstance.data_update_list(self)
  local data_update_list = {self.data}

  if self.save_to_overall then
    table.insert(data_update_list, analytics_data.overall)
  end

  return data_update_list
end

function AnalyticsInstance.register_destroyed_panels(self, amount)
  local analytics_filters = self:data_update_list()
  for _, analytic in pairs(analytics_filters) do
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

function AnalyticsInstance.register_chain(self, size)
  local max_size = math.min(size, 13)

  local analytics_filters = self:data_update_list()
  for _, analytic in pairs(analytics_filters) do
    if not analytic.reached_chains[size] then
      analytic.reached_chains[size] = 1
    else
      analytic.reached_chains[size] = analytic.reached_chains[size] + 1
    end
    size = math.min(size, 13)
    analytic.sent_garbage_lines = analytic.sent_garbage_lines + (max_size - 1)
  end
end

function AnalyticsInstance.register_swap(self)
  local analytics_filters = self:data_update_list()
  for _, analytic in pairs(analytics_filters) do
    analytic.swap_count = analytic.swap_count + 1
  end
end

function AnalyticsInstance.register_move(self)
  local analytics_filters = self:data_update_list()
  for _, analytic in pairs(analytics_filters) do
    analytic.move_count = analytic.move_count + 1
  end
end

function analytics.game_ends(analytic)
  if analytic then
    analytics_data.last_game = analytic.data
  end
  if config.enable_analytics then
    write_analytics_files()
  end

  analytic_clear(analytics_data.last_game)
end

return analytics
