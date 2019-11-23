local FILENAME = "localization.csv"

Localization = class(function(self)
  self.data = {}
  self.langs = {}
  self.codes = {}
  self.lang_index = 1
  self.init = false
end)

localization = Localization()

function Localization.get_list_codes(self)
  return self.codes
end

function Localization.get_language(self)
  return self.codes[self.lang_index]
end

function Localization.refresh_global_strings(self)
  join_community_msg = loc("join_community").."\ndiscord.panelattack.com"
end

function Localization.set_language(self, lang_code)
  for i, v in ipairs(self.codes) do
    if v == lang_code then
      self.lang_index = i
      break
    end
  end
  config.language_code = self.codes[self.lang_index]

  if config.language_code == "JP" then
    set_global_font("jp.ttf", 14)
  else
    set_global_font(nil, 12)
  end

  self:refresh_global_strings()
end

function Localization.init(self)

  local function csv_line(line, acc)
    local function trim(a, b)
      if line:sub(a, a) == '"' then
        a = a+1
      end
      if line:sub(b, b) == '"' then
        b = b-1
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
        if line:sub(cur+1, cur+1) == '"' then
          cur = cur + 1
        else
          escape = not escape
        end
      elseif not escape and ch == ',' then
        tokens[#tokens+1] = trim(stop_cur, cur-1)

        if acc then
          tokens[#tokens] = acc..tokens[#tokens]
          acc = nil
        end

        tokens[#tokens] = tokens[#tokens]:gsub('""', '"')

        stop_cur = cur + 1
      end

      cur = cur + 1
    end

    if escape then
      if not acc then
        leftover = line:sub(stop_cur+1, cur)
      else
        leftover = acc..line:sub(stop_cur, cur)
      end
        leftover = leftover.."\n"
    else
      tokens[#tokens+1] = trim(stop_cur, cur)
    end

    return tokens, leftover
  end

  self.init = true
  local num_line = 1
  local tokens, leftover
  local i = 1
  local key = nil
  if love.filesystem.getInfo(FILENAME) then
    for line in love.filesystem.lines(FILENAME) do

      if num_line == 1 then
        tokens = csv_line(line)
        for i, v in ipairs(tokens) do
          if i > 1 and v:gsub("%s", ""):len() > 0 then
            self.codes[#self.codes+1] = v
            self.data[v] = {}
          end
        end
      else
        tokens, leftover = csv_line(line, leftover)
        for _, v in ipairs(tokens) do

          if not key then
            key = v
            if key == "" or key:match("%s+") then
              break
            end
          else
            if v ~= "" and not v:match("^%s+$") then
              if num_line == 2 then
                self.langs[#self.langs+1] = v
              end
              self.data[self.codes[i]][key] = v
            end
            i = i+1
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

  self:set_language(config.language_code)
end

function loc(text_key, ...)
  local self = localization
  local code = self.codes[self.lang_index]

  if not code or not self.data[code] then
    code = self.codes[1]
  end

  local ret = nil
  if self.init then
    ret = self.data[code][text_key]
  end

  if ret then
    for i = 1, select('#', ...) do
      local tmp = select(i, ...)
      ret = ret:gsub("%%"..i, tmp)
    end
  else
    ret = "#"..text_key
    for i = 1, select('#', ...) do
      ret = ret.." "..select(i, ...)
    end
  end

  return ret
end
