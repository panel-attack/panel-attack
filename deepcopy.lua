--local copyCount

-- Save copied tables in `copies`, indexed by original table.
function p_deepcopy(orig, keysToShallowCopy, keysToIgnore, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                if keysToIgnore == nil or keysToIgnore[orig_key] == nil then
                    if type(orig_key) == "table" then
                        if keysToShallowCopy == nil or keysToShallowCopy[orig_key] == nil then
                            orig_key = p_deepcopy(orig_key, copies)
                        end
                    end
                    if type(orig_value) == "table" then
                        --local previousCount = copyCount

                        if keysToShallowCopy == nil or keysToShallowCopy[orig_key] == nil then
                            orig_value = p_deepcopy(orig_value, copies)
                        end

                        --if copyCount > previousCount + 100 then
                        --    print("deep: " .. copyCount - previousCount .. " - " .. orig_key)
                        --end
                    end
                    copy[orig_key] = orig_value
                    --copyCount = copyCount + 1
                end
            end
            setmetatable(copy, getmetatable(orig))
        end
    else -- number, string, boolean, etc
        copy = orig
        --copyCount = copyCount + 1
    end

    return copy
end

-- Save copied tables in `copies`, indexed by original table.
function deepcopy(orig, keysToShallowCopy, keysToIgnore, copies)
    --copyCount = 0
    local result = p_deepcopy(orig, keysToShallowCopy, keysToIgnore, copies)

    --print("deep copy finished: " .. copyCount)
    return result
end