
-- Tracks a queue data structure.
-- Also provides a capacity and drops messages with an error if that capacity is exceeded.
-- Also provides a time expiration for messages
-- Values are tracked via incrementing ID keys, when something is nilled it is tracked as an "empty"
ServerQueue =
  class(
  function(self, capacity)
    if not capacity then
      error("ServerQueue: you need to specify a capacity")
    end
    self.capacity = capacity
    self.data = {}
    self.first = 0
    self.last = -1
    self.empties = 0
  end
)

function ServerQueue.to_string(self)
  return "QUEUE: " .. dump(self)
end

function ServerQueue.to_short_string(self)
  local returnString = ""

  if self.first <= self.last then
    local still_empty = true
    for i = self.first, self.last do
      local msg = self.data[i]
      if msg ~= nil then
        for type, data in pairs(msg) do
          if type ~= "_expiration" then
            returnString = returnString .. type .. " "
          end
        end
      end
    end
  end

  return returnString
end

function ServerQueue.has_expired(self, msg)
  if os.time() > msg._expiration then
    str = "ServerQueue: a message has expired (" .. (os.time() - msg._expiration) .. ")\n"
    for k, v in pairs(msg) do
      str = str .. k .. ", "
    end
    warning(str .. "\n" .. self:to_string())
    return true
  end
  return false
end

-- push a server message in queue
function ServerQueue.push(self, msg)
  local last = self.last + 1
  self.last = last
  msg._expiration = os.time() + SERVER_QUEUE_EXPIRATION_LENGTH -- add an expiration date in seconds
  self.data[last] = msg
  if self:size() > self.capacity then
    local first = self.first
    local str = "ServerQueue: the queue ran out of room\n"
    warning(str .. "\n" .. self:to_string())
    self.data[first] = nil
    self.first = first + 1
  end
end

-- pop oldest server message in queue
function ServerQueue.pop(self)
  local first = self.first
  local ret = nil

  while ret == nil do
    if first >= self.last then
      first = 0
      self.last = -1
      break
    else
      ret = self.data[first]
      self.data[first] = nil
      if ret == nil then
        self.empties = self.empties - 1
      else
        if self:has_expired(ret) then
          self:remove(first)
          ret = nil
        end
      end
      first = first + 1
    end
  end

  self.first = first
  self:check_empty()

  return ret
end

-- pop first element found with a message containing any specified keys...
function ServerQueue.pop_next_with(self, ...)
  if self.first > self.last then
    return
  end

  local still_empty = true
  for i = self.first, self.last do
    local msg = self.data[i]
    if msg ~= nil then
      still_empty = false
      for j = 1, select("#", ...) do
        if msg[select(j, ...)] ~= nil then
          --print("POP "..select(j, ...))
          self:remove(i)
          if not self:has_expired(msg) then
            return msg
          end
        end
      end
    elseif still_empty then
      self.first = self.first + 1
      self.empties = self.empties - 1
    end
  end
end

-- pop all messages containing any specified keys...
function ServerQueue.pop_all_with(self, ...)
  local ret = {}

  if self.first <= self.last then
    local still_empty = true
    for i = self.first, self.last do
      local msg = self.data[i]
      if msg ~= nil then
        still_empty = false
        for j = 1, select("#", ...) do
          if msg[select(j, ...)] ~= nil then
            --print("POP "..select(j, ...))
            ret[#ret + 1] = msg
            self:remove(i)
            if not self:has_expired(msg) then
              break
            end
          end
        end
      elseif still_empty then
        self.first = self.first + 1
        self.empties = self.empties - 1
      end
    end
  end
  return ret
end

function ServerQueue.remove(self, index)
  if self.data[index] then
    self.data[index] = nil
    self.empties = self.empties + 1
    self:check_empty()
    return true
  end
  return false
end

function ServerQueue.top(self)
  return self.data[self.first]
end

function ServerQueue.size(self)
  return self.last - self.first - self.empties + 1
end

function ServerQueue.check_empty(self)
  if self:size() == 0 then
    self.first = 0
    self.last = -1
    self.empties = 0
  end
end

function ServerQueue.clear(self)
  if self.first >= self.last then
    for i = self.first, self.last do
      self.data[i] = nil
    end
  end
  self.first = 0
  self.last = -1
  self.empties = 0
end
