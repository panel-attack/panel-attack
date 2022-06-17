-- returns a new table where the value of each pair is replaced by the return value of running it through the supplied function
function table.map(tab, func)
  local mappedTable = {}
  for key, val in pairs(tab) do
    mappedTable[key] = func(val)
  end
  return mappedTable
end

-- returns the number of elements in the table
--
-- unlike #tab, this also works for dictionaries and arrays starting at index 0 and that have "gaps" inbetween indices
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

  if table.isList(tab) then
    for i = 1, #tab do
      if filter(tab[i]) then
        table.insert(filteredTable, tab[i])
      end
    end
  else
    for key, value in pairs(tab) do
      if filter(value) then
        filteredTable[key] = value
      end
    end
  end

  return filteredTable
end

-- returns true if the table contains at least one value that fulfills the condition, otherwise false
function table.trueForAny(tab, condition)
  for _, value in pairs(tab) do
    if condition(value) then
      return true
    end
  end
  return false
end

-- returns true if all value elements of the table fulfill the condition, otherwise false
function table.trueForAll(tab, condition)
  for _, value in pairs(tab) do
    if not condition(value) then
      return false
    end
  end
  return true
end

-- appends all entries of tab to the end of list
function table.appendToList(list, tab)
  assert(table.isList(tab), "insertListAt can only be used with continuously integer indexed tables")
  for i = 1, #tab do
    table.insert(list, #list + 1, tab[i])
  end
end

-- inserts all entries of tab starting at the specified position of list
function table.insertListAt(list, position, tab)
  assert(table.isList(tab), "insertListAt can only be used with continuously integer indexed tables")
  for i = #tab, 1, -1 do
    table.insert(list, position, tab[i])
  end
end

-- returns true if the table contains the given element, otherwise false
function table.contains(tab, element)
  return table.trueForAny(
    tab,
    function(tabElement)
      return deep_content_equal(tabElement, element)
    end
  )
end

-- appends an element to a table only if it does not contain the element yet
--
-- use this when you want to pretend that your table is a hashset
function table.appendIfNotExists(tab, element)
  if not table.contains(tab, element) then
    table.insert(tab, #tab + 1, element)
  end
end

-- Randomly grabs a value from the table
function table.getRandomElement(tab)
  if table.isList(tab) then
    return tab[math.random(#tab)]
  else
    -- pairs already returns in an arbitrary order but I'm not sure if it's truly random
    local rolledIndex = math.random(table.length(tab))
    local index = 0
    for _, value in pairs(tab) do
      index = index + 1
      if index == rolledIndex then
        return value
      end
    end
  end
end

-- returns true if the table uses sequential integer indices without gaps
function table.isList(tab)
  -- the tab[1] check is just to get dictionaries out of the way really quickly
  return tab[1] ~= nil and #tab == table.length(tab)
end

-- returns all keys of a table, sorted using the standard comparator to account for sequence based tables
function table.getKeys(tab)
  local keys = {}
  for key, _ in pairs(tab) do
    table.insert(keys, key)
  end
  table.sort(keys)

  return keys
end

-- returns the key for the given value, key is random if value occurs multiple times
function table.indexOf(tab, element)
  for key, value in pairs(tab) do
    if value == element then
      return key
    end
  end

  return nil
end