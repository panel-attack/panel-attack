
local queue = PriorityQueue()

-- Empty Case
assert(queue:size() == 0)

-- Popping base case
queue:put(1, 1)
assert(queue:size() == 1)
assert(queue:pop() == 1)
assert(queue:size() == 0)

-- Popping should pop the "lowest" value
queue:put(1, 2)
queue:put(2, 1)
assert(queue:size() == 2)
assert(queue:pop() == 2)
assert(queue:size() == 1)
assert(queue:pop() == 1)
assert(queue:size() == 0)

-- Popping should pop the first in on a tie
queue:put(1, 1)
queue:put(2, 1)
assert(queue:size() == 2)
assert(queue:pop() == 1)
assert(queue:size() == 1)
assert(queue:pop() == 2)
assert(queue:size() == 0)

-- Popping should pop the lowest, first in on a tie
queue:put(3, 2)
queue:put(4, 2)
queue:put(1, 1)
queue:put(2, 1)
assert(queue:size() == 4)
assert(queue:pop() == 1)
assert(queue:size() == 3)
assert(queue:pop() == 2)
assert(queue:size() == 2)
assert(queue:pop() == 3)
assert(queue:size() == 1)
assert(queue:pop() == 4)
assert(queue:size() == 0)

-- Popping should work the same with negative values
queue:put(3, -1)
queue:put(4, -1)
queue:put(1, -2)
queue:put(2, -2)
assert(queue:size() == 4)
assert(queue:pop() == 1)
assert(queue:size() == 3)
assert(queue:pop() == 2)
assert(queue:size() == 2)
assert(queue:pop() == 3)
assert(queue:size() == 1)
assert(queue:pop() == 4)
assert(queue:size() == 0)