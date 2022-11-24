local logger = require("logger")
local batteries = require("batteries")

local baseGarbage = 0
local currentGarbage = 0


function printCurrentMemory()
    batteries(10, 200, nil)
    batteries(10, 200, nil)
    logger.warn("Memory: " .. collectgarbage("count") .. " kb")
end

function memoryStart()
    batteries(10, 200, nil)
    batteries(10, 200, nil)
    baseGarbage = collectgarbage("count")
end

function memoryEnd()

    currentGarbage = collectgarbage("count")
    logger.warn("Memory Change: " .. currentGarbage - baseGarbage .. " kb")

    batteries(10, 200, nil)
    batteries(10, 200, nil)

    pcall(
    function()
        io.stdout:flush()
    end
    )
end