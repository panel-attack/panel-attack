--inputs directly as variables cause there are no input devices
local wait = 0
local right = 1
local left = 2
local down = 4
local up = 8
local swap = 16
local raise = 32
--these won't be sent as input but serve as indicators when the CPU needs to wait with an input for the correct time instead of performing the swap at the rate limit (and thus failing the trick)
--whether they will see much use or not remains to be seen
local insert = 64
local slide = 128
local catch = 256
local doubleInsert = 512
--technically more than just a swap, combine this with the direction to find out in which direction the stealth is going
--the CPU should make sure to save up enough idleframes for all moves and then perform the inputs in one go
local stealth = 1024

Input = class(function(self, bit, executionTime)
    self.bit = bit
    self.executionTime = executionTime
end)

function Input.getEncoded(self)
    return base64encode(self.bit)
end

--rewrite function properly with bitwise operations when it becomes relevant
function Input.isMovement(self, input)
    --innocently assuming we never input a direction together with something else unless it's a special that includes a timed swap anyway (doubleInsert,stealth)
    if input then
        return input > 0 and input < 16
    else --only relevant for the very first input
        return true
    end
end

function Input.sort(inputTable)
    table.sort(inputTable, function(a,b)
        return a.executionTime < b.executionTime
    end)
end