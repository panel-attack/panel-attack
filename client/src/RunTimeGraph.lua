local BarGraph = require("client.lib.BarGraph")
local consts = require("common.engine.consts")

local RunTimeGraph = class(function(self)
  local updateSpeed = consts.FRAME_RATE * 1
  local valueCount = 60
  local width = valueCount * 8
  local height = 50
  local x = consts.CANVAS_WIDTH - width
  local y = 4
  local padding = 80
  self.graphs = {}

  -- fps graph
  self.graphs[#self.graphs + 1] = BarGraph(x, y, width, height, updateSpeed, 60, valueCount, 1)
  self.graphs[#self.graphs]:setFillColor({0, 1, 0, 1}, 1)
  y = y + height + padding

  -- memory graph
  self.graphs[#self.graphs + 1] = BarGraph(x, y, width, height, updateSpeed, 256, valueCount, 1)
  y = y + height + padding

  -- leftover time
  self.graphs[#self.graphs + 1] = BarGraph(x, y, width, height, updateSpeed, consts.FRAME_RATE * 1, valueCount, 1)
  self.graphs[#self.graphs]:setFillColor({0, 1, 1, 1}, 1)
  y = y + height + padding

  -- run loop graph
  self.graphs[#self.graphs + 1] = BarGraph(x, y, width, height, updateSpeed, consts.FRAME_RATE * 1, valueCount, 6)
  self.graphs[#self.graphs]:setFillColor({0, 0, 1, 1}, 1) -- love.update
  self.graphs[#self.graphs]:setFillColor({1, 0.3, 0.3, 1}, 2) -- love.draw
  self.graphs[#self.graphs]:setFillColor({0.5, 0.5, 0.5, 1}, 3) -- self:draw + self:updateWithMetrics
  self.graphs[#self.graphs]:setFillColor({1, 1, 1, 1}, 4) -- love.present
  self.graphs[#self.graphs]:setFillColor({1, 0, 0, 1}, 5) -- manualGc
  self.graphs[#self.graphs]:setFillColor({0, 1, 0, 1}, 6) -- love.timer.sleep
  y = y + height + padding

  -- memory allocation graph
  self.memAllocGraph = BarGraph(x, y, width, height, updateSpeed, 128, valueCount, 4)
  self.memAllocGraph:setFillColor({0, 0, 1, 1}, 1) -- love.update
  self.memAllocGraph:setFillColor({1, 0.3, 0.3, 1}, 2) -- love.draw
  self.memAllocGraph:setFillColor({0.5, 0.5, 0.5, 1}, 3) -- self:draw + self:updateWithMetrics
  self.memAllocGraph:setFillColor({1, 1, 1, 1}, 4) -- love.present
end)

function RunTimeGraph:updateWithMetrics(runMetrics)
  local dt = runMetrics.dt
  local fps = math.round(1.0 / dt, 1)
  local averageFPS = love.timer.getFPS()
  local memAllocated = math.floor(runMetrics.updateMemAlloc + runMetrics.drawMemAlloc + runMetrics.graphMemAlloc + runMetrics.presentMemAlloc)
  self.graphs[1]:updateGraph("FPS: " .. averageFPS .. " (" .. fps .. ")", dt, fps)

  local memoryCount = collectgarbage("count")
  memoryCount = round(memoryCount / 1024, 1)
  self.graphs[2]:updateGraph("Memory: " .. memoryCount .. " Mb", dt, memoryCount)

  self.graphs[3]:updateGraph("leftover_time " .. leftover_time, dt, leftover_time)

  self.graphs[4]:updateGraph("Run Loop", dt, runMetrics.updateDuration,
                                             runMetrics.drawDuration,
                                             runMetrics.graphDuration,
                                             runMetrics.presentDuration,
                                             runMetrics.gcDuration,
                                             runMetrics.sleepDuration
                            )

  self.memAllocGraph:updateGraph("Memory Alloc " .. memAllocated .. "kB", dt, runMetrics.updateMemAlloc,
                                                                             runMetrics.drawMemAlloc,
                                                                             runMetrics.graphMemAlloc,
                                                                             runMetrics.presentMemAlloc)
end

function RunTimeGraph:draw()
  love.graphics.push()

  -- in order to not sully the draw data of the actual game, the RunTimeGraph is drawn separately
  -- these transformations assure it uses the same game coordinates as love.draw
  love.graphics.translate(GAME.canvasX, GAME.canvasY)
  love.graphics.scale(GAME.canvasXScale, GAME.canvasYScale)

  BarGraph.drawGraphs(self.graphs)
  if not collectgarbage("isrunning") then
    self.memAllocGraph:draw()
  end

  love.graphics.pop()
end

return RunTimeGraph
