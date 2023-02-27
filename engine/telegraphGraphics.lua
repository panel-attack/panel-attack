local logger = require("logger")

local TELEGRAPH_HEIGHT = 16
local TELEGRAPH_PADDING = 2 -- vertical space between telegraph and stack
local TELEGRAPH_BLOCK_WIDTH = 26
local TELEGRAPH_ATTACK_MAX_SPEED = 8 -- fastest an attack can travel toward the telegraph per frame

TelegraphGraphics = class(function(self, telegraph)
  self.telegraph = telegraph
  self.sender = telegraph.sender
  self.receiver = telegraph.owner
  self:updatePosition()
  self:preloadGraphics()
end)

-- The telegraph_attack_animation below refers the little loop shape attacks make before they start traveling toward the target.
local telegraph_attack_animation_speed = {4, 4, 4, 4, 4, 2, 2, 2, 2, 1, 1, 1, 1, .5, .5, .5, .5, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 8}

-- the following are angles out of 64, 0 being right, 32 being left, 16 being down, and 48 being up.
local telegraph_attack_animation_angles = {}
-- [1] for attacks where the destination is right of the origin

telegraph_attack_animation_angles[1] = {}
for i = 24, 24 + #telegraph_attack_animation_speed - 1 do
  telegraph_attack_animation_angles[1][#telegraph_attack_animation_angles[1] + 1] = i % 64
end
-- [-1] for attacks where the destination is left of the origin
telegraph_attack_animation_angles[-1] = {}
local leftward_animation_angle = 8
while #telegraph_attack_animation_angles[-1] <= #telegraph_attack_animation_speed do
  telegraph_attack_animation_angles[-1][#telegraph_attack_animation_angles[-1] + 1] = leftward_animation_angle
  leftward_animation_angle = leftward_animation_angle - 1
  if leftward_animation_angle < 0 then
    leftward_animation_angle = 64
  end
end

local telegraph_attack_animation = {}
telegraph_attack_animation[1] = {}
local leftward_or_rightward = {-1, 1}
for k, animation in ipairs(leftward_or_rightward) do
  telegraph_attack_animation[animation] = {}
  for frame = 1, #telegraph_attack_animation_speed do
    local distance = telegraph_attack_animation_speed[frame]
    local angle = telegraph_attack_animation_angles[animation][frame] / 64

    --[[ use trigonometry to find the change in x and the change in y, given the hypotenuse (telegraph_attack_animation_speed) and the angle we should be traveling (2*math.pi*telegraph_attack_animation_angles[left_or_right][frame]/64)
                
                I think:              
                change in y will be hypotenuse*sin angle
                change in x will be hypotenuse*cos angle
                --]]

    telegraph_attack_animation[animation][frame] = {}
    telegraph_attack_animation[animation][frame].dx = distance * math.cos(angle * 2 * math.pi)
    telegraph_attack_animation[animation][frame].dy = distance * math.sin(angle * 2 * math.pi)
  end
end

function TelegraphGraphics:updatePosition()
  self.pos_x = self.telegraph.owner.pos_x - 4
  self.pos_y = self.telegraph.owner.pos_y - 4 - TELEGRAPH_HEIGHT - TELEGRAPH_PADDING
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

  local result = self.pos_x
  if self.receiver.which == 1 then
    result = result + stackWidth + increment
  end

  result = result + (increment * index)

  return result
end

function TelegraphGraphics:telegraphLoopAttackPosition(garbage_block, frames_since_earned)

  local resultX, resultY = garbage_block.origin_x, garbage_block.origin_y

  if frames_since_earned > self.telegraph.attackStartFrame + #telegraph_attack_animation_speed then
    frames_since_earned = self.telegraph.attackStartFrame + #telegraph_attack_animation_speed
  end

  -- We can't gaurantee every frame was rendered, so we must calculate the exact location regardless of how many frames happened.
  -- TODO make this more performant?
  for frame = 1, frames_since_earned - self.telegraph.attackStartFrame do
    resultX = resultX + telegraph_attack_animation[garbage_block.direction][frame].dx
    resultY = resultY + telegraph_attack_animation[garbage_block.direction][frame].dy
  end

  return resultX, resultY
end

function TelegraphGraphics:renderAttacks()
  local telegraph = self.telegraph
  local sender = telegraph.sender

  for timeAttackInteracts, attacksThisFrame in pairs(telegraph.attacks) do
    local frames_since_earned = telegraph.sender.CLOCK - timeAttackInteracts
    if frames_since_earned <= telegraph.attackStartFrame then
      -- don't draw anything yet, card animation is still in progress.
    elseif frames_since_earned >= GARBAGE_TRANSIT_TIME then
      -- Attack is done, remove.
      telegraph.attacks[timeAttackInteracts] = nil
    else
      for _, attack in ipairs(attacksThisFrame) do
        for _, garbage_block in ipairs(attack.stuff_to_send) do
          garbage_block.destination_x = self:telegraphRenderXPosition(
                                            telegraph.garbage_queue:get_idx_of_garbage(garbage_block)) +
                                            (TELEGRAPH_BLOCK_WIDTH / 2) - ((TELEGRAPH_BLOCK_WIDTH / self.gfx.attack.width) / 2)
          garbage_block.destination_y = garbage_block.destination_y or (self.pos_y - TELEGRAPH_PADDING)

          if not garbage_block.origin_x or not garbage_block.origin_y then
            garbage_block.origin_x = (attack.origin_col - 1) * 16 + sender.pos_x
            garbage_block.origin_y = (11 - attack.origin_row) * 16 + sender.pos_y +
                                         sender.displacement - card_animation[#card_animation]
            garbage_block.x = garbage_block.origin_x
            garbage_block.y = garbage_block.origin_y
            garbage_block.direction = garbage_block.direction or math.sign(garbage_block.destination_x - garbage_block.origin_x) -- should give -1 for left, or 1 for right
          end

          if frames_since_earned <= telegraph.attackStartFrame + #telegraph_attack_animation_speed then
            -- draw telegraph attack animation, little loop down and to the side of origin.

            -- We can't gaurantee every frame was rendered, so we must calculate the exact location regardless of how many frames happened.
            -- TODO make this more performant?
            garbage_block.x, garbage_block.y = self:telegraphLoopAttackPosition(garbage_block, frames_since_earned)

            draw(self.gfx.attack.image, garbage_block.x, garbage_block.y, 0, self.gfx.attack.scale, self.gfx.attack.scale)
          else
            -- move toward destination

            local loopX, loopY = self:telegraphLoopAttackPosition(garbage_block, frames_since_earned)
            local framesHappened = frames_since_earned - (telegraph.attackStartFrame + #telegraph_attack_animation_speed)
            local totalFrames = GARBAGE_TRANSIT_TIME - (telegraph.attackStartFrame + #telegraph_attack_animation_speed)
            local percent = framesHappened / totalFrames

            garbage_block.x = loopX + percent * (garbage_block.destination_x - loopX)
            garbage_block.y = loopY + percent * (garbage_block.destination_y - loopY)

            draw(self.gfx.attack.image, garbage_block.x, garbage_block.y, 0, self.gfx.attack.scale, self.gfx.attack.scale)
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
    draw(self.gfx.attack.image, self:telegraphRenderXPosition(-1), self.pos_y, 0, self.gfx.attack.scale, self.gfx.attack.scale)
  end

  -- then draw the telegraph's garbage queue, leaving an empty space until such a time as the attack arrives (earned_frame-GARBAGE_TRANSIT_TIME)
  local g_queue_to_draw = telegraph.garbage_queue:makeCopy()
  local current_block = g_queue_to_draw:pop()
  local draw_y = self.pos_y
  local drewChain = false
  local attackAnimationLength = GARBAGE_TRANSIT_TIME
  if not config.renderAttacks then
    attackAnimationLength = 0
  end

  local currentIndex = 0
  while current_block do
    if sender.CLOCK - current_block.timeAttackInteracts >= attackAnimationLength then
      local draw_x = self:telegraphRenderXPosition(currentIndex)
      if current_block.isMetal then
        local metalGfx = self.gfx.telegraph.metal
        draw(metalGfx.image, draw_x, draw_y, 0, metalGfx.xScale, metalGfx.yScale)
      else
        local height = math.min(current_block.height, 14)
        -- ignore whether it was a chain or not and determine telegraph image solely based on garbage height
        if height > 1 then
          local chainGfx = self.gfx.telegraph.chain[height]
          draw(chainGfx.image, draw_x, draw_y, 0, chainGfx.xScale, chainGfx.yScale)
        else
          local comboGfx = self.gfx.telegraph.combo[current_block.width]
          draw(comboGfx.image, draw_x, draw_y, 0, comboGfx.xScale, comboGfx.yScale)
        end
      end
      drewChain = drewChain or current_block.isChain

      -- Render the stop times above blocks for debug purposes
      if config.debug_mode then
        local stopperTime = nil

        if current_block.isChain then
          stopperTime = telegraph.stoppers.chain[telegraph.garbage_queue.chain_garbage.first]
          if stopperTime and current_block.finalized then
            stopperTime = stopperTime .. " F"
          end
        else
          if current_block.isMetal then
            stopperTime = telegraph.stoppers.metal
          else
            stopperTime = telegraph.stoppers.combo[current_block.width]
          end
        end

        if stopperTime then
          gprintf(stopperTime, draw_x * GFX_SCALE, (draw_y - 8) * GFX_SCALE, 70, "center", nil, 1, large_font)
        end
      end

    end
    current_block = g_queue_to_draw:pop()
    currentIndex = currentIndex + 1
  end

  if not drewChain and telegraph.garbage_queue.ghost_chain then
    local draw_x = self:telegraphRenderXPosition(0)
    -- local draw_y = self.pos_y -- already defined like this further above
    local height = math.min(telegraph.garbage_queue.ghost_chain, 14)
    local chainGfx = self.gfx.telegraph.chain[height]
    draw(chainGfx.image, draw_x, draw_y, 0, chainGfx.xScale, chainGfx.yScale)

    -- Render a "G" for ghost
    if config.debug_mode then
      gprintf("G", draw_x * GFX_SCALE, (draw_y - 8) * GFX_SCALE, 70, "center", nil, 1, large_font)
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