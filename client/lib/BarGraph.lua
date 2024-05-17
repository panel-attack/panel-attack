-- Inspired by https://github.com/icrawler/FPSGraph but mostly rewritten.
local BarGraph = class(function(self, x, y, width, height, delay, maxValue, valueCount, subValueCount)
  assert(width >= 10)
  assert(maxValue ~= nil)
  assert(valueCount > 1)

  local vals = {}
  self.barCount = valueCount
  self.currentIndex = 1
  for _ = 1, self.barCount do
    table.insert(vals, {0})
  end

  self.x = math.floor(x or 0) -- | position of the graph
  self.y = math.floor(y or 0) -- |
  self.barWidth = math.floor(width / valueCount)
  self.width = self.barWidth * valueCount
  self.height = height or 30 -- |
  self.delay = delay or 0.5 -- delay until the next update
  self.vals = vals -- the values of the graph
  self.maxValue = maxValue -- fixed max value for graph if given
  self.cur_time = 0 -- the current time of the graph
  self.label = "graph" -- the label of the graph (changes when called by an update function)
  self.fillColors = {}
  self.strokeColors = {}
  -- how many values there are for each 
  self.subValueCount = subValueCount or 1
end)

BarGraph.font = love.graphics.newFont(12)

function BarGraph:updateGraph(label, dt, ...)
  self.cur_time = self.cur_time + dt

  while self.cur_time >= self.delay do
    self.cur_time = self.cur_time - self.delay

    local values = self.vals[self.currentIndex]
    for i = 1, self.subValueCount do
      -- nil is allowed as a 0 equivalent
      local val = select(i, ...) or 0
      assert(type(val) == "number", "Unexpected value type " .. tostring(type(val)) .." in bar graph update")
      values[i] = val
    end
    if self.currentIndex == self.barCount then
      self.currentIndex = 1
    else
      self.currentIndex = self.currentIndex + 1
    end
  end
  self.label = label
end

function BarGraph:setFillColor(color, index)
  self.fillColors[index] = color
end

local defaultStrokeColor = {0, 0, 0, 0.4}
local defaultFillColor = {1, 1, 1, 0.8}

function BarGraph.draw(graph)
  local oldFont = love.graphics.getFont()
  love.graphics.setFont(BarGraph.font)

  local xPosition = graph.x
  for i = 1, graph.barCount do
    local valueIndex = graph.currentIndex - 1 + i
    if valueIndex > graph.barCount then
      valueIndex = valueIndex - graph.barCount
    end
    local yPosition = graph.y + graph.height
    if type(graph.vals[valueIndex]) == "table" then
      local values = graph.vals[valueIndex]
      for index = 1, math.min(graph.subValueCount, #values) do
        local value = values[index]
        local height = graph.height * (value / graph.maxValue)
        local fillColor = graph.fillColors[index] or defaultFillColor
        local strokeColor = graph.strokeColors[index] or defaultStrokeColor
        love.graphics.setColor(unpack(fillColor))
        love.graphics.rectangle("fill", xPosition, yPosition - height, graph.barWidth, height)
        love.graphics.setColor(unpack(strokeColor))
        love.graphics.rectangle("line", xPosition + 0.5, yPosition - height + 0.5, graph.barWidth - 1, height - 1)
        yPosition = yPosition - height
      end
    end
    xPosition = xPosition + graph.barWidth
  end

  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.rectangle("line", graph.x + 0.5, graph.y + 0.5, graph.width - 1, graph.height - 1)

  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.rectangle("fill", graph.x, graph.height + graph.y + 8, graph.width, 20)

  love.graphics.setColor(1, 1, 1, 1)
  local padding = 4
  love.graphics.print(graph.label, graph.x + padding, graph.height + graph.y + 8 + padding)

  love.graphics.setFont(oldFont)
end

function BarGraph.drawGraphs(graphs)
  -- loop through all of the graphs
  for j = 1, #graphs do
    local graph = graphs[j]
    graph:draw()
  end
end

return BarGraph
