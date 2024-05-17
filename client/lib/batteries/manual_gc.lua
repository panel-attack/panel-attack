--[[
Copyright 2021 Max Cahill

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.

  "semi-manual" garbage collection
  specify a time budget and a memory ceiling per call.
  called once per frame, this will spread any big collections
  over several frames, and "catch up" when there is too much
  work to do.
  This keeps GC time burden much more predictable.
  The memory ceiling provides a safety backstop.
  if exceeded it will trigger a "full" collection, and this will
  hurt performance - you'll notice the hitch. If you hit your ceiling,
  it indicates you likely need to either find a way to generate less
  garbage, or spend more time each frame collecting.
  the function instructs the garbage collector only as small a step
  as possible each iteration. this prevents the "spiky" collection
  patterns, though with particularly large sets of tiny objects,
  the start of a collection can still take longer than you might like.
  default values:
  time_budget - 1ms (1e-3)
    adjust down or up as needed. games that generate more garbage
    will need to spend longer on gc each frame.
      during PA matches, CustomRun will pass in the remaining idle time each frame
      clients will use the full remaining time until the step limit
  memory_ceiling - 64mb
    a good place to start, though some games will need much more.
    remember, this is lua memory, not the total memory consumption
    of your game.
      for PA upped to 256 MB, 2 stacks with full rollback on long game durations takes up 100MB 
      on slower machines this may pile up and break through even 128MB too easily
  disable_otherwise - false
    disabling the gc completely is dangerous - any big allocation
    event (eg - level gen) could push you to an out of memory
    situation and crash your game. test extensively before you
    ship a game with this set true.
]]

return function(time_budget, memory_ceiling, disable_otherwise)
	time_budget = time_budget or 1e-3
  -- 64 MB memory is too low for long replays, they are guaranteed to hit the limit
  -- On weaker machines, it may pile up so quickly that even 128 may be breached (accumulating several MBs per second)
  -- so putting 256 MB for now
	memory_ceiling = memory_ceiling or 256
  -- original step limit was 10000
  -- after some testing it turns out that machines in need of more garbage collection won't reach that many steps
  -- while strong machines will just consume a lot more CPU; 5000 should be enough to guarantee performance
  local max_steps = 5000
	local steps = 0
	local start_time = love.timer.getTime()
	while
		love.timer.getTime() - start_time < time_budget and
		steps < max_steps
	do
		collectgarbage("step", 1)
		steps = steps + 1
	end
	--safety net
	if collectgarbage("count") / 1024 > memory_ceiling then
		collectgarbage("collect")
	end
	--don't collect gc outside this margin
	if disable_otherwise then
		collectgarbage("stop")
	end
end