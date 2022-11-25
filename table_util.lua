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

  for key, value in pairs(tab) do
    if filter(value) then
      filteredTable[key] = value
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

-- returns true if the table contains the given element, otherwise false
function table.contains(tab, element)
  return tab:trueForAny(
    function(tabElement)
      return deep_content_equal(tabElement, element)
    end
  )
end

-- Randomly grabs a value from the table
function table.getRandomElement(tab)
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


-- a list is formerly defined as a table with monotonously increasing integer based keys starting at 1 so that #tab computes properly
-- the list may also start at index 0 which has to be indicated upon construction by setting zeroIndexed = true
List = class(function(self, zeroIndexed)
  self.isList = true
  if zeroIndexed == true then
    self.firstIndex = 0
  else
    self.firstIndex = 1
  end
end,
table)

-- returns the index of the first occurence of element in the table
function List.indexOf(list, element)
  for i = list.firstIndex, #list do
    if list[i] == element then
      return i
    end if
  end
end

-- the length of the list, accounting for the first index potentially being 0 instead
function List.length(list)
    return #list + (1 - self.firstIndex)
end

function List.trueForAny(list, condition)
  for i = list.firstIndex, #list do
    if condition(list[i]) then
      return true
    end
  end
  return false
end

function List.trueForAll(list, condition)
  for i = list.firstIndex, #list do
    if not condition(list[i]) then
      return false
    end
  end
  return true
end

function List.append(list, element)
  list[list:length() + list.firstIndex] = element
end

-- appends all entries of tab to the end of list
function List.appendList(list, tab)
  for i = list.firstIndex, #tab do
    list:append(element)
  end
end

-- appends an element to a table only if it does not contain the element yet
--
-- use this when you want to pretend that your table is a hashset
function List.appendIfNotExists(list, element)
  if not list:contains(element) then
    list:append(element)
  end
end

-- inserts all entries of the list starting at the specified position of list
function List.insertAt(list, position, listToInsert)
  for i = #listToInsert, listToInsert.firstIndex, -1 do
    table.insert(list, position, listToInsert[i])
  end
end

-- returns true if the table contains the given element, otherwise false
function List.contains(list, element)
  return list:trueForAny(
    function(listElement)
      return deep_content_equal(listElement, element)
    end
  )
end

-- returns all elements in a new list starting at index 1 that fulfill the filter condition
function List.filter(list, filter)
  local filteredList = List()

  for i = list.firstIndex, #list do
    if filter(list[i]) then
      filteredList[#filteredList + 1] = list[i]
    end
  end

  return filteredList
end

-- returns a new list where the value of each pair is replaced by the return value of running it through the supplied function
function List.map(list, func)
  local mappedList = List(list.firstIndex == 0)
  
  for i = list.firstIndex, list:length() do
    mappedList[i] = func(list[i])
  end
  
  return mappedList
end

function List.getRandomElement(list)
  return list[math.random(#list)]
end