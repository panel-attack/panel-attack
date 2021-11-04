--[[  Priority Queue implemented in lua, based on a binary heap.

Copyright (C) 2017 Lucas de Morais Siqueira <lucas.morais.siqueira@gmail.com>

License: zlib

  This software is provided 'as-is', without any express or implied
  warranty. In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgement in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
]]--

local floor = math.floor


local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue

setmetatable(
    PriorityQueue,
    {
        __call = function (self)
            setmetatable({}, self)
            self:initialize()
            return self
        end
    }
)


function PriorityQueue:initialize()
    --[[  Initialization.

    Example:
        PriorityQueue = require("priority_queue")
        pq = PriorityQueue()
    ]]--
    self.heap = {}
    self.current_size = 0
end

function PriorityQueue:empty()
    return self.current_size == 0
end

function PriorityQueue:size()
    return self.current_size
end

function PriorityQueue:swim()
    -- Swim up on the tree and fix the order heap property.
    local heap = self.heap
    local floor = floor
    local i = self.current_size

    while floor(i / 2) > 0 do
        local half = floor(i / 2)
        if heap[i][2] < heap[half][2] then
            heap[i], heap[half] = heap[half], heap[i]
        end
        i = half
    end
end

function PriorityQueue:put(v, p)
    --[[ Put an item on the queue.

    Args:
        v: the item to be stored
        p(number): the priority of the item
    ]]--
    --

    self.heap[self.current_size + 1] = {v, p}
    self.current_size = self.current_size + 1
    self:swim()
end

function PriorityQueue:sink()
    -- Sink down on the tree and fix the order heap property.
    local size = self.current_size
    local heap = self.heap
    local i = 1

    while (i * 2) <= size do
        local mc = self:min_child(i)
        if heap[i][2] > heap[mc][2] then
            heap[i], heap[mc] = heap[mc], heap[i]
        end
        i = mc
    end
end

function PriorityQueue:min_child(i)
    if (i * 2) + 1 > self.current_size then
        return i * 2
    else
        if self.heap[i * 2][2] < self.heap[i * 2 + 1][2] then
            return i * 2
        else
            return i * 2 + 1
        end
    end
end

function PriorityQueue:pop()
    -- Remove and return the top priority item
    local heap = self.heap
    local retval = heap[1][1]
    heap[1] = heap[self.current_size]
    heap[self.current_size] = nil
    self.current_size = self.current_size - 1
    self:sink()
    return retval
end

return PriorityQueue