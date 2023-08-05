require("class")
local logger = require("logger")
require("queue")

-- A class representing a Queue that pops based on time
TimeQueue =
  class(
  function(self)
    self.queue = Queue()
    self.latestPush = 0
    self.now = 0
  end
)

-- queueDuration is the amount of time to wait from now, but won't go any earlier than previous queue items
function TimeQueue:push(value, queueDuration)
  local popTime = self.now + queueDuration
  if popTime < self.latestPush then
    popTime = self.latestPush
  end
  self.latestPush = popTime
  self.queue:push({value, popTime})
end

function TimeQueue:popIfReady()
  local peeked = self.queue:peek()
  local now = self.now
  local result = nil
  if peeked ~= nil and peeked[2] <= now then
    result = self.queue:pop()[1]
  end
  return result
end

function TimeQueue:pop()
  return self.queue:pop()
end

function TimeQueue:update(dt, processFunction)
  self.now = self.now + dt
  local current = self:popIfReady()
  while current ~= nil do
    processFunction(current)
    current = self:popIfReady()
  end
end

function TimeQueue:length()
  return self.queue:len()
end

function TimeQueue:clearAndProcess(processFunction)
  self:update(9999999999, processFunction)
  self.now = 0
  self.latestPush = 0
end
