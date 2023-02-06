local utf8 = require("utf8")

local TouchDataEncoding = {}

local START_LATIN_NUMBER = 256

local function panelNumberToRowAndCol(num, width)
  if num == 0 then
    return 0,0
  end
  local row = math.floor((num - 1) / width) + 1
  local column =  num - ((row - 1) * width)
    
  return column, row
end

function TouchDataEncoding.latinStringToTouchData(latinString, width)
  local raise = false
  local row = 0
  local column = 0
  local codePoint = 0
  for p, c in utf8.codes(latinString) do
    codePoint = c - START_LATIN_NUMBER
    break
  end

  if codePoint > 0 then
    if codePoint % 2 == 1 then
      raise = true
    end
    local panelNumber = math.floor(codePoint / 2)

    column, row = panelNumberToRowAndCol(panelNumber, width)
  end
  return raise, column, row
end

function TouchDataEncoding.touchDataToLatinString(raise, column, row, width)
  local codePoint = ((raise and 1) or 0)
  if row ~= 0 or column ~= 0 then
    local panelNumber = ((row - 1) * width) + column
    codePoint = codePoint + panelNumber * 2
  end
  codePoint = codePoint + START_LATIN_NUMBER
  local result = utf8.char(codePoint)
  return result
end

return TouchDataEncoding