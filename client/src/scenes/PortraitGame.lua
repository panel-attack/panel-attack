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

  local communityMessage = Label({
    text = "join_community",
    replacements = {"\ndiscord." .. consts.SERVER_LOCATION},
    translate = true,
    hAlign = "center",
    vAlign = "top",
    y = 10,
  })
  self.uiRoot.communityMessage = communityMessage
  self.uiRoot:addChild(self.uiRoot.communityMessage)

  local timerScale = themes[config.theme].time_Scale
  self.uiRoot.timer = PixelFontLabel({
    text = getTimer(self.match),
    fontMap = themes[config.theme].fontMaps.time,
    hAlign = "center",
    y = 60,
    xScale = timerScale,
    yScale = timerScale,
  })
  self.uiRoot:addChild(self.uiRoot.timer)

  -- recreate the global canvas in portrait dimensions
  GAME.globalCanvas = love.graphics.newCanvas(consts.CANVAS_HEIGHT, consts.CANVAS_WIDTH, {dpiscale=GAME:newCanvasSnappedScale()})

  local width, height, _ = love.window.getMode()
  if love.system.getOS() == "Android" then
    -- flip the window dimensions to portrait
    love.window.updateMode(height, width)
    love.window.setFullscreen(true)
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
      stack.origin_x = stack.frameOriginX / stack.gfxScale

      -- create a raise button that interacts with the touch controller
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
    else
      local stack = player.stack
      stack.gfxScale = 1
      stack.canvas = love.graphics.newCanvas(104 * stack.gfxScale, 204 * stack.gfxScale, {dpiscale = GAME:newCanvasSnappedScale()})
      stack.frameOriginX = (GAME.globalCanvas:getWidth() - stack.canvas:getWidth()) - 12
      stack.frameOriginY = 10
      stack.panelOriginX = stack.frameOriginX + stack.panelOriginXOffset
      stack.panelOriginY = stack.frameOriginY + stack.panelOriginYOffset
      stack.origin_x = stack.frameOriginX / stack.gfxScale
    end
  end
end

function PortraitGame:drawBar(stack, image, quad, themePositionOffset, height, yOffset, rotate, scale)
  local imageWidth, imageHeight = image:getDimensions()
  local barYScale = height / imageHeight
  local quadY = 0
  if barYScale < 1 then
    barYScale = 1
    quadY = imageHeight - height
  end
  local x = (stack.frameOriginX + stack.panelOriginXOffset + themePositionOffset[1] / 3) * stack.gfxScale
  local y = (stack.panelOriginY + themePositionOffset[2] / 3) * stack.gfxScale
  quad:setViewport(0, quadY, imageWidth, imageHeight - quadY)
  GraphicsUtil.drawQuad(image, quad, x, y - height - yOffset, rotate, scale * stack.gfxScale / 3, scale * barYScale, 0, 0, 1)
end

