require("table_util")

local function getTestData()
    local testData = {  { row = 1, column = 1, color = 2},
                        { row = 1, column = 2, color = 1},
                        { row = 2, column = 1, color = 3},
                        { row = 2, column = 2, color = 3},
                        { row = 3, column = 1, color = 4}}
    return testData
end

local function testTableMap()
    local testData = getTestData()
    local mappedTable = table.map(testData, function(data) return data.color end)
    for i=1,#testData do
        assert(testData[i].color == mappedTable[i])
    end

    print("Passed test testTableMap")
end

local function testTableLength()
    local scrambledTable = {}
    for i=1,10 do
        scrambledTable[i] = i
    end
    scrambledTable[17] = 489

    assert(table.length(scrambledTable) == 11)

    print("Passed test testTableLength")
end

local function testTableFilter()
    local testData = getTestData()
    local expected = {{ row = 2, column = 1, color = 3},
                      { row = 2, column = 2, color = 3}}

    local filteredTable = table.filter(testData, function(data) return data.color == 3 end)
    assert(#filteredTable == 2)
    for i=1, #expected do
        assert(deep_content_equal(filteredTable[i],expected[i]))
    end

    print("Passed test testTableFilter")

end

local function testTableAny()
    local testData = getTestData()
    assert(table.any(testData, function(data) return data.color == 4 end))
    assert(not table.any(testData, function(data) return data.color == 5 end))

    print("Passed test testTableAny")
end

local function testTableAll()
    local testData = getTestData()
    assert(table.all(testData, function(data) return data.color end))
    assert(not table.all(testData, function (data) return data.row > 1 end))

    print("Passed test testTableAll")
end

local function testTableAppendRange()
    local testData = getTestData()
    local extraData = { { row = 4, column = 1, color = 5},
                        { row = 5, column = 1, color = 1}}

    local expected =  { { row = 1, column = 1, color = 2},
                        { row = 1, column = 2, color = 1},
                        { row = 2, column = 1, color = 3},
                        { row = 2, column = 2, color = 3},
                        { row = 3, column = 1, color = 4},
                        { row = 4, column = 1, color = 5},
                        { row = 5, column = 1, color = 1}}
    
    table.appendRange(testData, extraData)

    assert(#testData == #expected)
    for i=1,#expected do
        assert(deep_content_equal(testData[i],expected[i]))
    end

    print("Passed test testTableAppendRange")
end

local function testTableInsertRange()
    local testData = getTestData()
    local extraData = { { row = 4, column = 1, color = 5},
                        { row = 5, column = 1, color = 1}}

    local expected =  { { row = 1, column = 1, color = 2},
                        { row = 1, column = 2, color = 1},
                        { row = 4, column = 1, color = 5},
                        { row = 5, column = 1, color = 1},
                        { row = 2, column = 1, color = 3},
                        { row = 2, column = 2, color = 3},
                        { row = 3, column = 1, color = 4}}
    
    table.insertRange(testData, 3, extraData)

    assert(#testData == #expected)
    for i=1,#expected do
        assert(deep_content_equal(testData[i],expected[i]))
    end

    print("Passed test testTableInsertRange")
end

local function testTableContains()
    local testData = getTestData()
    local data1 = { row = 1, column = 1, color = 2}
    local data2 = { row = 4, column = 1, color = 55}

    assert(table.contains(testData, data1))
    assert(not table.contains(testData, data2))

    print("Passed test testTableInsertRangeWithPos")
end

local function testTableGetIterator()
    local testData = getTestData()
    local i = 1
    local n = #testData

    for data in table.getIterator(testData) do
        assert( i <= n)
        assert(deep_content_equal(data, testData[i]))
        i = i + 1
    end
end

testTableAll()
testTableAny()
testTableContains()
testTableFilter()
testTableGetIterator()
testTableInsertRange()
testTableAppendRange()
testTableLength()
testTableMap()