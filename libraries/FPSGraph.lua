--[[
	MIT LICENSE

    Copyright (c) 2014 Phoenix C. Enero

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--

local fpsGraph = {}

fpsGraph.fpsFont = love.graphics.newFont(8)

-- creates a graph table (too lazy to make objects and stuff)
function fpsGraph.createGraph(x, y, width, height, delay, draggable)

	-- create a value table such that the distance between two points is atleast 2 pixels
	local vals = {}
	for i=1, math.floor((width or 50)/2) do
		table.insert(vals, 0)
	end

	-- return the table
	return {
		x = x or 0, -- | position of the graph
		y = y or 0, -- |
		width = width or 50, --  | dimensions of the graph
		height = height or 30, --|
		delay = delay or 0.5, -- delay until the next update
		draggable = draggable or true, -- whether it is draggable or not
		vals = vals, -- the values of the graph
		vmax = 0, -- the maximum value of the graph
		cur_time = 0, -- the current time of the graph
		label = "graph", -- the label of the graph (changes when called by an update function)
		_dx = 0, -- used for calculating the distance between the mouse and the pos
		_dy = 0, -- as you are clicking the graph
		_isDown = false -- check if the graph is still down
	}
end

-- update the graph's values (make an update wrapper function if you want
-- to use this for your own purposes)
function fpsGraph.updateGraph(graph, val, label, dt)
	-- update the current time of the graph
	graph.cur_time = graph.cur_time + dt

	-- get mouse position
	local mouseX, mouseY = love.mouse.getPosition()

	-- code for draggable graphs
	if graph.draggable then
		if (mouseX < graph.width+graph.x and mouseX > graph.x and
		   mouseY < graph.height+graph.y and mouseY > graph.y) or graph._isDown then
			if love.mouse.isDown(1) then
				graph._isDown = true
				graph.x = mouseX - graph._dx
				graph.y = mouseY - graph._dy
			else
				graph._isDown = false
				graph._dx = mouseX - graph.x
				graph._dy = mouseY - graph.y
			end
		end
	end

	-- when current time is bigger than the delay
	while graph.cur_time >= graph.delay do
		-- subtract current time by delay
		graph.cur_time = graph.cur_time - graph.delay

		-- add new values to the graph while removing the first
		table.remove(graph.vals, 1)
		table.insert(graph.vals, val)

		-- get the new max variable
		local max = 0
		for i=1, #graph.vals do
			local v = graph.vals[i]
			if v > max then
				max = v
			end
		end

		-- update the max and label variables
		graph.vmax = max
		graph.label = label
	end
end

-- Updates the FPS graph
function fpsGraph.updateFPS(graph, dt)
	local fps = 0.75*1/dt + 0.25*love.timer.getFPS()

	fpsGraph.updateGraph(graph, fps, "FPS: " .. math.floor(fps*10)/10, dt)
end

-- Updates the Memory graph
function fpsGraph.updateMem(graph, dt)
	local mem = collectgarbage("count")

	fpsGraph.updateGraph(graph, mem, "Memory (KB): " .. math.floor(mem*10)/10, dt)
end

-- draws all the graphs in your list
function fpsGraph.drawGraphs(graphs)
	-- set default font
	love.graphics.setFont(fpsGraph.fpsFont)

	-- loop through all of the graphs
	for j=1, #graphs do
		local v = graphs[j]
		-- round values
		local maxVal = math.ceil(v.vmax/10)*10+20
		local len = #v.vals
		local step = v.width/len

		-- draw graph
		for i=2, len do
			local a = v.vals[i-1]
			local b = v.vals[i]
			love.graphics.line(step*(i-2)+v.x, v.height*(-a/maxVal+1)+v.y,
							   step*(i-1)+v.x, v.height*(-b/maxVal+1)+v.y)
		end

		-- print the label of the graph
		love.graphics.print(v.label, v.x, v.height+v.y-8)
	end
end

return fpsGraph