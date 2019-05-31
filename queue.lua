Queue = class(function(q)
    q.first = 0
    q.last  = -1
  end)

function Queue.push(self, value)
  local last = self.last + 1
  self.last = last
  self[last] = value
end

function Queue.pop(self)
  local ret = nil
  local first = nil
  repeat
    first = self.first
    if first > self.last then
      error("q is empty")
    end
    ret = self[first]
    self[first] = nil
    if self.first == self.last then
      self.first = 0
      self.last = -1
    else
      self.first = first + 1
    end
  until (ret ~= nil)

  return ret
end

function Queue.get(self, i)
  return self[self.first + i - 1]
end

function Queue.remove(self, i)
  self[self.first + i - 1] = nil
end

function Queue.peek(self)
  if self.last == -1 then
    return self[first]
  else
    local ret
    local f = self.first
    repeat
      ret = self[f]
      f = f + 1
    until ret ~= nil
    return ret
  end
end

function Queue.len(self)
  local ret = 0

  for i=1,(self.last - self.first + 1) do
    if self[self.first + i - 1] ~= nil then
      ret = ret + 1
    end
  end

  return ret
end

function Queue.clear(self)
  for i=self.first,self.last do
    self[i]=nil
  end
  self.first = 0
  self.last = -1
end
