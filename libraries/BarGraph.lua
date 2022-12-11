-- Inspired by https://github.com/icrawler/FPSGraph but mostly rewritten.

local BarGraph = class(function(self, x, y, width, height, delay, maxValue)
  assert(width >= 10)
  assert(maxValue ~= nil)

  local vals = {}
  self.barWidth = 4
  for i = 1, math.floor((width) / self.barWidth) do
    table.insert(vals, {0})
  end

  self.x = math.floor(x or 0) -- | position of the graph
  self.y = math.floor(y or 0) -- |
  self.width = width --  | dimensions of the graph
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

    table.remove(self.vals, 1)
    table.insert(self.vals, val)
  end
  self.label = label
end

function BarGraph:setFillColor(color, index)
  self.fillColors[index] = color
end

function BarGraph.drawGraphs(graphs)
  local oldFont = love.graphics.getFont()
  gfx_q:push({love.graphics.setFont, {BarGraph.font}})

  -- loop through all of the graphs
  for j = 1, #graphs do
    local graph = graphs[j]
    local maxVal = graph.maxValue

    local xPosition = graph.x
    for _, values in ipairs(graph.vals) do
      assert(type(values) == "table")
      local yPosition = graph.y + graph.height
      for index, value in ipairs(values) do
        local height = graph.height * (value / maxVal)
        local fillColor = graph.fillColors[index] or {1, 1, 1, 0.8}
        local strokeColor = graph.strokeColors[index] or {0, 0, 0, 0.4}
        gfx_q:push({love.graphics.setColor, fillColor})
        gfx_q:push({love.graphics.rectangle, {"fill", xPosition, yPosition - height, graph.barWidth, height}})
        gfx_q:push({love.graphics.setColor, strokeColor})
        gfx_q:push({love.graphics.rectangle, {"line", xPosition + 0.5, yPosition - height + 0.5, graph.barWidth - 1, height - 1}})
        yPosition = yPosition - height
      end
      xPosition = xPosition + graph.barWidth
    end

    gfx_q:push({love.graphics.setColor, {1, 1, 1, 0.8}})
    gfx_q:push({love.graphics.rectangle, {"line", graph.x + 0.5, graph.y + 0.5, graph.width - 1, graph.height - 1}})

    gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})

    gfx_q:push({love.graphics.print, {graph.label, graph.x, graph.height + graph.y + 8}})
  end

  gfx_q:push({love.graphics.setFont, {oldFont}})
end

return BarGraph
