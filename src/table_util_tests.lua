require("src/table_util")
local logger = require("src/logger")

local function getTestDataList()
  local testData = {
    {row = 1, column = 1, color = 2},
    {row = 1, column = 2, color = 1},
    {row = 2, column = 1, color = 3},
    {row = 2, column = 2, color = 3},
    {row = 3, column = 1, color = 4}
  }
  return testData
end

local function getTestDataDict()
  local testData = {}
  testData["row1"] = "210000"
  testData["row2"] = "330000"
  testData["row3"] = "400000"
  return testData
end

local function testTableMapList()
  local testData = getTestDataList()
  local mappedTable =
    table.map(
    testData,
    function(data)
      return data.color
    end
  )
  for i = 1, #testData do
    assert(testData[i].color == mappedTable[i])
  end

  logger.trace("passed test testTableMapList")
end

local function testTableMapDict()
  local testData = getTestDataDict()
  local mappedTable =
    table.map(
    testData,
    function(value)
      return string.sub(value, 1, 2)
    end
  )

  assert(mappedTable["row1"] == "21")
  assert(mappedTable["row2"] == "33")
  assert(mappedTable["row3"] == "40")

  logger.trace("passed test testTableMapDict")
end

local function testTableLength()
  local scrambledTable = {}
  for i = 1, 10 do
    scrambledTable[i] = i
  end
  scrambledTable[17] = 489

  assert(table.length(scrambledTable) == 11)

  logger.trace("passed test testTableLength")
end

local function testTableFilterList()
  local testData = getTestDataList()
  local expected = {
    {row = 2, column = 1, color = 3},
    {row = 2, column = 2, color = 3}
  }

  local filteredTable =
    table.filter(
    testData,
    function(data)
      return data.color == 3
    end
  )
  assert(#filteredTable == 2)
  for i = 1, #expected do
    assert(deep_content_equal(filteredTable[i], expected[i]))
  end

  logger.trace("passed test testTableFilterList")
end

local function testTableFilterDict()
  local testData = getTestDataDict()
  local expected = {}
  expected["row1"] = "210000"
  expected["row2"] = "330000"

  local filteredTable =
    table.filter(
    testData,
    function(value)
      return string.len(string.gsub(value, "0", "")) > 1
    end
  )
  assert(table.length(filteredTable) == 2)
  for i = 1, table.length(expected) do
    assert(deep_content_equal(filteredTable[i], expected[i]))
  end

  logger.trace("passed test testTableFilterDict")
end

local function testTableTrueForAnyList()
  local testData = getTestDataList()
  assert(
    table.trueForAny(
      testData,
      function(data)
        return data.color == 4
      end
    )
  )
  assert(
    not table.trueForAny(
      testData,
      function(data)
        return data.color == 5
      end
    )
  )

  logger.trace("passed test testTableAnyList")
end

local function testTableTrueForAnyDict()
  local testData = getTestDataDict()
  assert(
    table.trueForAny(
      testData,
      function(value)
        return string.sub(value, 2, 2) ~= "0"
      end
    )
  )
  assert(
    not table.trueForAny(
      testData,
      function(value)
        return string.len(value) > 6
      end
    )
  )

  logger.trace("passed test testTableAnyDict")
end

local function testTableTrueForAllList()
  local testData = getTestDataList()
  assert(
    table.trueForAll(
      testData,
      function(data)
        return data.color
      end
    )
  )
  assert(
    not table.trueForAll(
      testData,
      function(data)
        return data.row > 1
      end
    )
  )

  logger.trace("passed test testTableAll")
end

local function testTableTrueForAllDict()
  local testData = getTestDataDict()
  assert(
    table.trueForAll(
      testData,
      function(value)
        return string.len(value) == 6
      end
    )
  )
  assert(
    not table.trueForAll(
      testData,
      function(value)
        return string.sub(value, 2, 2) ~= "0"
      end
    )
  )

  logger.trace("passed test testTableAllDict")
end

local function testTableAppendToList()
  local testData = getTestDataList()
  local extraData = {
    {row = 4, column = 1, color = 5},
    {row = 5, column = 1, color = 1}
  }

  local expected = {
    {row = 1, column = 1, color = 2},
    {row = 1, column = 2, color = 1},
    {row = 2, column = 1, color = 3},
    {row = 2, column = 2, color = 3},
    {row = 3, column = 1, color = 4},
    {row = 4, column = 1, color = 5},
    {row = 5, column = 1, color = 1}
  }

  table.appendToList(testData, extraData)

  assert(#testData == #expected)
  for i = 1, #expected do
    assert(deep_content_equal(testData[i], expected[i]))
  end

  logger.trace("passed test testTableAppendToList")
end

local function testTableInsertListAt()
  local testData = getTestDataList()
  local extraData = {
    {row = 4, column = 1, color = 5},
    {row = 5, column = 1, color = 1}
  }

  local expected = {
    {row = 1, column = 1, color = 2},
    {row = 1, column = 2, color = 1},
    {row = 4, column = 1, color = 5},
    {row = 5, column = 1, color = 1},
    {row = 2, column = 1, color = 3},
    {row = 2, column = 2, color = 3},
    {row = 3, column = 1, color = 4}
  }

  table.insertListAt(testData, 3, extraData)

  assert(#testData == #expected)
  for i = 1, #expected do
    assert(deep_content_equal(testData[i], expected[i]))
  end

  logger.trace("passed test testTableInsertListAt")
end

local function testTableContainsList()
  local testData = getTestDataList()
  local data1 = {row = 1, column = 1, color = 2}
  local data2 = {row = 4, column = 1, color = 55}

  assert(table.contains(testData, data1))
  assert(not table.contains(testData, data2))

  logger.trace("passed test testTableContainsList")
end

local function testTableContainsDict()
  local testData = getTestDataDict()

  local data1 = "330000"
  local data2 = "helloWorld"

  assert(table.contains(testData, data1))
  assert(not table.contains(testData, data2))

  logger.trace("passed test testTableContainsDict")
end

-- how to search the keys of a dictionary using trueForAny, trueForAll or contains
local function testTableContainsDictKeys()
  local testData = getTestDataDict()
  local keys = table.getKeys(testData)
  local data1 = "row3"
  local data2 = "row4"

  assert(table.contains(keys, data1))
  assert(not table.contains(keys, data2))

  logger.trace("passed test testTableContainsDictKeys")
end

local function testTableGetKeys()
  local testData = getTestDataDict()
  local keys = table.getKeys(testData)

  for key, _ in pairs(testData) do
    assert(table.contains(keys, key))
  end

  logger.trace("passed test testTableGetKeys")
end

testTableGetKeys()
testTableTrueForAllList()
testTableTrueForAllDict()
testTableTrueForAnyList()
testTableTrueForAnyDict()
testTableContainsList()
testTableContainsDict()
testTableContainsDictKeys()
testTableFilterList()
testTableFilterDict()
testTableInsertListAt()
testTableAppendToList()
testTableLength()
testTableMapList()
testTableMapDict()
