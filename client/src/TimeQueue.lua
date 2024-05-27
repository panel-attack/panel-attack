local class = require("common.lib.class")
local logger = require("common.lib.logger")
local Queue = require("common.lib.Queue")

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

function TimeQueue:update(dt)
  self.now = self.now + dt
end

function TimeQueue:length()
  return self.queue:len()
end

function TimeQueue:clear()
  self:update(self.latestPush - self.now + 1)
end
