local logger = require("logger")
local util = require("util")
local GraphicsUtil = require("graphics_util")
local consts = require("consts")
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

  -- Stores the actual queue of garbages in the telegraph but not queued long enough to exceed the "stoppers"
  self.garbage_queue = GarbageQueue()

  -- Attacks must stay in the telegraph a certain amount of time before they can be sent, we track this with "stoppers"
  --note: keys for stoppers such as self.stoppers.chain[some_key]
  --will be the garbage block's index in the queue , and value will be the frame the stopper expires).
  --keys for self.stoppers.combo[some_key] will be garbage widths, and values will be frame_to_release
  self.stoppers =  {chain = {}, combo = {}, metal = nil}
  
  self.attacks = {} -- A copy of the chains and combos earned used to render the animation of going to the telegraph
  self.senderCurrentlyChaining = false -- Set when we start a new chain, cleared when the sender is done chaining, used to know if we should grow a chain or start a new one, and to know if we are allowed to send the attack since the sender is done.
  -- (typically sending is prevented by garbage chaining)
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

function Telegraph.saveClone(toSave)
  clone_pool[#clone_pool + 1] = toSave
end

function Telegraph.rollbackCopy(source, other)
  if other == nil then
    if #clone_pool == 0 then
      other = Telegraph(source.sender)
    else
      other = clone_pool[#clone_pool]
      clone_pool[#clone_pool] = nil
    end
  end

  other.garbage_queue = source.garbage_queue:makeCopy()
  other.stoppers = deepcpy(source.stoppers)
  if config.renderAttacks then
    other.attacks = deepcpy(source.attacks)
  end
  other.sender = source.sender
  other.originX = source.originX
  other.originY = source.originY
  other.senderCurrentlyChaining = source.senderCurrentlyChaining

  -- We don't want saved copies to hold on to stacks, up to the rollback restore to set these back up.
  other.sender = nil
  return other
end

-- Adds a piece of garbage to the queue
function Telegraph:push(garbage, attackDrawCol, attackDrawRow, frameEarned)
  assert(self.sender ~= nil, "telegraph needs sender set")
  assert(frameEarned == self.sender.clock, "expected sender clock to equal attack")

  -- the attack only starts interacting with the telegraph on the next frame, not the same it was earned
  self:privatePush(garbage, attackDrawCol, attackDrawRow, frameEarned + 1)
end

-- Adds a piece of garbage to the queue
function Telegraph.privatePush(self, garbage, attackDrawColumn, attackDrawRow, timeAttackInteracts)
  local garbageToSend
  if garbage.isChain then
    garbageToSend = self:grow_chain(timeAttackInteracts)
  else
    -- get combo_garbage_widths, n_resulting_metal_garbage
    garbageToSend = self:add_combo_garbage(garbage, timeAttackInteracts)
    garbageToSend = deepcpy(garbageToSend) -- we don't want to use the same object as in the garbage queue so they don't change each other
  end
  if config.renderAttacks then
    if not self.attacks[timeAttackInteracts] then
      self.attacks[timeAttackInteracts] = {}
    end
    self.attacks[timeAttackInteracts][#self.attacks[timeAttackInteracts]+1] =
      {timeAttackInteracts=timeAttackInteracts, attackDrawColumn=attackDrawColumn, attackDrawRow=attackDrawRow, stuff_to_send=garbageToSend}
  end
end

function Telegraph.add_combo_garbage(self, garbage, timeAttackInteracts)
  logger.debug("Telegraph.add_combo_garbage "..(garbage.width or "nil").." "..(garbage.isMetal and "true" or "false"))
  local garbageToSend = {}
  if garbage.isMetal and not self.mergeComboMetalQueue then
    garbageToSend[#garbageToSend+1] = {garbage.width, garbage.height, true, false, timeAttackInteracts = timeAttackInteracts}
    self.stoppers.metal = timeAttackInteracts + GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME
  else
    garbageToSend[#garbageToSend+1] = {garbage.width, garbage.height, garbage.isMetal, garbage.isChain, timeAttackInteracts = timeAttackInteracts}
    self.stoppers.combo[garbage.width] = timeAttackInteracts + GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME
  end
  self.garbage_queue:push(garbageToSend)
  return garbageToSend
end

function Telegraph:chainingEnded(frameEnded)
  -- this being a global reference really sucks here, now that attackEngines live on match
  -- have to take care of that when getting to it
  if GAME.battleRoom and not GAME.battleRoom.trainingModeSettings then
    assert(frameEnded == self.sender.clock, "expected sender clock to equal attack")
  end

  self.senderCurrentlyChaining = false
  local chain = self.garbage_queue.chain_garbage[self.garbage_queue.chain_garbage.last]
  if chain.finalized then
    logger.error("Finalizing a chain thats already finalized.")
  end
  logger.debug("finalizing chain at " .. frameEnded)
  chain.finalized = true
end

function Telegraph.grow_chain(self, timeAttackInteracts)
  local newChain = false
  if not self.senderCurrentlyChaining then
    self.senderCurrentlyChaining = true
    newChain = true
  end

  local result = self.garbage_queue:grow_chain(timeAttackInteracts, newChain)
  self.stoppers.chain[self.garbage_queue.chain_garbage.last] = timeAttackInteracts + GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME
  return result
end

--to see what's going to be ready at a given frame
function Telegraph.peek_all_ready_garbage(self, frame)
  return self:pop_all_ready_garbage(frame, true--[[just_peeking]])
end

function Telegraph.soonest_stopper(self)
  local ret
  ret = self.stoppers.chain[1] or self.stoppers.combo[1] or self.stoppers.metal or nil
  return ret
end

-- Returns all the garbage that is ready to be sent.
--
-- We are recreating specific logic for what garbage is delayed.
--
-- A combo won't delay a chain
-- A chain will delay a combo, combo goes on top

-- Metal won't delay a combo
-- Combo delays a metal, metal goes on top
function Telegraph.pop_all_ready_garbage(self, time_to_check, just_peeking)
  local ready_garbage = {}
  local n_chain_stoppers, n_combo_stoppers = 0, 0 -- count of stoppers remaining
  local subject = self
  assert(time_to_check ~= nil)

  if just_peeking then
    subject = self:makeCopy()
  end
  --remove any chain stoppers that expire this frame,
  for chain_idx, chain_release_frame in pairs(subject.stoppers.chain) do
    if chain_release_frame <= time_to_check then
      logger.debug("removing a chain stopper at " .. chain_release_frame)
      subject.stoppers.chain[chain_idx] = nil
    else
      n_chain_stoppers = n_chain_stoppers + 1
    end
  end

  --remove any combo stoppers that expire this frame,
  for combo_garbage_width, combo_release_frame in pairs(subject.stoppers.combo) do
    if combo_release_frame <= time_to_check then
      logger.trace("removing a combo stopper at " .. combo_release_frame)
      subject.stoppers.combo[combo_garbage_width] = nil
    else 
      n_combo_stoppers = n_combo_stoppers + 1
    end
  end

  --remove the metal stopper if it expires this frame
  if subject.stoppers.metal and subject.stoppers.metal <= time_to_check then
    logger.debug("removing a metal stopper at " .. subject.stoppers.metal)
    subject.stoppers.metal = nil
  end
  
  while subject.garbage_queue.chain_garbage:peek() do

    if not subject.stoppers.chain[subject.garbage_queue.chain_garbage.first] and 
       subject.garbage_queue.chain_garbage:peek().finalized then
      logger.debug("committing chain at " .. time_to_check)
      ready_garbage[#ready_garbage+1] = subject.garbage_queue:pop()
    else 
      logger.trace("could be chaining or stopper")
      --there was a stopper here or their chain could still be going, stop and return.
      if ready_garbage[1] then
        return ready_garbage
      else
        return nil
      end
    end
  end

  for combo_garbage_width=1,6 do
    local n_blocks_of_this_width = subject.garbage_queue.combo_garbage[combo_garbage_width]:len()
    
    local frame_to_release = subject.stoppers.combo[combo_garbage_width]
    if n_blocks_of_this_width > 0 then
      if not frame_to_release then
        logger.debug("committing combo at " .. time_to_check)
        for i=1,n_blocks_of_this_width do
          ready_garbage[#ready_garbage+1] = subject.garbage_queue:pop()
        end
      else 
        --there was a stopper here, stop and return
          if ready_garbage[1] then
            return ready_garbage
          else
            return nil
          end
      end
    end
  end
  
  local frame_to_release_metal = subject.stoppers.metal
  while subject.garbage_queue.metal:peek() and not subject.stoppers.metal do
    logger.debug("committing metal at " .. time_to_check)
    ready_garbage[#ready_garbage+1] = subject.garbage_queue:pop()
  end
  if ready_garbage[1] then
    return ready_garbage
  else
    return nil
  end
end

function Telegraph:popAllAndSendToTarget(clockTime, target)
  local to_send = self:pop_all_ready_garbage(clockTime)
  if to_send and to_send[1] then
    if target then
      target:receiveGarbage(clockTime + GARBAGE_DELAY_LAND_TIME, to_send)
    end
  end
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

function Telegraph:render()

  local telegraph_to_render = self
  local senderCharacter = telegraph_to_render.sender.character

  if config.renderAttacks then

    local orig_atk_w, orig_atk_h = characters[senderCharacter].telegraph_garbage_images["attack"]:getDimensions()
    local atk_scale = 16 / math.max(orig_atk_w, orig_atk_h) -- keep image ratio

    for timeAttackInteracts, attacks_this_frame in pairs(telegraph_to_render.attacks) do
      local frames_since_earned = telegraph_to_render.sender.clock - timeAttackInteracts
      if frames_since_earned < self:attackAnimationStartFrame() then
        --don't draw anything yet, card animation is still in progress.
      elseif frames_since_earned >= self:attackAnimationEndFrame() then
        --Attack is done, remove.
        telegraph_to_render.attacks[timeAttackInteracts] = nil
      else
        for _, attack in ipairs(attacks_this_frame) do
          for _k, garbage_block in ipairs(attack.stuff_to_send) do
            garbage_block.destination_x = self:telegraphRenderXPosition(telegraph_to_render.garbage_queue:get_idx_of_garbage(unpack(garbage_block))) + (TELEGRAPH_BLOCK_WIDTH / 2) - ((TELEGRAPH_BLOCK_WIDTH / orig_atk_w) / 2)
            garbage_block.destination_y = garbage_block.destination_y or (telegraph_to_render.originY - TELEGRAPH_PADDING)

            if not attack.origin_x or not attack.origin_y then
              attack.origin_x = (attack.attackDrawColumn-1) * 16 + telegraph_to_render.sender.panelOriginX
              attack.origin_y = (11-attack.attackDrawRow) * 16 + telegraph_to_render.sender.panelOriginY + (telegraph_to_render.sender.displacement or 0) - (consts.CARD_ANIMATION[frames_since_earned] or 0)
              attack.direction = math.sign(garbage_block.destination_x - attack.origin_x) --should give -1 for left, or 1 for right
            end

            if self.sender.opacityForFrame then
              GraphicsUtil.setColor(1, 1, 1, self.sender:opacityForFrame(frames_since_earned, 1, 8))
            end

            if frames_since_earned <= self:attackAnimationStartFrame() + #telegraph_attack_animation_speed then
              --draw telegraph attack animation, little loop down and to the side of origin.

              -- We can't gaurantee every frame was rendered, so we must calculate the exact location regardless of how many frames happened.
              -- TODO make this more performant?
              local garbageBlockX, garbageBlockY = telegraph_to_render:telegraphLoopAttackPosition(attack, garbage_block, frames_since_earned)

              GraphicsUtil.drawGfxScaled(characters[senderCharacter].telegraph_garbage_images["attack"], garbageBlockX, garbageBlockY, 0, atk_scale, atk_scale)
            else
              --move toward destination

              local loopX, loopY = telegraph_to_render:telegraphLoopAttackPosition(attack, garbage_block, frames_since_earned)
              local framesHappened = frames_since_earned - (self:attackAnimationStartFrame() + #telegraph_attack_animation_speed)
              local totalFrames = self:attackAnimationEndFrame() - (self:attackAnimationStartFrame() + #telegraph_attack_animation_speed)
              local percent =  framesHappened / totalFrames

              local garbageBlockX = loopX + percent * (garbage_block.destination_x - loopX)
              local garbageBlockY = loopY + percent * (garbage_block.destination_y - loopY)

              GraphicsUtil.drawGfxScaled(characters[senderCharacter].telegraph_garbage_images["attack"], garbageBlockX, garbageBlockY, 0, atk_scale, atk_scale)
            end

            GraphicsUtil.setColor(1, 1, 1, 1)
          end
        end
      end
    end
  end

  if config.renderTelegraph then
    -- Render if we are "currently chaining" for debug purposes
    if config.debug_mode and telegraph_to_render.senderCurrentlyChaining then
      local orig_atk_w, orig_atk_h = characters[senderCharacter].telegraph_garbage_images["attack"]:getDimensions()
      local atk_scale = 16 / math.max(orig_atk_w, orig_atk_h) -- keep image ratio
  
      GraphicsUtil.drawGfxScaled(characters[senderCharacter].telegraph_garbage_images["attack"], telegraph_to_render:telegraphRenderXPosition(-1), telegraph_to_render.originY, 0, atk_scale, atk_scale)
    end

    --then draw the telegraph's garbage queue, leaving an empty space until such a time as the attack arrives
    local g_queue_to_draw = telegraph_to_render.garbage_queue:makeCopy()
    local current_block = g_queue_to_draw:pop()
    local draw_y = telegraph_to_render.originY
    local drewChain = false
    local attackAnimationLength = self:attackAnimationEndFrame()
    if not config.renderAttacks then
      attackAnimationLength = 0
    end

    local currentIndex = 0
    while current_block do
      if telegraph_to_render.sender.clock - current_block.timeAttackInteracts >= attackAnimationLength then
        local draw_x = self:telegraphRenderXPosition(currentIndex)
        if not current_block[3]--[[is_metal]] then
          local height = math.min(current_block[2], 14)
          if height > 1 then -- For illegal chain garbage, default to using the chain size graphics
            current_block[1] = 6
          end
          local orig_grb_w, orig_grb_h = characters[senderCharacter].telegraph_garbage_images[height][current_block[1]]:getDimensions()
          local grb_scale_x = 24 / orig_grb_w
          local grb_scale_y = 16 / orig_grb_h
          GraphicsUtil.drawGfxScaled(characters[senderCharacter].telegraph_garbage_images[height--[[height]]][current_block[1]--[[width]]], draw_x, draw_y, 0, grb_scale_x, grb_scale_y)
        else
          local orig_mtl_w, orig_mtl_h = characters[senderCharacter].telegraph_garbage_images["metal"]:getDimensions()
          local mtl_scale_x = 24 / orig_mtl_w
          local mtl_scale_y = 16 / orig_mtl_h
          GraphicsUtil.drawGfxScaled(characters[senderCharacter].telegraph_garbage_images["metal"], draw_x, draw_y, 0, mtl_scale_x, mtl_scale_y)
        end
        drewChain = drewChain or current_block[4]

        -- Render the stop times above blocks for debug purposes
        if config.debug_mode then
          local stopperTime = nil

          if current_block[4]--[[chain]] then
            stopperTime = telegraph_to_render.stoppers.chain[telegraph_to_render.garbage_queue.chain_garbage.first]
            if stopperTime and current_block.finalized then
              stopperTime = stopperTime .. " F"
            end
          else
            if current_block[3]--[[is_metal]] then
              stopperTime = telegraph_to_render.stoppers.metal
            else
              stopperTime = telegraph_to_render.stoppers.combo[current_block[1]]
            end
          end

          if stopperTime then
            GraphicsUtil.printf(stopperTime, draw_x*GFX_SCALE, (draw_y-8)*GFX_SCALE, 70, "center", nil, 1, 10)
          end
        end

      end
      current_block = g_queue_to_draw:pop()
      currentIndex = currentIndex + 1
    end
    
    if not drewChain and telegraph_to_render.garbage_queue.ghost_chain then
      local draw_x = self:telegraphRenderXPosition(0)
      local draw_y = telegraph_to_render.originY
      local height = math.min(telegraph_to_render.garbage_queue.ghost_chain, 14)
      local orig_grb_w, orig_grb_h = characters[senderCharacter].telegraph_garbage_images[height][6]:getDimensions()
      local grb_scale_x = 24 / orig_grb_w
      local grb_scale_y = 16 / orig_grb_h
      GraphicsUtil.drawGfxScaled(characters[senderCharacter].telegraph_garbage_images[height][6], draw_x, draw_y, 0, grb_scale_x, grb_scale_y)

      -- Render a "G" for ghost
      if config.debug_mode then
        GraphicsUtil.printf("G", draw_x*GFX_SCALE, (draw_y-8)*GFX_SCALE, 70, "center", nil, 1, 10)
      end
    end

  end

end
