-- Put any local development changes you need in here that you don't want commited.

for _, value in pairs(arg) do
  if value == "test" then
    TESTS_ENABLED = 1
  elseif value == "debug" then
    DEBUG_ENABLED = 1
    require "lldebugger"
    lldebugger.start()
  elseif value == "profile" then
    PROFILING_ENABLED = 1
  elseif value == "performanceTests" then
    PERFORMANCE_TESTS_ENABLED = 1
  else
    for match in string.gmatch(value, "user%-id=(.*)") do
      CUSTOM_USER_ID = match
    end
  end
end