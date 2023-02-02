-- Inspired by https://github.com/icrawler/FPSGraph but mostly rewritten.

local BarGraph = class(function(self, x, y, width, height, delay, maxValue, valueCount)
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
end)

BarGraph.font = love.graphics.newFont(12)

function BarGraph:updateGraph(val, label, dt)
  assert(type(val) == "table")

  self.cur_time = self.cur_time + dt

  while self.cur_time >= self.delay do
    self.cur_time = self.cur_time - self.delay

    self.vals[self.currentIndex] = val
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

function BarGraph.drawGraphs(graphs)
  local oldFont = love.graphics.getFont()
  love.graphics.setFont(BarGraph.font)

  -- loop through all of the graphs
  for j = 1, #graphs do
    local graph = graphs[j]
    local maxVal = graph.maxValue

    local xPosition = graph.x
    for i = 1, graph.barCount do
      local valueIndex = graph.currentIndex - 1 + i
      if valueIndex > graph.barCount then
        valueIndex = valueIndex - graph.barCount
      end
      local values = graph.vals[valueIndex]
      assert(type(values) == "table")
      local yPosition = graph.y + graph.height
      for index, value in ipairs(values) do
        local height = graph.height * (value / maxVal)
        local fillColor = graph.fillColors[index] or {1, 1, 1, 0.8}
        local strokeColor = graph.strokeColors[index] or {0, 0, 0, 0.4}
        love.graphics.setColor(unpack(fillColor))
        love.graphics.rectangle("fill", xPosition, yPosition - height, graph.barWidth, height)
        love.graphics.setColor(unpack(strokeColor))
        love.graphics.rectangle("line", xPosition + 0.5, yPosition - height + 0.5, graph.barWidth - 1, height - 1)
        yPosition = yPosition - height
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
  end

  love.graphics.setFont(oldFont)
end

return BarGraph
