local class = require("common.lib.class")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local ModController = require("client.src.mods.ModController")
local ModLoader = require("client.src.mods.ModLoader")
local logger = require("common.lib.logger")

local states = { loadingMods = 1, catchingUp = 2 }

-- a transition that displays an intermediary loading screen while the match of the newScene is catching up
-- once the match caught up, the transition ends
local CatchUpTransition = class(function(transition, oldScene, newScene)
  assert(newScene.match)
  transition.progress = 0
  transition.timePassed = 0
  transition.oldScene = oldScene
  transition.newScene = newScene
  transition.match = newScene.match
  local state = states.catchingUp

  for _, player in ipairs(transition.match.players) do
    local character = characters[player.settings.characterId]
    if not character.fully_loaded then
      state = states.loadingMods
      logger.debug("triggering character load from catchup transition for mod " .. character.id)
      ModController:loadModFor(character, player)
    end
  end

  local stage = stages[transition.match.stageId]
  if not stage.fully_loaded then
    state = states.loadingMods
    logger.debug("triggering stage load from catchup transition for mod " .. stage.id)
    ModController:loadModFor(stage, match)
  end

  transition.state = state
end)

local function hasTimeLeft(t)
  return love.timer.getTime() < t + 0.9 * consts.FRAME_RATE
end

function CatchUpTransition:update(dt)
  self.timePassed = self.timePassed + dt

  if not self.match.P1.play_to_end then
    self.progress = 1
    self.newScene:onGameStart()
  else
    self.progress = self.match.P1.clock / #self.match.P1.confirmedInput
  end
  local t = love.timer.getTime()
  local shouldCatchUp = ((self.match.P1 and self.match.P1.play_to_end) or (self.match.P2 and self.match.P2.play_to_end)) or ModLoader.loading_mod
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

function CatchUpTransition:draw()
  GraphicsUtil.setColor(1, 1, 1, 1)
  GraphicsUtil.drawRectangle("line", consts.CANVAS_WIDTH / 4 - 5, consts.CANVAS_HEIGHT / 2 - 25, consts.CANVAS_WIDTH / 2 + 10, 50)
  GraphicsUtil.drawRectangle("fill", consts.CANVAS_WIDTH / 4, consts.CANVAS_HEIGHT / 2 - 20, consts.CANVAS_WIDTH / 2 * self.progress, 40)
  GraphicsUtil.printf("Catching up: " .. self.match.P1.clock .. " out of " .. #self.match.P1.confirmedInput .. " frames", 0, 500, consts.CANVAS_WIDTH, "center")
end

return CatchUpTransition