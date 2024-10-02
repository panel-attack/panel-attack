local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")
local consts = require("common.engine.consts")
local Telegraph = require("client.src.graphics.Telegraph")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local PixelFontLabel = require("client.src.ui.PixelFontLabel")

local PortraitGame = class(function(self, sceneParams)
  self.nextScene = sceneParams.nextScene

  self:load(sceneParams)
  self.match:connectSignal("matchEnded", self, self.onMatchEnded)
end,
GameBase)

PortraitGame.name = "PortraitGame"

function PortraitGame:customLoad()
  self.uiRoot.width = consts.CANVAS_HEIGHT
  self.uiRoot.height = consts.CANVAS_WIDTH

  self.uiRoot.timer = PixelFontLabel({fontMap = themes[config.theme].fontMaps.time, hAlign = "center", y = 10})
  self.uiRoot:addChild(self.uiRoot.timer)

  -- recreate the global canvas in portrait dimensions
  GAME.globalCanvas = love.graphics.newCanvas(consts.CANVAS_HEIGHT, consts.CANVAS_WIDTH, {dpiscale=GAME:newCanvasSnappedScale()})
  -- flip the window dimensions to portrait

  local width, height, _ = love.window.getMode()
  if love.system.getOS() == "Android" then
    love.window.updateMode(height, width)
  else
    GAME:updateCanvasPositionAndScale(width, height)
  end

  for _, player in ipairs(self.match.players) do
    if player.isLocal and player.human and player.settings.inputMethod == "touch" then
      -- recreate the stack canvas to use gfxScale of 5 instead of the usual 3
      -- force center it
      player.stack.gfxScale = 5
      player.stack.canvas = love.graphics.newCanvas(104 * 5, 204 * 5, {dpiscale = GAME:newCanvasSnappedScale()})
      player.stack.frameOriginX = (GAME.globalCanvas:getWidth() / 2 - player.stack.canvas:getWidth() / 2) / 5
      -- TODO: create a raise button
    end
  end
end

function PortraitGame:draw()
  self.uiRoot:draw()
  for _, stack in ipairs(self.match.stacks) do
    -- don't render stacks that only have an attack engine
    if stack.is_local and stack.inputMethod == "touch" then
      stack:render()
    end

    if stack.garbageTarget and stack.garbageTarget.isLocal and stack.garbageTarget.inputMethod == "touch" then
      Telegraph:render(stack, stack.garbageTarget)
    end
  end

  self:drawCommunityMessage()

  if self.match.ended then
    local winners = self.match:getWinners()
    local pos = themes[config.theme].gameover_text_Pos
    local message
    if #winners == 1 then
      message = loc("ss_p_wins", winners[1].name)
    else
      message = loc("ss_draw")
    end
    GraphicsUtil.printf(message, pos.x, pos.y, consts.CANVAS_WIDTH, "center")
  end
end

function PortraitGame:onMatchEnded(match)
  -- recreate the global canvas in landscape dimensions
  GAME.globalCanvas = love.graphics.newCanvas(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT, {dpiscale=GAME:newCanvasSnappedScale()})
  -- flip the window dimensions to landscape
  local width, height, _ = love.window.getMode()
  -- love.window.updateMode(height, width)
  if love.system.getOS() == "Android" then
    love.window.updateMode(height, width)
  else
    GAME:updateCanvasPositionAndScale(width, height)
  end
  for _, player in ipairs(self.match.players) do
    if player.isLocal and player.human and player.settings.inputMethod == "touch" then
      -- recreate the stack canvas to use gfxScale of 3
      player.stack.gfxScale = 3
      player.stack.canvas = love.graphics.newCanvas(104 * 3, 204 * 3, {dpiscale = GAME:newCanvasSnappedScale()})
    end
  end
end

function PortraitGame:customRun()
  local frames = 0
  local stack = self.match.stacks[1]
  if stack ~= nil and stack.game_stopwatch ~= nil and tonumber(stack.game_stopwatch) ~= nil then
    frames = stack.game_stopwatch
  end

  if self.match.timeLimit then
    frames = (self.match.timeLimit * 60) - frames
    if frames < 0 then
      frames = 0
    end
  end
  self.uiRoot.timer:setText(frames_to_time_string(frames, self.match.ended))
end

return PortraitGame