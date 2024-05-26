-- starting to play a streamed Source can be slow because love has to buffer some data
-- slow in that case is on the magnitude of up to 10ms
-- if that happens during gameplay this can easily cause a framedrop on slower machines
-- by moving the Source:play into a thread, the rest of PA does not have to wait for this to happen
-- love userdata is shared between threads and this includes sources
-- that means the source can just be passed as an argument
-- the thread can be reused once it finished executing

require("love.audio")

local source = ...
source:play()