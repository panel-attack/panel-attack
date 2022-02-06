-- returns a new table where every element is replaced by the return value of running it through the supplied function
function table.map(tab, func)
    local mappedTable = {}
    for i = 1, #tab do
        mappedTable[i] = func(tab[i])
    end
    return mappedTable
end

-- returns a new key-value table where the value of each pair is replaced by the return value of running it through the supplied function
function table.mapDict(dict, func)
    local mappedDict = {}
    for key, val in pairs(dict) do
        mappedDict[key] = func(val)
    end
    return mappedDict
end

-- returns the number of elements in the table
--
-- unlike #tab, this also works for arrays starting at index 0 and that have "gaps" inbetween indices
function table.length(tab)
    local count = 0
    for _ in pairs(tab) do
      count = count + 1
    end
    return count
end

-- returns all elements in a new table that fulfill the filter condition
function table.filter(tab, filter)
    local filteredTable = {}
    for i = 1, #tab do
        if filter(tab[i]) then
            table.insert(filteredTable, #filteredTable + 1, tab[i])
        end
    end
    return filteredTable
end

-- returns true if the table contains at least one element that fulfills the condition, otherwise false
function table.any(tab, condition)
    for i = 1, #tab do
        if condition(tab[i]) then
            return true
        end
    end
    return false
end

-- returns true if all elements of the table fulfill the condition, otherwise false
function table.all(tab, condition)
    for i = 1, #tab do
        if not condition(tab[i]) then
            return false
        end
    end
    return true
end

-- appends all entries of tab to the end of list
function table.insertRange(list, tab)
    for i = 1, #tab do
        table.insert(list, #list + 1, tab[i])
    end
end

-- inserts all entries of tab starting at the specified position of list
function table.insertRange(list, position, tab)
    for i = #tab, 1, -1 do
        table.insert(list, position, tab[i])
    end
end

-- returns true if the table contains the given element, otherwise false
function table.contains(tab, element)
    return table.any(tab, function(tabElement) deep_content_equal(tabElement, element) end)
end

-- appends an element to a table only if it does not contain the element yet
--
-- use this when you want to pretend that your table is a hashset
function table.appendIfNotExists(tab, element)
    if not table.contains(tab, element) then
        table.insert(tab, #tab + 1, element)
    end
end

-- returns an iterator that returns the next element in the table on each call
--
-- used for looping through a table with the for element in table.getIterator(tab) style when you do not care about the index that comes with pairs/ipairs or a regular for loop
function table.getIterator(tab)
    local i = 0
    local n = #tab
    return function ()
            i = i + 1
            if i <= n then return tab[i] end
            end
end

-- Randomly grabs a value from the table
function table.getRandomElement(tab)
    return tab[math.random(#tab)]
end