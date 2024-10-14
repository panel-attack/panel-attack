-- Put any local development changes you need in here that you don't want commited.

local function enableProfiler()
  PROF_CAPTURE = true
  -- we want to optimize in a way that our weakest platforms benefit
  -- on our weakest platform (android), jit is default disabled
  --jit.off()
end

for _, value in pairs(arg) do
  if value == "test" then
    TESTS_ENABLED = 1
  elseif value == "debug" then
    DEBUG_ENABLED = 1
    require "lldebugger"
    lldebugger.start()
  elseif value == "profileFrameTimes" then
    enableProfiler()

    if not collectgarbage("isrunning") then
      collectgarbage("restart")
    end
  elseif value == "profileMemory" then
    enableProfiler()
    -- the garbage collector is a primary source of frame spikes
    -- thus one goal of profiling is to identify where memory is allocated
    -- because the less memory is allocated, the less the garbage collector runs 
    -- the final goal would be to achieve near 0 memory allocation during games
    -- this would allow us to simply turn off the GC during matches and only collect afterwards
    PROFILE_MEMORY = true
    collectgarbage("stop")
  elseif value == "performanceTests" then
    PERFORMANCE_TESTS_ENABLED = 1
  elseif value == "updaterTest" then
    -- drop the updater directory of the updater in for debugging purposes
    GAME_UPDATER_STATES = { idle = 0, checkingForUpdates = 1, downloading = 2}
    GAME_UPDATER = require("updater.gameUpdater")
  else
    for match in string.gmatch(value, "user%-id=(.*)") do
      CUSTOM_USER_ID = match
    end
  end
end