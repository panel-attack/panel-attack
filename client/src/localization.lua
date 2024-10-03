-- TODO rename
local FILENAME = "client/assets/localization.csv"
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local class = require("common.lib.class")

-- Holds all the data for localizing the game
Localization = {
    data = {},
    langs = {},
    codes = {},
    lang_index = 1,
    init = false,
}

function Localization.get_list_codes(self)
  return self.codes
end

function Localization.get_language(self)
  return self.codes[self.lang_index]
end

function Localization.refresh_global_strings(self)
  join_community_msg = loc("join_community" ,"\ndiscord." .. consts.SERVER_LOCATION)
end

function Localization.init(self)
  local function csv_line(line, acc)
    local function trim(a, b)
      if line:sub(a, a) == '"' then
        a = a + 1
      end
      if line:sub(b, b) == '"' then
        b = b - 1
      end
      return line:sub(a, b)
    end

    local tokens = {}
    local leftover = nil
    local cur = 1
    local stop_cur = 1
    local escape = (acc ~= nil)
    local ch

    while cur <= line:len() do
      ch = line:sub(cur, cur)

      if ch == '"' then
        if line:sub(cur + 1, cur + 1) == '"' then
          cur = cur + 1
        else
          escape = not escape
        end
      elseif not escape and ch == "," then
        tokens[#tokens + 1] = trim(stop_cur, cur - 1)

        if acc then
          tokens[#tokens] = acc .. tokens[#tokens]
          acc = nil
        end

        tokens[#tokens] = tokens[#tokens]:gsub('""', '"')

        stop_cur = cur + 1
      end

      cur = cur + 1
    end

    if escape then
      if not acc then
        leftover = line:sub(stop_cur + 1, cur)
      else
        leftover = acc .. line:sub(stop_cur, cur)
      end
      leftover = leftover .. "\n"
    else
      tokens[#tokens + 1] = trim(stop_cur, cur)
    end

    return tokens, leftover
  end

  self.init = true
  local num_line = 1
  local tokens, leftover
  local i = 1
  local key = nil
  -- Process all the localization strings
  if love.filesystem.getInfo(FILENAME) then
    for line in love.filesystem.lines(FILENAME) do
      if num_line == 1 then
        tokens = csv_line(line)
        for j, v in ipairs(tokens) do
          if j > 2 and v:gsub("%s", ""):len() > 0 then
            self.codes[#self.codes + 1] = v
            self.data[v] = {}
          end
        end
      else
        tokens, leftover = csv_line(line, leftover)
        for j, v in ipairs(tokens) do
          -- Key all the other languages by the first column
          if not key then
            key = v
            if key == "" or key:match("%s+") then
              break
            end
          else
            if j ~= 2 then
              if v ~= "" and not v:match("^%s+$") then
                if num_line == 2 then
                  self.langs[#self.langs + 1] = v
                end
                self.data[self.codes[i]][key] = v
              end
              i = i + 1
            end
          end
          if i > #self.codes then
            break
          end
        end

        if not leftover then
          i = 1
          key = nil
        end
      end

      num_line = num_line + 1
    end
  end

  --[[    for k, v in pairs(self.data) do
      print("LANG "..k)
      for a, b in pairs(v) do
        print(a..": "..b)
      end
    end--]]
end

-- Gets the localized string for a loc key
function loc(text_key, ...)
  local code = Localization.codes[Localization.lang_index]

  if not code or not Localization.data[code] then
    code = Localization.codes[1]
  end

  local ret = nil
  if Localization.init then
    ret = Localization.data[code][text_key]
  end

  if ret then
    for i = 1, select("#", ...) do
      local tmp = select(i, ...)
      ret = ret:gsub("%%" .. i, tmp)
    end
  else
    ret = "#" .. text_key
    for i = 1, select("#", ...) do
      ret = ret .. " " .. select(i, ...)
    end
  end

  return ret
end

return Localization