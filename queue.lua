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
    local first = self.first
    if first > self.last then
        error("q is empty")
    end
    local ret = self[first]
    self[first] = nil
    self.first = first + 1
    return ret
end

function Queue.len(self)
    return self.last - self.first + 1
end

function Queue.clear(self)
    for i=self.first,self.last do
        self[i]=nil
    end
    self.first = 0
    self.last = -1
end
