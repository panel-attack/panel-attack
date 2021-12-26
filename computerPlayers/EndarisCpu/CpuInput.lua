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

Input = class(function(self, bit, executionFrame)
    self.bit = bit
    -- executionFrame is assumed to be the framenumber on the stack
    self.executionFrame = executionFrame
end)

function Input.getEncoded(self)
    return base64encode[self.bit + 1]
end

--rewrite function properly with bitwise operations when it becomes relevant
function Input.isMovement(input)
    --innocently assuming we never input a direction together with something else unless it's a special that includes a timed swap anyway (doubleInsert,stealth)
    if input then
        return input.bit > 0 and input.bit < 16
    else --only relevant for the very first input
        return true
    end
end

function Input.sort(inputTable)
    table.sort(inputTable, function(a,b)
        return a.executionFrame < b.executionFrame
    end)
end

function Input.EncodedWait()
    return base64encode[1]
end

function Input.WaitTimeSpan(from, to)
    local input = Input(wait, from)
    input.to = to
    return input
end

function Input.Left(executionFrame)
    return Input(left, executionFrame)
end

function Input.Right(executionFrame)
    return Input(right, executionFrame)
end

function Input.Down(executionFrame)
    return Input(down, executionFrame)
end

function Input.Up(executionFrame)
    return Input(up, executionFrame)
end

function Input.Raise(executionFrame)
    return Input(raise, executionFrame)
end

function Input.Swap(executionFrame)
    return Input(swap, executionFrame)
end

function Input.toString(self)
    return  "Input " .. self.bit .. " at executionFrame " .. self.executionFrame
end