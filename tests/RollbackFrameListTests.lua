local NewSparseRollbackFrameList = require("engine.RollbackFrameList")

local function basicTest()
  local list = NewSparseRollbackFrameList()

  list[1] = 1
  list[5] = 5
  list[10] = 10

  assert(list.length == 3)
  assert(list:getValueAtFrame(7) == 5)
  assert(list:lastValue() == 10)
  list:clearFromFrame(3)
  assert(list:lastValue() == 1)
  assert(list.length == 1)
end

basicTest()

