require("client.src.TimeQueue")

local function processAssertNotRun(result)
  assert(false)
end

local function processAssertValue(value)
  return function(result)
    assert(result == value)
  end
end

local queue = TimeQueue()
assert(queue:length() == 0)

queue:push("1", 1)

queue:update(0.5, processAssertNotRun)
assert(queue:length() == 1)
queue:update(0.5, processAssertValue("1"))
assert(queue:length() == 0)

queue:push("2", 1)
queue:push("3", 4)
assert(queue:length() == 2)

queue:update(0.5, processAssertNotRun)
assert(queue:length() == 2)
queue:update(0.5, processAssertValue("2"))
assert(queue:length() == 1)
queue:update(0.5, processAssertNotRun)
assert(queue:length() == 1)
queue:update(3.5, processAssertValue("3"))
assert(queue:length() == 0)