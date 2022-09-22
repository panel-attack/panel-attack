
local logger = require("logger")

local function recordReplayRunSpeed(path)
        
    GAME.muteSoundEffects = true

    Replay.loadFromPath(path)
    Replay.loadFromFile(replay)

    assert(GAME ~= nil)
    assert(GAME.match ~= nil)
    assert(GAME.match.P1 ~= nil)
    assert(GAME.match.P2 ~= nil)

    local match = GAME.match
    local player1 = GAME.match.P1
    local player2 = GAME.match.P2

    local startTime = love.timer.getTime()

    local matchOutcome = match.battleRoom:matchOutcome()
    while matchOutcome == nil do
        -- local time1 = love.timer.getTime()
        match:run()
        -- local time2 = love.timer.getTime()
        -- print("Run " .. player1.CLOCK .. " took " .. time2 - time1)
        -- local garbage = collectgarbage("count")
        -- print("Memory " .. garbage)
        matchOutcome = match.battleRoom:matchOutcome()
    end
    local endTime = love.timer.getTime()

    reset_filters()
    stop_the_music()
    replay = {}
    GAME:clearMatch()
    return endTime - startTime
end

local function testReplayPerformanceWithPath(path)
  local runCount = 3
  local totalTime = 0
  for i = 1, runCount, 1 do
    collectgarbage("collect")
    local time = recordReplayRunSpeed(path)

    totalTime = totalTime + time
    logger.warn("Run " .. i .. " took " .. time)
    --local garbage = collectgarbage("count")
    --logger.warn("Memory " .. garbage)
  end

  logger.warn("Total Time: " .. round(totalTime / runCount, 5))
end

testReplayPerformanceWithPath("tests/replays/v046-2022-06-04-19-06-21-Hekato-L8-vs-CoreyBLD-L8-Casual-draw.txt")
testReplayPerformanceWithPath("tests/replays/10min-v046-2022-07-25-00-23-46-Geminorum-L10-vs-Zyza-L10-Casual-P1wins.txt")
