


function math.sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end

CpuLogger = class(
    function(self, logLevel)
        self.logLevel = logLevel
    end
)

-- a glorified print that can be turned on/off via the cpu configuration
function CpuLogger.log(self, level, ...)
    if self.logLevel >= level then
        print(...)
    end
end

-- assumes that the table has only elements of the same type that implements the equals(self, other) method
function table.appendIfNotExists(table1, value)
    local alreadyExists = false
    CpuLog:log(1, #table1 .. " values already in table")
    for i=1, #table1 do
        CpuLog:log(1, "comparing \n" .. table1[i]:toString() .. " and \n" .. value:toString())
        if table1[i]:equals(value) then
            alreadyExists = true
            break
        end
    end
    if alreadyExists == false then
        table.insert(table1, value)
    end
end