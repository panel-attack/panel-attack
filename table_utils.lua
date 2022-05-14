-- @module table_utils
local table_utils = {}

-- returns the number of elements in the table
--
-- unlike #tab, this also works for dictionaries and arrays starting at index 0 and that have "gaps" inbetween indices
function table_utils.length(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

-- returns all elements in a new table that fulfill the filter condition
function table_utils.filter(t, filter)
  local filteredTable = {}

  if table.isList(t) then
    for i = 1, #t do
      if filter(t[i]) then
        table.insert(filteredTable, t[i])
      end
    end
  else
    for key, value in pairs(t) do
      if filter(value) then
        filteredTable[key] = value
      end
    end
  end

  return filteredTable
end

-- returns true if the table contains at least one value that fulfills the condition, otherwise false
function table_utils.trueForAny(tab, condition)
  for _, value in pairs(tab) do
    if condition(value) then
      return true
    end
  end
  return false
end

return table_utils