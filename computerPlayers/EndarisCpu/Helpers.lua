


function math.sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end

-- a glorified print that can be turned on/off via the cpu configuration
function cpuLog(...)
    if not active_cpuConfig or active_cpuConfig["Log"] then
        print(...)
    end
end