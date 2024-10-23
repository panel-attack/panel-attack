local class = require("common.lib.class")

-- A class representing a Queue data structure where you typically put new data on the front and take data off the back.
-- TODO consolidate with ServerQueue
Queue =
  class(
  function(q)
    q.first = 0
    q.last = -1
  end
)

function Queue.push(self, value)
  local last = self.last + 1
  self.last = last
  self[last] = value
end

function Queue.pop(self)
  local first = self.first
  if first > self.last then
    error("Queue is empty")
  end
  local ret = self[first]
  self[first] = nil
  if self.first == self.last then
    self.first = 0
    self.last = -1
  else
    self.first = first + 1
  end
  return ret
end

function Queue.peek(self)
  return self[self.first]
end

function Queue.len(self)
  return self.last - self.first + 1
end

function Queue.clear(self)
  for i = self.first, self.last do
    self[i] = nil
  end
  self.first = 0
  self.last = -1
end

function Queue:contains(element)
  for i = self.first, self.last do
    if self[i] == element then
      return true
    end
  end
  return false
end

-- returns a shallow copy of the queue content
-- metatable not included!
-- an optional table argument may be passed in to serve as the table so no new table is created
function Queue:getShallowCopy(copy)
  if not copy then
    copy = {}
  end
  for i = self.first, self.last do
    copy[i] = self[i]
  end
  copy.first = self.first
  copy.last = self.last

  return copy
end

return Queue