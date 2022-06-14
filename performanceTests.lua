
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
        match:run()
        matchOutcome = match.battleRoom:matchOutcome()
    end
    local endTime = love.timer.getTime()

    reset_filters()
    stop_the_music()
    replay = {}
    GAME:clearMatch()
    return endTime - startTime
end

local runCount = 10
local totalTime = 0
for i = 1, runCount, 1 do
  collectgarbage("collect")
  local time = recordReplayRunSpeed("tests/replays/v046-2022-06-04-19-06-21-Hekato-L8-vs-CoreyBLD-L8-Casual-draw.txt")

  totalTime = totalTime + time
  print("Run " .. i .. " took " .. time)
  local garbage = collectgarbage("count")
  print("Memory " .. garbage)
end

print("Total Time: " .. round(totalTime / runCount, 5))