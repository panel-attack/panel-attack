local BarGraph = require("libraries.BarGraph")
local consts = require("consts")

local RunTimeGraph = class(function(self)
  local updateSpeed = consts.frameRate * 1
  local x = 880
  local y = 0
  local width = 400
  local height = 50
  local padding = 80
  self.graphs = {}

  -- fps graph
  self.graphs[#self.graphs + 1] = BarGraph(x, y, width, height, updateSpeed, 60)
  self.graphs[#self.graphs]:setFillColor({0, 1, 0, 1}, 1)
  y = y + height + padding

  -- memory graph
  self.graphs[#self.graphs + 1] = BarGraph(x, y, width, height, updateSpeed, 20)
  y = y + height + padding

  -- leftover time
  self.graphs[#self.graphs + 1] = BarGraph(x, y, width, height, updateSpeed, consts.frameRate * 1)
  self.graphs[#self.graphs]:setFillColor({0, 1, 1, 1}, 1)
  y = y + height + padding

  -- run loop graph
  self.graphs[#self.graphs + 1] = BarGraph(x, y, width, height, updateSpeed, consts.frameRate * 1)
  self.graphs[#self.graphs]:setFillColor({0, 1, 0, 1}, 1) -- update
  self.graphs[#self.graphs]:setFillColor({1, 0.5, 0, 1}, 2) -- draw
  self.graphs[#self.graphs]:setFillColor({0, 0, 1, 1}, 3) -- sleep
  self.graphs[#self.graphs]:setFillColor({1, 1, 1, 1}, 4) -- present
  y = y + height + padding
end)

function RunTimeGraph:updateWithMetrics(runMetrics)
  local dt = runMetrics.dt
  local fps = math.round(1.0 / dt, 1)
  local averageFPS = love.timer.getFPS()
  self.graphs[1]:updateGraph({fps}, "FPS: " .. averageFPS .. " (" .. fps .. ")", dt)

  local memoryCount = collectgarbage("count")
  memoryCount = round(memoryCount / 1024, 1)
  self.graphs[2]:updateGraph({memoryCount}, "Memory: " .. memoryCount .. " Mb", dt)

  self.graphs[3]:updateGraph({leftover_time}, "leftover_time " .. leftover_time, dt)

  self.graphs[4]:updateGraph({runMetrics.updateDuration, runMetrics.drawDuration, runMetrics.sleepDuration, runMetrics.presentDuration},
                             "Run Loop", dt)
end

function RunTimeGraph:draw()
  BarGraph.drawGraphs(self.graphs)
end

return RunTimeGraph
