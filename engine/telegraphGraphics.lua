local logger = require("logger")

local TELEGRAPH_HEIGHT = 16
local TELEGRAPH_PADDING = 2 -- vertical space between telegraph and stack
local TELEGRAPH_BLOCK_WIDTH = 26
local TELEGRAPH_ATTACK_MAX_SPEED = 8 -- fastest an attack can travel toward the telegraph per frame
-- The telegraph_attack_animation below refers the little loop shape attacks make before they start traveling toward the target.
local TELEGRAPH_ATTACK_ANIMATION_SPEED = {4, 4, 4, 4, 4, 2, 2, 2, 2, 1, 1, 1, 1, .5, .5, .5, .5, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 8}
-- the following are angles out of 64, 0 being right, 32 being left, 16 being down, and 48 being up.
local TELEGRAPH_ATTACK_ANIMATION_ANGLES = {}
-- [1] for attacks where the destination is right of the origin

TELEGRAPH_ATTACK_ANIMATION_ANGLES[1] = {}
for i = 24, 24 + #TELEGRAPH_ATTACK_ANIMATION_SPEED - 1 do
  TELEGRAPH_ATTACK_ANIMATION_ANGLES[1][#TELEGRAPH_ATTACK_ANIMATION_ANGLES[1] + 1] = i % 64
end
-- [-1] for attacks where the destination is left of the origin
TELEGRAPH_ATTACK_ANIMATION_ANGLES[-1] = {}
local leftward_animation_angle = 8
while #TELEGRAPH_ATTACK_ANIMATION_ANGLES[-1] <= #TELEGRAPH_ATTACK_ANIMATION_SPEED do
  TELEGRAPH_ATTACK_ANIMATION_ANGLES[-1][#TELEGRAPH_ATTACK_ANIMATION_ANGLES[-1] + 1] = leftward_animation_angle
  leftward_animation_angle = leftward_animation_angle - 1
  if leftward_animation_angle < 0 then
    leftward_animation_angle = 64
  end
end

local TELEGRAPH_ATTACK_ANIMATION = {}
TELEGRAPH_ATTACK_ANIMATION[1] = {}
local leftward_or_rightward = {-1, 1}
for k, animation in ipairs(leftward_or_rightward) do
  TELEGRAPH_ATTACK_ANIMATION[animation] = {}
  for frame = 1, #TELEGRAPH_ATTACK_ANIMATION_SPEED do
    local distance = TELEGRAPH_ATTACK_ANIMATION_SPEED[frame]
    local angle = TELEGRAPH_ATTACK_ANIMATION_ANGLES[animation][frame] / 64

    --[[ use trigonometry to find the change in x and the change in y, given the hypotenuse (telegraph_attack_animation_speed) and the angle we should be traveling (2*math.pi*telegraph_attack_animation_angles[left_or_right][frame]/64)
                
                I think:              
                change in y will be hypotenuse*sin angle
                change in x will be hypotenuse*cos angle
                --]]

    TELEGRAPH_ATTACK_ANIMATION[animation][frame] = {}
    TELEGRAPH_ATTACK_ANIMATION[animation][frame].dx = distance * math.cos(angle * 2 * math.pi)
    TELEGRAPH_ATTACK_ANIMATION[animation][frame].dy = distance * math.sin(angle * 2 * math.pi)
  end
end


TelegraphGraphics = class(function(self, telegraph)
  self.telegraph = telegraph
  self.sender = telegraph.sender
  self.receiver = telegraph.owner
  self:updatePosition()
  self:preloadGraphics()
  -- some constant used for drawing
  self.attackStartFrame = 1
end)

function TelegraphGraphics:updatePosition()
  self.posX = self.telegraph.owner.pos_x - 4
  self.posY = self.telegraph.owner.pos_y - 4 - TELEGRAPH_HEIGHT - TELEGRAPH_PADDING
end

function TelegraphGraphics:preloadGraphics()
  if config.renderAttacks or config.renderTelegraph then
    character_loader_load(self.sender.character)
    character_loader_wait()
    local telegraphImages = characters[self.sender.character].telegraph_garbage_images

    self.gfx = {}
    self.gfx.attack = {}
    self.gfx.attack.image = telegraphImages["attack"]
    self.gfx.attack.width, self.gfx.attack.height = self.gfx.attack.image:getDimensions()
    self.gfx.attack.scale = 16 / math.max(self.gfx.attack.width, self.gfx.attack.height)
    if config.renderTelegraph then
      -- metal
      self.gfx.telegraph = {}
      self.gfx.telegraph.metal = {}
      self.gfx.telegraph.metal.image = telegraphImages["metal"]
      local metalWidth, metalHeight = self.gfx.telegraph.metal.image:getDimensions()
      self.gfx.telegraph.metal.xScale = 24 / metalWidth
      self.gfx.telegraph.metal.yScale = 16 / metalHeight

      -- chain garbage
      self.gfx.telegraph.chain = {}
      for garbageHeight = 1, 14 do
        self.gfx.telegraph.chain[garbageHeight] = {}
        self.gfx.telegraph.chain[garbageHeight].image = telegraphImages[garbageHeight][6]
        local imageWidth, imageHeight = self.gfx.telegraph.chain[garbageHeight].image:getDimensions()
        self.gfx.telegraph.chain[garbageHeight].xScale = 24 / imageWidth
        self.gfx.telegraph.chain[garbageHeight].yScale = 16 / imageHeight
      end

      -- combo garbage
      self.gfx.telegraph.combo = {}
      for garbageWidth = 1, 6 do
        self.gfx.telegraph.combo[garbageWidth] = {}
        self.gfx.telegraph.combo[garbageWidth].image = telegraphImages[1][garbageWidth]
        local imageWidth, imageHeight = self.gfx.telegraph.combo[garbageWidth].image:getDimensions()
        self.gfx.telegraph.combo[garbageWidth].xScale = 24 / imageWidth
        self.gfx.telegraph.combo[garbageWidth].yScale = 16 / imageHeight
      end
    end
  end
end

function TelegraphGraphics:telegraphRenderXPosition(index)

  local stackWidth = math.floor(self.receiver.canvas:getWidth() / GFX_SCALE)
  local increment = -TELEGRAPH_BLOCK_WIDTH * self.receiver.mirror_x

  local result = self.posX
  if self.receiver.which == 1 then
    result = result + stackWidth + increment
  end

  result = result + (increment * index)

  return result
end

function TelegraphGraphics:telegraphLoopAttackPosition(garbage, attackAge)

  local resultX, resultY = garbage.xOrigin, garbage.yOrigin

  if attackAge > self.attackStartFrame + #TELEGRAPH_ATTACK_ANIMATION_SPEED then
    attackAge = self.attackStartFrame + #TELEGRAPH_ATTACK_ANIMATION_SPEED
  end

  -- We can't guarantee every frame was rendered, so we must calculate the exact location regardless of how many frames happened.
  -- TODO make this more performant?
  for frame = 1, attackAge - self.attackStartFrame do
    resultX = resultX + TELEGRAPH_ATTACK_ANIMATION[garbage.direction][frame].dx
    resultY = resultY + TELEGRAPH_ATTACK_ANIMATION[garbage.direction][frame].dy
  end

  return resultX, resultY
end

function TelegraphGraphics:renderAttacks()
  local telegraph = self.telegraph
  local sender = telegraph.sender

  for timeAttackInteracts, attacksThisFrame in pairs(telegraph.attacks) do
    local attackAge = telegraph.sender.CLOCK - timeAttackInteracts
    if attackAge <= self.attackStartFrame then
      -- don't draw anything yet, card animation is still in progress.
    elseif attackAge >= GARBAGE_TRANSIT_TIME then
      -- Attack is done, remove.
      telegraph.attacks[timeAttackInteracts] = nil
    else
      for _, attack in ipairs(attacksThisFrame) do
        for _, garbage in ipairs(attack.garbageToSend) do
          garbage.xDestination = self:telegraphRenderXPosition(
                                            telegraph.garbageQueue:getGarbageIndex(garbage)) +
                                            (TELEGRAPH_BLOCK_WIDTH / 2) - ((TELEGRAPH_BLOCK_WIDTH / self.gfx.attack.width) / 2)
          garbage.yDestination = garbage.yDestination or (self.posY - TELEGRAPH_PADDING)

          if not garbage.xOrigin or not garbage.yOrigin then
            garbage.xOrigin = (attack.originColumn - 1) * 16 + sender.pos_x
            garbage.yOrigin = (11 - attack.originRow) * 16 + sender.pos_y +
                                         sender.displacement - card_animation[#card_animation]
            garbage.x = garbage.xOrigin
            garbage.y = garbage.yOrigin
            garbage.direction = garbage.direction or math.sign(garbage.xDestination - garbage.xOrigin) -- should give -1 for left, or 1 for right
          end

          if attackAge <= self.attackStartFrame + #TELEGRAPH_ATTACK_ANIMATION_SPEED then
            -- draw telegraph attack animation, little loop down and to the side of origin.

            -- We can't gaurantee every frame was rendered, so we must calculate the exact location regardless of how many frames happened.
            -- TODO make this more performant?
            garbage.x, garbage.y = self:telegraphLoopAttackPosition(garbage, attackAge)

            draw(self.gfx.attack.image, garbage.x, garbage.y, 0, self.gfx.attack.scale, self.gfx.attack.scale)
          else
            -- move toward destination

            local loopX, loopY = self:telegraphLoopAttackPosition(garbage, attackAge)
            local framesHappened = attackAge - (self.attackStartFrame + #TELEGRAPH_ATTACK_ANIMATION_SPEED)
            local totalFrames = GARBAGE_TRANSIT_TIME - (self.attackStartFrame + #TELEGRAPH_ATTACK_ANIMATION_SPEED)
            local percent = framesHappened / totalFrames

            garbage.x = loopX + percent * (garbage.xDestination - loopX)
            garbage.y = loopY + percent * (garbage.yDestination - loopY)

            draw(self.gfx.attack.image, garbage.x, garbage.y, 0, self.gfx.attack.scale, self.gfx.attack.scale)
          end
        end
      end
    end
  end
end

function TelegraphGraphics:renderTelegraph()
  local telegraph = self.telegraph
  local sender = telegraph.sender

    -- Render if we are "currently chaining" for debug purposes
  if config.debug_mode and telegraph.senderCurrentlyChaining then
    draw(self.gfx.attack.image, self:telegraphRenderXPosition(-1), self.posY, 0, self.gfx.attack.scale, self.gfx.attack.scale)
  end

  -- then draw the telegraph's garbage queue, leaving an empty space until such a time as the attack arrives (earned_frame-GARBAGE_TRANSIT_TIME)
  local garbageQueue = telegraph.garbageQueue:makeCopy()
  local garbage = garbageQueue:pop()
  local drawY = self.posY
  local drewChain = false
  local attackAnimationLength = GARBAGE_TRANSIT_TIME
  if not config.renderAttacks then
    attackAnimationLength = 0
  end

  local currentIndex = 0
  while garbage do
    if sender.CLOCK - garbage.timeAttackInteracts >= attackAnimationLength then
      local drawX = self:telegraphRenderXPosition(currentIndex)
      if garbage.isMetal then
        local metalGfx = self.gfx.telegraph.metal
        draw(metalGfx.image, drawX, drawY, 0, metalGfx.xScale, metalGfx.yScale)
      else
        local height = math.min(garbage.height, 14)
        -- ignore whether it was a chain or not and determine telegraph image solely based on garbage height
        if height > 1 then
          local chainGfx = self.gfx.telegraph.chain[height]
          draw(chainGfx.image, drawX, drawY, 0, chainGfx.xScale, chainGfx.yScale)
        else
          local comboGfx = self.gfx.telegraph.combo[garbage.width]
          draw(comboGfx.image, drawX, drawY, 0, comboGfx.xScale, comboGfx.yScale)
        end
      end
      drewChain = drewChain or garbage.isChain

      -- Render the stop times above blocks for debug purposes
      if config.debug_mode then
        local stopperTime = nil

        if garbage.isChain then
          stopperTime = telegraph.stoppers.chain[telegraph.garbageQueue.chainGarbage.first]
          if stopperTime and garbage.finalized then
            stopperTime = stopperTime .. " F"
          end
        else
          if garbage.isMetal then
            stopperTime = telegraph.stoppers.metal
          else
            stopperTime = telegraph.stoppers.combo[garbage.width]
          end
        end

        if stopperTime then
          gprintf(stopperTime, drawX * GFX_SCALE, (drawY - 8) * GFX_SCALE, 70, "center", nil, 1, LARGE_FONT)
        end
      end

    end
    garbage = garbageQueue:pop()
    currentIndex = currentIndex + 1
  end

  if not drewChain and telegraph.garbageQueue.ghostChain then
    local drawX = self:telegraphRenderXPosition(0)
    -- local draw_y = self.posY -- already defined like this further above
    local height = math.min(telegraph.garbageQueue.ghostChain, 14)
    local chainGfx = self.gfx.telegraph.chain[height]
    draw(chainGfx.image, drawX, drawY, 0, chainGfx.xScale, chainGfx.yScale)

    -- Render a "G" for ghost
    if config.debug_mode then
      gprintf("G", drawX * GFX_SCALE, (drawY - 8) * GFX_SCALE, 70, "center", nil, 1, LARGE_FONT)
    end
  end
end

function TelegraphGraphics:render()
  if config.renderAttacks then
    self:renderAttacks()
  end

  if config.renderTelegraph then
    self:renderTelegraph()
  end
end