local logger = require("logger")

-- https://docs.google.com/spreadsheets/d/1VedRmzk6MfVNFv74AopMOaWMsehL_qrwQYOS-uFrejo/pubhtml#

local combo_to_damage = {0, 0, 0, 128, 170, 256, 304, 352, 400, 448, 496, 544, 768, 1024, 1280, 1536, 1792, 2048, 2304, 2560, 2816, 3072, 3328, 3584, 3840, 4096}

local chain_to_damage = {0, 256, 512, 768, 1024, 1280, 1536, 1792, 2048, 2240, 2432, 2624, 2816, 3008, 3200, 3392, 3584, 3584, 3584, 4096}

-- (Does not include combo damage, combo damage is seperate)
local metal_to_damage = {0, 0, 320, 640, 960, 1280, 1600, 1920, 2240, 2560, 2880, 3200, 3520, 3840, 4096, 3584, 3840, 4096}

Health =
  class(
  function(self, starting_health)
    self.health = starting_health
    self.maxHealth = starting_health
  end
)

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

function Health.game_ended(self)
  return self.health <= 0
end


function Health.render(self)

  local healthQuadBoss = love.graphics.newQuad(0, 0, themes[config.theme].images.IMG_healthbar:getWidth(), themes[config.theme].images.IMG_healthbar:getHeight(), themes[config.theme].images.IMG_healthbar:getWidth(), themes[config.theme].images.IMG_healthbar:getHeight())

  -- Healthbar
  local healthbar = math.max(0, self.health) * (themes[config.theme].images.IMG_healthbar:getHeight() / self.maxHealth)
  local width = themes[config.theme].images.IMG_healthbar:getWidth()
  local height = themes[config.theme].images.IMG_healthbar:getHeight()
  healthQuadBoss:setViewport(0,height - healthbar, width, healthbar)
  qdraw(themes[config.theme].images.IMG_healthbar, healthQuadBoss, 260, 36 + (height - healthbar), 
  themes[config.theme].healthbar_Rotate,
   themes[config.theme].healthbar_Scale,
    themes[config.theme].healthbar_Scale, 0, 0, 1)

end