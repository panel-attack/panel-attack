local class = require("common.lib.class")
local logger = require("common.lib.logger")
local consts = require("common.engine.consts")
-- TODO: move graphics related functionality to client
local GraphicsUtil = require("client.src.graphics.graphics_util")
local GFX_SCALE = consts.GFX_SCALE

local TELEGRAPH_HEIGHT = 16
local TELEGRAPH_PADDING = 2 --vertical space between telegraph and stack
local TELEGRAPH_BLOCK_WIDTH = 26

local clone_pool = {}

-- Sender is the sender of these attacks, must implement clock, frameOriginX, frameOriginY, and character
Telegraph = class(function(self, sender)

  -- A sender can be anything that
  self.sender = sender
  -- has some coordinates to originate the attack animation from
  assert(sender.frameOriginX ~= nil, "telegraph sender invalid")
  assert(sender.frameOriginY ~= nil, "telegraph sender invalid")
  -- has a clock to figure out how far the attacks should have animated relative to when it was sent
  -- (and also that non-cheating senders can only send attacks on the frame they're on)
  assert(sender.clock ~= nil, "telegraph sender invalid")
  -- has a character to source the telegraph images above the stack from
  assert(sender.character ~= nil, "telegraph sender invalid")
  -- has a panel origin to realistically offset coordinates
  assert(sender.panelOriginX ~= nil, "telegraph sender invalid")
  assert(sender.panelOriginY ~= nil, "telegraph sender invalid")
end)

--The telegraph_attack_animation below refers the little loop shape attacks make before they start traveling toward the target.
local telegraph_attack_animation_speed = {
    4,4,4,4,4,2,2,2,2,1,
    1,1,1,.5,.5,.5,.5,1,1,1,
    1,2,2,2,2,4,4,4,4,8}

--the following are angles out of 64, 0 being right, 32 being left, 16 being down, and 48 being up.
local telegraph_attack_animation_angles = {}
--[1] for attacks where the destination is right of the origin

telegraph_attack_animation_angles[1] = {}
for i=24,24+#telegraph_attack_animation_speed-1 do
  telegraph_attack_animation_angles[1][#telegraph_attack_animation_angles[1]+1] = i%64
end
--[-1] for attacks where the destination is left of the origin
telegraph_attack_animation_angles[-1] = {}
local leftward_animation_angle = 8
while #telegraph_attack_animation_angles[-1] <= #telegraph_attack_animation_speed do
  telegraph_attack_animation_angles[-1][#telegraph_attack_animation_angles[-1]+1] = leftward_animation_angle
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
  for frame=1,#telegraph_attack_animation_speed do
    local distance = telegraph_attack_animation_speed[frame]
    local angle = telegraph_attack_animation_angles[animation][frame]/64
    
                --[[ use trigonometry to find the change in x and the change in y, given the hypotenuse (telegraph_attack_animation_speed) and the angle we should be traveling (2*math.pi*telegraph_attack_animation_angles[left_or_right][frame]/64)
                
                I think:              
                change in y will be hypotenuse*sin angle
                change in x will be hypotenuse*cos angle
                --]]
    
    telegraph_attack_animation[animation][frame] = {}
    telegraph_attack_animation[animation][frame].dx = distance * math.cos(angle*2*math.pi)
    telegraph_attack_animation[animation][frame].dy = distance * math.sin(angle*2*math.pi)
  end
end

function Telegraph:updatePositionForGarbageTarget(newGarbageTarget)
  self.stackCanvasWidth = newGarbageTarget:stackCanvasWidth()
  self.mirror_x = newGarbageTarget.mirror_x
  self.originX = newGarbageTarget.frameOriginX
  self.originY = newGarbageTarget.frameOriginY - TELEGRAPH_HEIGHT - TELEGRAPH_PADDING
end

function Telegraph:telegraphRenderXPosition(index)

  local increment = -TELEGRAPH_BLOCK_WIDTH * self.mirror_x

  local result = self.originX
  if self.mirror_x == 1 then
    result = result + self.stackCanvasWidth / GFX_SCALE + increment
  end

  result = result + (increment * index)

  return result
end

function Telegraph:attackAnimationStartFrame()
  -- In games PA is inspired by the attack animation only happens after the card_animation
  -- In PA garbage is removed from telegraph early in order to afford the 1 second desync tolerance for online play
  -- to compensate, both attacks and telegraph are shown earlier so they are shown long enough and early enough
  -- their attacks being rendered immediately produces a decent compromise on visuals
  return 1
end

function Telegraph:attackAnimationEndFrame()
  return GARBAGE_TRANSIT_TIME
end

function Telegraph:telegraphLoopAttackPosition(attack, garbage_block, frames_since_earned)

  local resultX, resultY = attack.origin_x, attack.origin_y

  if frames_since_earned > self:attackAnimationStartFrame() + #telegraph_attack_animation_speed then
    frames_since_earned = self:attackAnimationStartFrame() + #telegraph_attack_animation_speed
  end

  -- We can't gaurantee every frame was rendered, so we must calculate the exact location regardless of how many frames happened.
  -- TODO make this more performant?
  for frame=1, frames_since_earned - self:attackAnimationStartFrame() do
    resultX = resultX + telegraph_attack_animation[attack.direction][frame].dx
    resultY = resultY + telegraph_attack_animation[attack.direction][frame].dy
  end

  return resultX, resultY
end

function Telegraph:renderAttacks()
  local character = characters[self.sender.character]
  local orig_atk_w, orig_atk_h = character.telegraph_garbage_images["attack"]:getDimensions()
  local atk_scale = 16 / math.max(orig_atk_w, orig_atk_h) -- keep image ratio

  for timeAttackInteracts, attacks_this_frame in pairs(self.attacks) do
    local frames_since_earned = self.sender.clock - timeAttackInteracts
    if frames_since_earned < self:attackAnimationStartFrame() then
      --don't draw anything yet, card animation is still in progress.
    elseif frames_since_earned >= self:attackAnimationEndFrame() then
      --Attack is done, remove.
      self.attacks[timeAttackInteracts] = nil
    else
      for _, attack in ipairs(attacks_this_frame) do
        for _k, garbage_block in ipairs(attack.stuff_to_send) do
          garbage_block.destination_x = self:telegraphRenderXPosition(self.garbage_queue:get_idx_of_garbage(unpack(garbage_block))) + (TELEGRAPH_BLOCK_WIDTH / 2) - ((TELEGRAPH_BLOCK_WIDTH / orig_atk_w) / 2)
          garbage_block.destination_y = garbage_block.destination_y or (self.originY - TELEGRAPH_PADDING)

          if not attack.origin_x or not attack.origin_y then
            attack.origin_x = (attack.attackDrawColumn-1) * 16 + self.sender.panelOriginX
            attack.origin_y = (11-attack.attackDrawRow) * 16 + self.sender.panelOriginY + (self.sender.displacement or 0) - (consts.CARD_ANIMATION[frames_since_earned] or 0)
            attack.direction = math.sign(garbage_block.destination_x - attack.origin_x) --should give -1 for left, or 1 for right
          end

          if self.sender.opacityForFrame then
            GraphicsUtil.setColor(1, 1, 1, self.sender:opacityForFrame(frames_since_earned, 1, 8))
          end

          if frames_since_earned <= self:attackAnimationStartFrame() + #telegraph_attack_animation_speed then
            --draw telegraph attack animation, little loop down and to the side of origin.

            -- We can't gaurantee every frame was rendered, so we must calculate the exact location regardless of how many frames happened.
            -- TODO make this more performant?
            local garbageBlockX, garbageBlockY = self:telegraphLoopAttackPosition(attack, garbage_block, frames_since_earned)

            GraphicsUtil.drawGfxScaled(character.telegraph_garbage_images["attack"], garbageBlockX, garbageBlockY, 0, atk_scale, atk_scale)
          else
            --move toward destination

            local loopX, loopY = self:telegraphLoopAttackPosition(attack, garbage_block, frames_since_earned)
            local framesHappened = frames_since_earned - (self:attackAnimationStartFrame() + #telegraph_attack_animation_speed)
            local totalFrames = self:attackAnimationEndFrame() - (self:attackAnimationStartFrame() + #telegraph_attack_animation_speed)
            local percent =  framesHappened / totalFrames

            local garbageBlockX = loopX + percent * (garbage_block.destination_x - loopX)
            local garbageBlockY = loopY + percent * (garbage_block.destination_y - loopY)

            GraphicsUtil.drawGfxScaled(character.telegraph_garbage_images["attack"], garbageBlockX, garbageBlockY, 0, atk_scale, atk_scale)
          end

          GraphicsUtil.setColor(1, 1, 1, 1)
        end
      end
    end
  end
end

local iconHeight = 16
local iconWidth = 24

function Telegraph:renderStagedGarbageIcons()
  local character = characters[self.sender.character]
  local y = self.originY

  for i = #self.sender.outgoingGarbage.stagedGarbage, 1, -1 do
    local garbage = self.sender.outgoingGarbage.stagedGarbage[i]
    local x = self:telegraphRenderXPosition(math.abs(i - #self.sender.outgoingGarbage.stagedGarbage))
    local image
    if garbage.isChain then
      image = character.telegraph_garbage_images[garbage.height][6]
    elseif garbage.isMetal then
      image = character.telegraph_garbage_images["metal"]
    else
      image = character.telegraph_garbage_images[1][garbage.width]
    end

    local width, height = image:getDimensions()
    local xScale = iconWidth / width
    local yScale = iconHeight / height

    GraphicsUtil.drawGfxScaled(image, x, y, 0, xScale, yScale)
  end
end

function Telegraph:render()
  if false then--config.renderAttacks then
    self:renderAttacks()
  end

  if config.renderTelegraph then
    self:renderStagedGarbageIcons()
  end
end

return Telegraph