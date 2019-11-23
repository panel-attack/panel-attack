ServerQueue = class(function(self, capacity)
  if not capacity then error("ServerQueue: you need to specify a capacity") end
  self.capacity = capacity
  self.data = {}
  self.first = 0
  self.last  = -1
  self.empties = 0
  end)

function ServerQueue.print(self)
  print("QUEUE")
  for k,v in pairs(self.data) do
    print("=====================")
    print(k)
    for a,b in pairs(v) do
      print(";")
      print(a)
      print(b)
    end
    print("=====================")
  end
end

-- push a server message in queue
function ServerQueue.push(self, msg)
  local last = self.last + 1
  self.last = last
  self.data[last] = msg
  if self:size() > self.capacity then
    local first = self.first
    self.data[first] = nil
    self.first = first + 1
  end
  --self:print()
end

-- pop oldest server message in queue
function ServerQueue.pop(self)
  local first = self.first
  local ret = nil

  while ret == nil do
    ret = self.data[first]
    self.data[first] = nil
    if first >= self.last then
      first = 0
      self.last = -1
      break
    else 
      if ret == nil then
        self.empties = self.empties - 1
      end
      first = first + 1
    end
  end

  self.first = first
  self:check_empty()

  return ret
end

-- pop first element found with a message containing specified keys...
function ServerQueue.pop_next_with(self, ...)
  if self.first > self.last then
    return
  end

  local still_empty = true
  for i=self.first,self.last do
    local msg = self.data[i]
    if msg ~= nil then
      still_empty = false
      for j=1,select('#', ...) do
        if msg[select(j, ...)] ~= nil then
          self:remove(i)
          --print("POP "..select(j, ...))
          return msg
        end
      end
    elseif still_empty then
      self.first = self.first + 1
      self.empties = self.empties - 1
    end
  end
end

-- pop all messages containing specified keys...
function ServerQueue.pop_all_with(self, ...)
  local ret = {}

  if self.first <= self.last then
    local still_empty = true
    for i=self.first,self.last do
      local msg = self.data[i]
      if msg ~= nil then
        still_empty = false
        for j=1,select('#', ...) do
          if msg[select(j, ...)] ~= nil then
            ret[#ret+1] = msg
            --print("POP "..select(j, ...))
            self:remove(i)
            break
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
    for i=self.first,self.last do
      self.data[i]=nil
    end
  end
  self.first = 0
  self.last = -1
  self.empties = 0
end
