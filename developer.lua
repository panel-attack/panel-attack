-- Put any local development changes you need in here that you don't want commited.

local launch_type = arg[2]
if launch_type == "test" or launch_type == "debug" then
    require "lldebugger"
    TESTS_ENABLED = 1
    if launch_type == "debug" then
        lldebugger.start()
    end
end