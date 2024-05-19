local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")
local ModLoader = require("client.src.mods.ModLoader")

local states = { loadingMods = 1, catchingUp = 2 }

local GameCatchUp = class(function(self, sceneParams)
  self.vsScene = sceneParams
  self.match = self.vsScene.match
  self.timePassed = 0
  self.progress = 0
  self.state = states.loadingMods
end,
Scene)

local function hasTimeLeft(t)
  return love.timer.getTime() < t + 0.9 * consts.FRAME_RATE
end

function GameCatchUp:update(dt)
  self.timePassed = self.timePassed + dt

  if not self.match.stacks[1].play_to_end then
    self.progress = 1
    self.vsScene:onGameStart()
    GAME.navigationStack:replace(self.vsScene)
  else
    self.progress = self.match.stacks[1].clock / #self.match.stacks[1].confirmedInput
  end
  local t = love.timer.getTime()
  local shouldCatchUp = ((self.match.stacks[1] and self.match.stacks[1].play_to_end) or (self.match.stacks[2] and self.match.stacks[2].play_to_end)) or ModLoader.loading_mod
  -- spend 90% of frame time on catchup
  -- since we're not drawing anything big that should be realistic for catching ASAP
  while shouldCatchUp and hasTimeLeft(t) do
    if self.state == states.loadingMods then
      if not ModLoader.update() then
        self.state = states.catchingUp
      end
    elseif self.state == states.catchingUp then
      self.match:run()
    end
  end
end

function GameCatchUp:draw()
  local match = self.match
  GraphicsUtil.setColor(1, 1, 1, 1)
  GraphicsUtil.drawRectangle("line", consts.CANVAS_WIDTH / 4 - 5, consts.CANVAS_HEIGHT / 2 - 25, consts.CANVAS_WIDTH / 2 + 10, 50)
  GraphicsUtil.drawRectangle("fill", consts.CANVAS_WIDTH / 4, consts.CANVAS_HEIGHT / 2 - 20, consts.CANVAS_WIDTH / 2 * self.progress, 40)
  GraphicsUtil.printf("Catching up: " .. match.stacks[1].clock .. " out of " .. #match.stacks[1].confirmedInput .. " frames", 0, 500, consts.CANVAS_WIDTH, "center")
end

return GameCatchUp