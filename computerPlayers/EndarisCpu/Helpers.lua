


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