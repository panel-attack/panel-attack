local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")
local consts = require("common.engine.consts")
local Telegraph = require("client.src.graphics.Telegraph")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local PixelFontLabel = require("client.src.ui.PixelFontLabel")
local TextButton = require("client.src.ui.TextButton")
local Label = require("client.src.ui.Label")
local input = require("common.lib.inputManager")

local PortraitGame = class(function(self, sceneParams)
  self.nextScene = sceneParams.nextScene

  self:load(sceneParams)
  self.match:connectSignal("matchEnded", self, self.onMatchEnded)
end,
GameBase)

PortraitGame.name = "PortraitGame"

local function getTimer(match)
  local frames = 0
  local stack = match.stacks[1]
  if stack ~= nil and stack.game_stopwatch ~= nil and tonumber(stack.game_stopwatch) ~= nil then
    frames = stack.game_stopwatch
  end

  if match.timeLimit then
    frames = (match.timeLimit * 60) - frames
    if frames < 0 then
      frames = 0
    end
  end

  return frames_to_time_string(frames, match.ended)
end

function PortraitGame:customLoad()
  self.uiRoot.width = consts.CANVAS_HEIGHT
  self.uiRoot.height = consts.CANVAS_WIDTH

  local timerScale = themes[config.theme].time_Scale
  self.uiRoot.timer = PixelFontLabel({text = getTimer(self.match), fontMap = themes[config.theme].fontMaps.time, hAlign = "center", y = 10, xScale = timerScale, yScale = timerScale})
  self.uiRoot:addChild(self.uiRoot.timer)

  -- recreate the global canvas in portrait dimensions
  GAME.globalCanvas = love.graphics.newCanvas(consts.CANVAS_HEIGHT, consts.CANVAS_WIDTH, {dpiscale=GAME:newCanvasSnappedScale()})

  local width, height, _ = love.window.getMode()
  if love.system.getOS() == "Android" then
    -- flip the window dimensions to portrait
    love.window.updateMode(height, width)
  elseif DEBUG_ENABLED then
    GAME:updateCanvasPositionAndScale(width, height)
  end

  for _, player in ipairs(self.match.players) do
    if player.isLocal and player.human and player.settings.inputMethod == "touch" then
      -- recreate the stack canvas to use a higher instead of the usual 3
      -- force center it
      local stack = player.stack
      stack.gfxScale = 5
      stack.canvas = love.graphics.newCanvas(104 * stack.gfxScale, 204 * stack.gfxScale, {dpiscale = GAME:newCanvasSnappedScale()})
      stack.frameOriginX = (GAME.globalCanvas:getWidth() / 2 - stack.canvas:getWidth() / 2) / stack.gfxScale
      stack.frameOriginY = (GAME.globalCanvas:getHeight() - stack.canvas:getHeight()) / stack.gfxScale
      stack.panelOriginX = stack.frameOriginX + stack.panelOriginXOffset
      stack.panelOriginY = stack.frameOriginY + stack.panelOriginYOffset
      -- TODO: create a raise button
      local raiseButton = TextButton({label = Label({text = "raise", fontSize = 20}), hAlign = "right", vAlign = "bottom", height = player.stack.canvas:getHeight() / 2})
      raiseButton.onTouch = function(button, x, y)
        button.backgroundColor[4] = 1
        stack.touchInputController.touchingRaise = true
      end
      raiseButton.onDrag = function(button, x, y)
        stack.touchInputController.touchingRaise = button:inBounds(x, y)
      end
      raiseButton.onRelease = function(button, x, y, timeHeld)
        button.backgroundColor[4] = 0.7
        stack.touchInputController.touchingRaise = false
      end
      raiseButton.width = 70
      self.uiRoot.raiseButton = raiseButton
      self.uiRoot:addChild(raiseButton)

      -- fixing multibar pos different from theme settings
      self.multibar = {}
      -- so basically offset does no longer apply
      -- but we want to try and keep the relationship between the different offsets I guess
      -- local framePos = themes[config.theme].healthbar_frame_Pos
      -- local barPos = themes[config.theme].multibar_Pos
      -- local overtimePos = themes[config.theme].multibar_LeftoverTime_Pos
      -- this might actually be way too finicky / not feasible with the theme asset / configs
      -- it might make sense to instead use a separate free floating multibar specifically for portrait mode based on the default theme one
      -- because otherwise there is really no telling what files / config we get
    end
  end
end

function PortraitGame:draw()
  if self.backgroundImage then
    self.backgroundImage:draw()
  end
  self.uiRoot:draw()
  for _, stack in ipairs(self.match.stacks) do
    -- don't render stacks that only have an attack engine
    if stack.is_local and stack.inputMethod == "touch" then
      stack:render()
      --stack:drawMultibar()
    end

    if stack.garbageTarget and stack.garbageTarget.is_local and stack.garbageTarget.inputMethod == "touch" then
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
  if love.system.getOS() == "Android" then
    love.window.updateMode(height, width)
  elseif DEBUG_ENABLED then
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
  self.uiRoot.timer:setText(getTimer(self.match))
end

return PortraitGame