
local TouchDataEncoding = require("engine.TouchDataEncoding")

local function testWithBoardSize(width, height)
  for z = 0, 1 do
    local raise = false
    if z == 1 then
      raise = true
    end
    for column = 1, width do
      for row = 1, height do
        local latinString = TouchDataEncoding.touchDataToLatinString(raise, row, column, width)
        local raise2, row2, column2 = TouchDataEncoding.latinStringToTouchData(latinString, width)
        assert(raise == raise2)
        assert(column == column2)
        assert(row == row2)
      end
    end
  end
end

testWithBoardSize(6, 12)
testWithBoardSize(12, 12)
testWithBoardSize(6, 20)