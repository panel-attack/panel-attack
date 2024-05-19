local utf8 = require("common.lib.utf8Additions")

-- Represents an encoding scheme that saves a panel column, row, and raise data into a single unicode character
-- so it can be somewhat understood in the replay file and easy to trasmit over the network.
local TouchDataEncoding = {}

-- Start at a unicode point that is mostly printable characters that are distinguishable
local START_LATIN_NUMBER = 256

-- Given a stack width and number, returns which panel it is in the stack, left to right, bottom to top
local function panelNumberToRowAndCol(num, width)
  if num == 0 then
    return 0,0
  end
  local row = math.floor((num - 1) / width) + 1
  local column =  num - ((row - 1) * width)
    
  return row, column
end

-- Given an encoded latin unicode character, decodes it back into a raise, column, and row
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

    row, column = panelNumberToRowAndCol(panelNumber, width)
  end
  return raise, row, column
end

-- Given a raise, column and row, encodes it as a single latin unicode character
function TouchDataEncoding.touchDataToLatinString(raise, row, column, width)
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