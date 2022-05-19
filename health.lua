local logger = require("logger")

-- https://docs.google.com/spreadsheets/d/1VedRmzk6MfVNFv74AopMOaWMsehL_qrwQYOS-uFrejo/pubhtml#

local combo_to_damage = {0, 0, 0, 128, 170, 256, 304, 352, 400, 448, 496, 544, 768, 1024, 1280, 1536, 1792, 2048, 2304, 2560, 2816, 3072, 3328, 3584, 3840, 4096}

local chain_to_damage = {0, 256, 512, 768, 1024, 1280, 1536, 1792, 2048, 2240, 2432, 2624, 2816, 3008, 3200, 3392, 3584, 3584, 3584, 4096}

-- (Does not include combo damage, combo damage is seperate)
local metal_to_damage = {0, 0, 320, 640, 960, 1280, 1600, 1920, 2240, 2560, 2880, 3200, 3520, 3840, 4096, 3584, 3840, 4096}

local barWidth = 50

Health =
  class(
  function(self, secondsToppedOutToLose, lineClearGPM, height, positionX, positionY, mirror)
    self.secondsToppedOutToLose = secondsToppedOutToLose
    self.maxSecondsToppedOutToLose = secondsToppedOutToLose
    self.lineClearRate = lineClearGPM / 60
    self.currentLines = 0
    self.lastWasFourCombo = false
    self.height = height
    self.pos_x = positionX
    self.pos_y = positionY
    self.mirror_x = mirror
  end
)

function Health:run()
  local decrementLines = (self.lineClearRate * (1/60.0))
  self.currentLines = math.max(0, self.currentLines - decrementLines)
  if self.currentLines >= self.height then
    self.secondsToppedOutToLose = math.max(0, self.secondsToppedOutToLose - (1/60.0))
  end
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

function Health.take_combo_damage(self, combo_size)
  if combo_size > 3 then
    self.health = self.health - combo_to_damage[combo_size]
    logger.info("New health is " .. self.health)
  end
end

function Health.take_chain_damage(self, chain_size)
  if chain_size > 1 then
    self.health = self.health - chain_to_damage[chain_size]
    logger.info("New health is " .. self.health)
  end
end

function Health.take_metal_damage(self, metal_combo_size)
  if metal_combo_size > 2 then
    self.health = self.health - metal_to_damage[metal_combo_size] 
    logger.info("New health is " .. self.health)
  end
end

function Health:game_ended()
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
  gfx_q:push({love.graphics.draw, {image, quad, xPosition, yPosition, 0, scaleX, scaleY}})
end

function Health:renderHealth()
  local percentage = math.max(0, self.secondsToppedOutToLose) / self.maxSecondsToppedOutToLose
  self:renderPartialScaledImage(themes[config.theme].images.IMG_healthbar, 760, 110, barWidth, 590, 1, percentage)
end

function Health:renderTopOut()
  local percentage = math.max(0, self.currentLines) / self.height
  local x = 860
  local y = 110
  self:renderPartialScaledImage(themes[config.theme].images.IMG_shake_bar, 860, 110, barWidth, 590, 1, percentage)

  local height = 4
  local grey = 0.8
  local alpha = 1
  grectangle_color("fill", x / GFX_SCALE, y / GFX_SCALE, barWidth / GFX_SCALE, height / GFX_SCALE, grey, grey, grey, alpha)
end

function Health.render(self)

  self:renderHealth()
  self:renderTopOut()


end