require("server_queue")

local queue = ServerQueue()

assert(queue:size() == 0)

-- queue:push(1)
-- assert(queue:size() == 1)
-- assert(queue:top() == 1)
-- assert(queue:size() == 1)
-- assert(queue:pop() == 1)
-- assert(queue:size() == 0)


local table1 = {test="a"}
local table2 = {bob="a"}
local table3 = {alice="a"}
queue:push(table1)
queue:push(table2)
queue:push(table3)

local results = queue:pop_all_with("bob")
assert(results[1] == table2)
assert(queue:top() == table1)
assert(queue:size() == 2)

assert(queue:pop_next_with("alice") == table3)
assert(queue:size() == 1)
assert(queue:pop_next_with("test") == table1)
assert(queue:size() == 0)

