local logger = require("common.lib.logger")
local StackReplayTestingUtils = require("common.engine.tests.StackReplayTestingUtils")

local function testReplayPerformanceWithPath(path)
  local runCount = 3
  local totalTime = 0
  for i = 1, runCount, 1 do
    collectgarbage("collect")
    local _, time = StackReplayTestingUtils:simulateReplayWithPath(path)

    totalTime = totalTime + time
    logger.warn("Run " .. i .. " took " .. time)
  end

  logger.warn("Total Time: " .. math.round(totalTime / runCount, 5))
  StackReplayTestingUtils:cleanup(match)
end

testReplayPerformanceWithPath("tests/replays/v046-2022-06-04-19-06-21-Hekato-L8-vs-CoreyBLD-L8-Casual-draw.txt")
--testReplayPerformanceWithPath("tests/replays/10min-v046-2022-07-25-00-23-46-Geminorum-L10-vs-Zyza-L10-Casual-P1wins.txt")