local Queue = require("common.lib.Queue")

local queue = Queue()
assert(queue:peek() == nil)
assert(queue:len() == 0)

queue:push("1")
assert(queue:len() == 1)
assert(queue:peek() == "1")
assert(queue:len() == 1)

queue:push("2")
assert(queue:len() == 2)
assert(queue:peek() == "1")
assert(queue:len() == 2)

assert(queue:pop() == "1")
assert(queue:len() == 1)
assert(queue:peek() == "2")
assert(queue:len() == 1)

assert(queue:pop() == "2")
assert(queue:len() == 0)
assert(queue:peek() == nil)
