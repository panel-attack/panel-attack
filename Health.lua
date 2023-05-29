local logger = require("logger")

local HEALTH_BAR_WIDTH = 50

Health =
  class(
  function(self, secondsToppedOutToLose, lineClearGPM, height, riseLevel)
    self.secondsToppedOutToLose = secondsToppedOutToLose -- Number of seconds currently remaining of being "topped" out before we are defeated.
    self.maxSecondsToppedOutToLose = secondsToppedOutToLose -- Starting value of secondsToppedOutToLose
    self.lineClearRate = lineClearGPM / 60 -- How many "lines" we clear per second. Essentially how fast we recover.
    self.currentLines = 0 -- The current number of "lines" simulated
    self.height = height -- How many "lines" need to be accumulated before we are "topped" out.
    self.lastWasFourCombo = false -- Tracks if the last combo was a +4. If two +4s hit in a row, it only counts as 1 "line"
    self.clock = 0 -- Current clock time, this should match the opponent
    self.riseLevel = riseLevel -- The current level used to simulate "rise speed"
    self.currentRiseSpeed = level_to_starting_speed[self.riseLevel] -- rise speed is just like the normal game for now, lines are added faster the longer the match goes
  end
)

function Health:run()

  -- Increment rise speed if needed
  if self.clock > 0 and self.clock % (15 * 60) == 0 then
    self.currentRiseSpeed = math.min(self.currentRiseSpeed + 1, 99)
  end

  local risenLines = 1.0 / (speed_to_rise_time[self.currentRiseSpeed] * 16)
  self.currentLines = self.currentLines + risenLines

  -- Harder to survive over time, simulating "stamina"
  local staminaPercent = math.max(0.5, 1 - ((self.clock / 60) * (0.01 / 10)))
  local decrementLines = (self.lineClearRate * (1/60.0)) * staminaPercent
  self.currentLines = math.max(0, self.currentLines - decrementLines)
  if self.currentLines >= self.height then
    self.secondsToppedOutToLose = math.max(0, self.secondsToppedOutToLose - (1/60.0))
  end
  self.clock = self.clock + 1
end

function Health:receiveGarbage(frameToReceive, garbageList)
  for k,v in pairs(garbageList) do
    local width, height, metal, from_chain, finalized = unpack(v)
    if width and height then
      local countGarbage = true
      if not metal and not from_chain and width == 3 then
        if self.lastWasFourCombo then
          -- Two four combos in a row, don't count an extra line
          self.lastWasFourCombo = false
          countGarbage = false
        else
          -- First four combo
          self.lastWasFourCombo = true
        end
      else
        -- non four combo
        self.lastWasFourCombo = false
      end

      if countGarbage then
        self.currentLines = self.currentLines + height
      end
    end
  end
end


function Health:isFullyDepleted()
  return self.secondsToppedOutToLose <= 0
end

function Health:renderPartialScaledImage(image, x, y, maxWidth, maxHeight, percentageX, percentageY)
  local width = image:getWidth()
  local height = image:getHeight()
  local partialWidth = width * percentageX
  local partialHeight = height * percentageY
  local quad = love.graphics.newQuad(width - partialWidth, height - partialHeight, partialWidth, partialHeight, width, height)
  
  local scaleX = maxWidth / width
  local scaleY = maxHeight / height
  
  local xPosition = x + (1 - percentageX) * maxWidth
  local yPosition = y + (1 - percentageY) * maxHeight
  love.graphics.draw(image, quad, xPosition, yPosition, 0, scaleX, scaleY)
end

function Health:renderHealth(xPosition)
  local percentage = math.max(0, self.secondsToppedOutToLose) / self.maxSecondsToppedOutToLose
  self:renderPartialScaledImage(themes[config.theme].images.IMG_healthbar, xPosition, 110, HEALTH_BAR_WIDTH, 590, 1, percentage)
end

function Health:renderTopOut(xPosition)
  local percentage = math.max(0, self.currentLines) / self.height
  local x = xPosition + HEALTH_BAR_WIDTH
  local y = 110
  self:renderPartialScaledImage(themes[config.theme].images.IMG_multibar_shake_bar, x, 110, HEALTH_BAR_WIDTH, 590, 1, percentage)

  local height = 4
  local grey = 0.8
  local alpha = 1
  grectangle_color("fill", x / GFX_SCALE, y / GFX_SCALE, HEALTH_BAR_WIDTH / GFX_SCALE, height / GFX_SCALE, grey, grey, grey, alpha)
end

function Health:render(xPosition)

  self:renderHealth(xPosition)
  self:renderTopOut(xPosition)

end