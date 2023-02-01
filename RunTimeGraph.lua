local BarGraph = require("libraries.BarGraph")
local consts = require("consts")

local RunTimeGraph = class(function(self)
  local updateSpeed = consts.FRAME_RATE * 1
  local valueCount = 60
  local width = valueCount * 8
  local height = 50
  local x = canvas_width - width
  local y = 4
  local padding = 80
  self.graphs = {}

  -- fps graph
  self.graphs[#self.graphs + 1] = BarGraph(x, y, width, height, updateSpeed, 60, valueCount)
  self.graphs[#self.graphs]:setFillColor({0, 1, 0, 1}, 1)
  y = y + height + padding

  -- memory graph
  self.graphs[#self.graphs + 1] = BarGraph(x, y, width, height, updateSpeed, 256, valueCount)
  y = y + height + padding

  -- leftover time
  self.graphs[#self.graphs + 1] = BarGraph(x, y, width, height, updateSpeed, consts.FRAME_RATE * 1, valueCount)
  self.graphs[#self.graphs]:setFillColor({0, 1, 1, 1}, 1)
  y = y + height + padding

  -- run loop graph
  self.graphs[#self.graphs + 1] = BarGraph(x, y, width, height, updateSpeed, consts.FRAME_RATE * 1, valueCount)
  self.graphs[#self.graphs]:setFillColor({0, 1, 0, 1}, 1) -- love.update
  self.graphs[#self.graphs]:setFillColor({1, 0.3, 0.3, 1}, 3) -- love.draw
  self.graphs[#self.graphs]:setFillColor({0.5, 0.5, 0.5, 1}, 2) -- self:draw + self:updateWithMetrics
  self.graphs[#self.graphs]:setFillColor({1, 1, 1, 1}, 4) -- love.present
  self.graphs[#self.graphs]:setFillColor({0.2, 0.2, 1, 1}, 5) -- manualGc
  self.graphs[#self.graphs]:setFillColor({0, 0, 1, 1}, 6) -- love.timer.sleep

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

  self.graphs[4]:updateGraph({runMetrics.updateDuration,
                              runMetrics.drawDuration,
                              runMetrics.graphDuration,
                              runMetrics.presentDuration,
                              runMetrics.gcDuration,
                              runMetrics.sleepDuration
                            },
                             "Run Loop", dt)
end

function RunTimeGraph:draw()
  love.graphics.push()

  love.graphics.translate(GAME.canvasX, GAME.canvasY)
  love.graphics.scale(GAME.canvasXScale, GAME.canvasYScale)

  BarGraph.drawGraphs(self.graphs)

  love.graphics.pop()
end

return RunTimeGraph
