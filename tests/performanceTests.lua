
local logger = require("logger")
local utf8 = require("utf8Additions")
local StackReplayTestingUtils = require("tests.StackReplayTestingUtils")

local function testReplayPerformanceWithPath(path)
  local runCount = 3
  local totalTime = 0
  for i = 1, runCount, 1 do
    collectgarbage("collect")
    local _, time = StackReplayTestingUtils:simulateReplayWithPath(path)

    totalTime = totalTime + time
    logger.warn("Run " .. i .. " took " .. time)
  end

  logger.warn("Total Time: " .. round(totalTime / runCount, 5))
end

testReplayPerformanceWithPath("tests/replays/v046-2022-06-04-19-06-21-Hekato-L8-vs-CoreyBLD-L8-Casual-draw.txt")
--testReplayPerformanceWithPath("tests/replays/10min-v046-2022-07-25-00-23-46-Geminorum-L10-vs-Zyza-L10-Casual-P1wins.txt")

-- performance comparison between string usage and table concat for singleplayer
-- simulated for one minute without restorefromrollbackcopy and debugmode off

local function testPerformanceString(seconds)
  local confirmedInputsP1 = ""
  local loopCount = seconds * 60

  local totalTime = 0

  for i = 1, loopCount do
    local time = love.timer.getTime()
    -- check in send_controls
    local len1 = utf8.len(confirmedInputsP1)
    local len2 = utf8.len(confirmedInputsP1)
    -- receiveConfirmedInput, called in send_controls
    confirmedInputsP1 = confirmedInputsP1 .. "A"
    local loopTime = love.timer.getTime() - time
    totalTime = totalTime + loopTime
    if i == loopCount then
      print("needed " .. loopTime .. "s to concat for the " .. loopCount .. "th loop")
    end
  end

  print("string performance, took: " .. totalTime .. " to concat inputs for a " .. seconds .. "s match")

end

local function testPerformanceTable(seconds)
  local confirmedInputsP1 = {}
  local loopCount = seconds * 60

  local totalTime = 0

  for i = 1, loopCount do
    local time = love.timer.getTime()
    -- check in send_controls
    local len1 = #confirmedInputsP1
    local len2 = #confirmedInputsP1
    -- receiveConfirmedInput, called in send_controls
    local inputs = string.toCharTable("A")
    table.appendToList(confirmedInputsP1, inputs)
    local loopTime = love.timer.getTime() - time
    totalTime = totalTime + loopTime
    if i == loopCount then
      print("needed " .. loopTime .. "s to concat for the " .. loopCount .. "th loop")
    end
  end

  print("table performance, took: " .. totalTime .. " to concat inputs for a " .. seconds .. "s match")
end

local function testPerformanceTableStringLen(seconds)
  local confirmedInputsP1 = {}
  local loopCount = seconds * 60

  local totalTime = 0

  for i = 1, loopCount do
    local time = love.timer.getTime()
    -- check in send_controls
    local len1 = #confirmedInputsP1
    local len2 = #confirmedInputsP1
    -- receiveConfirmedInput, called in send_controls
    local input = "A"
    if utf8.len(input) == 1 then
      confirmedInputsP1[#confirmedInputsP1+1] = input
    else
      local inputs = string.toCharTable(input)
      table.appendToList(confirmedInputsP1, inputs)
    end
    local loopTime = love.timer.getTime() - time
    totalTime = totalTime + loopTime
    if i == loopCount then
      print("needed " .. loopTime .. "s to concat for the " .. loopCount .. "th loop")
    end
  end

  print("table stringlen performance, took: " .. totalTime .. " to concat inputs for a " .. seconds .. "s match")
end

testPerformanceString(30)
testPerformanceTable(30)
testPerformanceTableStringLen(30)

testPerformanceString(60)
testPerformanceTable(60)
testPerformanceTableStringLen(60)

testPerformanceString(120)
testPerformanceTable(120)
testPerformanceTableStringLen(120)

testPerformanceString(300)
testPerformanceTable(300)
testPerformanceTableStringLen(300)

testPerformanceString(600)
testPerformanceTable(600)
testPerformanceTableStringLen(600)

testPerformanceString(900)
testPerformanceTable(900)
testPerformanceTableStringLen(900)