-- when using the stack function, the multibar ends up somewhere
-- so just force absolute multibar with a somewhat fixed draw
function PortraitGame:drawMultibar(stack)
  local stop_time = stack.stop_time
  local shake_time = stack.shake_time

  -- before the first move, display the stop time from the puzzle, not the stack
  if stack.puzzle and stack.puzzle.puzzleType == "clear" and stack.puzzle.moves == stack.puzzle.remaining_moves then
    stop_time = stack.puzzle.stop_time
    shake_time = stack.puzzle.shake_time
  end

  framePos = framePos or themes[config.theme].healthbar_frame_Pos
  barPos = barPos or themes[config.theme].multibar_Pos
  overtimePos = overtimePos or themes[config.theme].multibar_LeftoverTime_Pos

  local scale = themes[config.theme].healthbar_frame_Scale * (stack.gfxScale / 3)

  GraphicsUtil.draw(themes[config.theme].images.healthbarFrames.absolute[stack.which],
                    math.floor((stack.frameOriginX + stack.panelOriginXOffset + framePos[1] / 3) * stack.gfxScale),
                    stack.frameOriginY * stack.gfxScale,
                    0,
                    scale,
                    scale)

  local multiBarFrameCount = stack.multiBarFrameCount
  local multiBarMaxHeight = 589 * (stack.gfxScale / 3) * themes[config.theme].multibar_Scale
  local bottomOffset = 0

  scale = themes[config.theme].multibar_Scale
  local healthHeight = (stack.health / multiBarFrameCount) * multiBarMaxHeight
  self:drawBar(stack, themes[config.theme].images.IMG_healthbar, stack.healthQuad, barPos, healthHeight, 0, 0, scale)

  bottomOffset = healthHeight

  local stopHeight = 0
  local preStopHeight = 0

  if shake_time > 0 and shake_time > (stop_time + stack.pre_stop_time) then
    -- shake is only drawn if it is greater than prestop + stop
    -- shake is always guaranteed to fit
    local shakeHeight = (shake_time / multiBarFrameCount) * multiBarMaxHeight
    self:drawBar(stack, themes[config.theme].images.IMG_multibar_shake_bar, stack.multi_shakeQuad, barPos, shakeHeight, bottomOffset, 0, scale)
  else
    -- stop/prestop are only drawn if greater than shake
    if stop_time > 0 then
      stopHeight = math.min(stop_time, multiBarFrameCount - stack.health) / multiBarFrameCount * multiBarMaxHeight
      self:drawBar(stack, themes[config.theme].images.IMG_multibar_stop_bar, stack.multi_stopQuad, barPos, stopHeight, bottomOffset, 0, scale)

      bottomOffset = bottomOffset + stopHeight
    end
    if stack.pre_stop_time and stack.pre_stop_time > 0 then
      local totalInvincibility = stack.health + stack.stop_time + stack.pre_stop_time
      local remainingSeconds = 0
      if totalInvincibility > multiBarFrameCount then
        -- total invincibility exceeds what the multibar can display -> fill only the remaining space with prestop
        preStopHeight = (1 - (stack.health + stop_time) / multiBarFrameCount) * multiBarMaxHeight
        remainingSeconds = (totalInvincibility - multiBarFrameCount) / 60
      else
        preStopHeight = stack.pre_stop_time / multiBarFrameCount * multiBarMaxHeight
      end

      self:drawBar(stack, themes[config.theme].images.IMG_multibar_prestop_bar, stack.multi_prestopQuad, barPos, preStopHeight, bottomOffset, 0, scale)

      if remainingSeconds > 0 then
        local formattedSeconds = string.format("%." .. themes[config.theme].multibar_LeftoverTime_Decimals .. "f", remainingSeconds)
        local x = math.floor((stack.frameOriginX + stack.panelOriginXOffset + overtimePos[1] / 3) * stack.gfxScale)
        local y = stack.panelOriginY * stack.gfxScale

        local limit = GAME.globalCanvas:getWidth() - x
        local alignment = "right"
        limit = x - GraphicsUtil.getGlobalFont():getWidth(formattedSeconds) / 2
        x = 0
        local fontDelta = 20 - GraphicsUtil.fontSize

        GraphicsUtil.printf(formattedSeconds, x, y, limit, alignment, nil, nil, fontDelta)
      end
    end
  end
end

function PortraitGame:draw()
  if self.backgroundImage then
    self.backgroundImage:draw()
  end
  if not self.match.isPaused or self.match.renderDuringPause then
    for _, stack in ipairs(self.match.stacks) do
      stack:render()
      -- don't render stacks that only have an attack engine
      if stack.is_local and stack.player.human and stack.inputMethod == "touch" then
        self:drawMultibar(stack)
      end

      if stack.garbageTarget then --and stack.garbageTarget.is_local and stack.garbageTarget.inputMethod == "touch" then
        Telegraph:render(stack, stack.garbageTarget)
      end
    end
  end

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

  if self.match.isPaused then
    self.match:draw_pause()
  end
  self.uiRoot:draw()
end

function PortraitGame:onMatchEnded(match)
  -- recreate the global canvas in landscape dimensions
  GAME.globalCanvas = love.graphics.newCanvas(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT, {dpiscale=GAME:newCanvasSnappedScale()})
  -- flip the window dimensions to landscape
  local width, height, _ = love.window.getMode()
  if love.system.getOS() == "Android" then
    love.window.updateMode(height, width)
    love.window.setFullscreen(false)
  elseif DEBUG_ENABLED then
    GAME:updateCanvasPositionAndScale(width, height)
  end
  for _, player in ipairs(match.players) do
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