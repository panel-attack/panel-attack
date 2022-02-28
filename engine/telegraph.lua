local logger = require("logger")

local TELEGRAPH_HEIGHT = 16
local TELEGRAPH_PADDING = 2 --vertical space between telegraph and stack
local TELEGRAPH_BLOCK_WIDTH = 24
local TELEGRAPH_ATTACK_MAX_SPEED = 8 --fastest an attack can travel toward the telegraph per frame

Telegraph = class(function(self, sender, owner)

  -- Stores the actual queue of garbages in the telegraph but not queued long enough to exceed the "stoppers"
  self.garbage_queue = GarbageQueue(sender)

  -- Attacks must stay in the telegraph a certain amount of time before they can be sent, we track this with "stoppers"
  --note: keys for stoppers such as self.stoppers.chain[some_key]
  --will be the garbage block's index in the queue , and value will be the frame the stopper expires).
  --keys for self.stoppers.combo[some_key] will be garbage widths, and values will be frame_to_release
  self.stoppers =  {chain = {}, combo = {}, metal = nil}
  
  self.sender = sender -- The stack that sent this garbage
  self.owner = owner -- The stack that is receiving the garbage
  self.pos_x = owner.pos_x - 4
  self.pos_y = owner.pos_y - 4 - TELEGRAPH_HEIGHT - TELEGRAPH_PADDING
  self.attacks = {} -- A copy of the chains and combos earned used to render the animation of going to the telegraph
  self.pendingGarbage = {} -- Table of garbage that needs to be pushed into the telegraph at specific CLOCK times
  self.pendingChainingEnded = {} -- A list of CLOCK times where chaining ended in the future
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


function Telegraph.rollbackCopy(self, source, other)
  if other == nil then
    other = Telegraph(source.sender, source.owner)
  end

  other.garbage_queue = source.garbage_queue:makeCopy()
  other.stoppers = deepcpy(source.stoppers)
  other.attacks = deepcpy(source.attacks)
  other.sender = source.sender
  other.pos_x = source.pos_x
  other.pos_y = source.pos_y
  other.senderCurrentlyChaining = source.senderCurrentlyChaining
  other.pendingGarbage = deepcpy(source.pendingGarbage)
  other.pendingChainingEnded = deepcpy(source.pendingChainingEnded)
  return other
end

function Telegraph:update() 

  if self.pendingChainingEnded[self.owner.CLOCK] then
    self:chainingEnded(self.owner.CLOCK)
    self.pendingChainingEnded[self.owner.CLOCK] = nil
  end

  if self.pendingGarbage[self.owner.CLOCK] then
    for _, pendingGarbage in ipairs(self.pendingGarbage[self.owner.CLOCK]) do
      self:privatePush(unpack(pendingGarbage))
    end
    self.pendingGarbage[self.owner.CLOCK] = nil
  end
end

-- Adds a piece of garbage to the queue
function Telegraph.push(self, attack_type, attack_size, metal_count, attack_origin_col, attack_origin_row, frame_earned)

  -- If we got an attack earlier then last frame, (they attacked in the past and we missed it) we need to rollback
  if frame_earned < self.owner.CLOCK - 1 then
    self.owner:rollbackToFrame(frame_earned+1)
  end

  -- If we got the attack in the future, wait to queue it
  if frame_earned > self.owner.CLOCK then
    if not self.pendingGarbage[frame_earned] then
      self.pendingGarbage[frame_earned] = {}
    end

    self.pendingGarbage[frame_earned][#self.pendingGarbage[frame_earned]+1] = {attack_type, attack_size, metal_count, attack_origin_col, attack_origin_row, frame_earned}

    return
  end

  -- Now push this attack
  self:privatePush(attack_type, attack_size, metal_count, attack_origin_col, attack_origin_row, frame_earned)

  -- We may have more attacks this frame. To make sure we save our rollback state with all attacks, don't save and resimulate till we are done with this frame.
  -- Then only resimulate as needed, because we might simulate more than we need to since another rollback might happen.
end

-- Adds a piece of garbage to the queue
function Telegraph.privatePush(self, attack_type, attack_size, metal_count, attack_origin_col, attack_origin_row, frame_earned)

  local x_displacement 
  if not metal_count then
    metal_count = 0
  end
  local stuff_to_send
  if attack_type == "chain" then
    stuff_to_send = self:grow_chain(frame_earned)
  elseif attack_type == "combo" then
    -- get combo_garbage_widths, n_resulting_metal_garbage
    stuff_to_send = self:add_combo_garbage(attack_size, metal_count, frame_earned)
    stuff_to_send = deepcpy(stuff_to_send) -- we don't want to use the same object as in the garbage queue so they don't change each other
  end
  if not self.attacks[frame_earned] then
    self.attacks[frame_earned] = {}
  end
  self.attacks[frame_earned][#self.attacks[frame_earned]+1] =
    {frame_earned=frame_earned, origin_col=attack_origin_col, origin_row= attack_origin_row, stuff_to_send=stuff_to_send}

end

function Telegraph.add_combo_garbage(self, n_combo, n_metal, frame_earned)
  logger.debug("Telegraph.add_combo_garbage "..(n_combo or "nil").." "..(n_metal or "nil"))
  local stuff_to_send = {}
  for i=3,n_metal do
    stuff_to_send[#stuff_to_send+1] = {6, 1, true, false, frame_earned = frame_earned}
    self.stoppers.metal = frame_earned+GARBAGE_TRANSIT_TIME + GARBAGE_DELAY
  end
  local combo_pieces = combo_garbage[n_combo]
  for i=1,#combo_pieces do
    stuff_to_send[#stuff_to_send+1] = {combo_pieces[i], 1, false, false, frame_earned = frame_earned}
    self.stoppers.combo[combo_pieces[i]] = frame_earned+GARBAGE_TRANSIT_TIME + GARBAGE_DELAY
  end
  self.garbage_queue:push(stuff_to_send)
  return stuff_to_send
  
end

function Telegraph:chainingEnded(frameEnded)

  -- If they ended chaining earlier then last frame, (they finished the chain in the past and we missed it) we need to rollback
  if frameEnded < self.owner.CLOCK - 1 then
    self.owner:rollbackToFrame(frameEnded+1)
  end
  
  -- If we got the attack in the future wait to queue it
  if frameEnded > self.owner.CLOCK then
    self.pendingChainingEnded[frameEnded] = true
    return
  end

  self.senderCurrentlyChaining = false
  local chain = self.garbage_queue.chain_garbage[self.garbage_queue.chain_garbage.last]
  if chain.frame_earned >= frameEnded then
    logger.error("Finalizing a chain that ended before it was earned.")
  end
  chain.finalized = true
end

function Telegraph.grow_chain(self, frame_earned)
  local newChain = false
  if not self.senderCurrentlyChaining then
    self.senderCurrentlyChaining = true
    newChain = true
  end

  local result = self.garbage_queue:grow_chain(frame_earned, newChain)
  self.stoppers.chain[self.garbage_queue.chain_garbage.last] = frame_earned + GARBAGE_TRANSIT_TIME + GARBAGE_DELAY
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
      logger.debug("in Telegraph.pop_all_ready_garbage")
      logger.debug("removing a stopper")
      subject.stoppers.chain[chain_idx] = nil
    else
      n_chain_stoppers = n_chain_stoppers + 1
    end
  end

  --remove any combo stoppers that expire this frame,
  for combo_garbage_width, combo_release_frame in pairs(subject.stoppers.combo) do
    if combo_release_frame <= time_to_check then
      subject.stoppers.combo[combo_garbage_width] = nil
    else 
      n_combo_stoppers = n_combo_stoppers + 1
    end
  end

  --remove the metal stopper if it expires this frame
  if subject.stoppers.metal and subject.stoppers.metal <= time_to_check then
    subject.stoppers.metal = nil
  end
  
  while subject.garbage_queue.chain_garbage:peek() do

    if not subject.stoppers.chain[subject.garbage_queue.chain_garbage.first] and subject.garbage_queue.chain_garbage:peek().finalized then
      logger.debug("in Telegraph.pop_all_ready_garbage")
      logger.debug("popping the first chain")
      ready_garbage[#ready_garbage+1] = subject.garbage_queue:pop()
    else 
      logger.debug("could be chaining or stopper")
      --there was a stopper here or their chain could still be going, stop and return.
      if ready_garbage[1] then
        return ready_garbage
      else
        return nil
      end
    end
  end

  for combo_garbage_width=3,6 do
    local n_blocks_of_this_width = subject.garbage_queue.combo_garbage[combo_garbage_width]:len()
    
    local frame_to_release = subject.stoppers.combo[combo_garbage_width]
    if n_blocks_of_this_width > 0 then
      if not frame_to_release then
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
      ready_garbage[#ready_garbage+1] = subject.garbage_queue:pop()
  end
  if ready_garbage[1] then
    return ready_garbage
  else
    return nil
  end
end

function Telegraph:render()
  local telegraph_to_render = self
  local senderCharacter = telegraph_to_render.sender.character

  local render_x = telegraph_to_render.pos_x
  local orig_atk_w, orig_atk_h = characters[senderCharacter].telegraph_garbage_images["attack"]:getDimensions()
  local atk_scale = 16 / math.max(orig_atk_w, orig_atk_h) -- keep image ratio

  -- Render if we are "currently chaining" for debug purposes
  if config.debug_mode and telegraph_to_render.senderCurrentlyChaining then
    draw(characters[senderCharacter].telegraph_garbage_images["attack"], render_x - 15 , telegraph_to_render.pos_y, 0, atk_scale, atk_scale)
  end

  for frame_earned, attacks_this_frame in pairs(telegraph_to_render.attacks) do
    local frames_since_earned = telegraph_to_render.owner.CLOCK - frame_earned
      if frames_since_earned <= #card_animation then
        --don't draw anything yet, card animation is still in progress.
      elseif frames_since_earned >= GARBAGE_TRANSIT_TIME then
        --Attack is done, remove.
        telegraph_to_render.attacks[frame_earned] = nil
      else
        for _, attack in ipairs(attacks_this_frame) do
          for _k, garbage_block in ipairs(attack.stuff_to_send) do
            garbage_block.destination_x = telegraph_to_render.pos_x + TELEGRAPH_BLOCK_WIDTH * telegraph_to_render.garbage_queue:get_idx_of_garbage(unpack(garbage_block))
            garbage_block.destination_y = garbage_block.destination_y or telegraph_to_render.pos_y - TELEGRAPH_HEIGHT - TELEGRAPH_PADDING 
            
            if not garbage_block.origin_x or not garbage_block.origin_y then
              garbage_block.origin_x = (attack.origin_col-1) * 16 + telegraph_to_render.sender.pos_x
              garbage_block.origin_y = (11-attack.origin_row) * 16 + telegraph_to_render.sender.pos_y + telegraph_to_render.sender.displacement - card_animation[#card_animation]
              garbage_block.x = garbage_block.origin_x
              garbage_block.y = garbage_block.origin_y
              garbage_block.direction = garbage_block.direction or sign(garbage_block.destination_x - garbage_block.origin_x) --should give -1 for left, or 1 for right
            end

            if frames_since_earned <= #card_animation + #telegraph_attack_animation_speed then
              --draw telegraph attack animation, little loop down and to the side of origin.
     
              -- We can't gaurantee every frame was rendered, so we must calculate the exact location regardless of how many frames happened.
              -- TODO make this more performant?
              garbage_block.x = garbage_block.origin_x
              garbage_block.y = garbage_block.origin_y
              for frame=1, frames_since_earned - #card_animation do
                garbage_block.x = garbage_block.x + telegraph_attack_animation[garbage_block.direction][frame].dx
                garbage_block.y = garbage_block.y + telegraph_attack_animation[garbage_block.direction][frame].dy
              end

              draw(characters[senderCharacter].telegraph_garbage_images["attack"], garbage_block.x, garbage_block.y, 0, atk_scale, atk_scale)
            else
              --move toward destination
              local distance_to_destination = math.sqrt(math.pow(garbage_block.x-garbage_block.destination_x,2)+math.pow(garbage_block.y-garbage_block.destination_y,2))
              if frames_since_earned == #card_animation + #telegraph_attack_animation_speed then
                garbage_block.speed = distance_to_destination / (GARBAGE_TRANSIT_TIME-frames_since_earned)
              end
  
              if distance_to_destination <= (garbage_block.speed or TELEGRAPH_ATTACK_MAX_SPEED) then
                --just move it to it's destination
                garbage_block.x, garbage_block.y = garbage_block.destination_x, garbage_block.destination_y
              else
                garbage_block.x = garbage_block.x - ((garbage_block.speed or TELEGRAPH_ATTACK_MAX_SPEED)*(garbage_block.x-garbage_block.destination_x))/distance_to_destination
                garbage_block.y = garbage_block.y - ((garbage_block.speed or TELEGRAPH_ATTACK_MAX_SPEED)*(garbage_block.y-garbage_block.destination_y))/distance_to_destination
              end

              draw(characters[senderCharacter].telegraph_garbage_images["attack"], garbage_block.x, garbage_block.y, 0, atk_scale, atk_scale)
            end
          end
        end
      end
  end

  --then draw the telegraph's garbage queue, leaving an empty space until such a time as the attack arrives (earned_frame-GARBAGE_TRANSIT_TIME)
  local g_queue_to_draw = telegraph_to_render.garbage_queue:makeCopy()
  local current_block = g_queue_to_draw:pop()
  local draw_x = telegraph_to_render.pos_x
  local draw_y = telegraph_to_render.pos_y
  local drewChain = false

  while current_block do
    --TODO: create a way to draw telegraphs from right to left
    if telegraph_to_render.owner.CLOCK - current_block.frame_earned >= GARBAGE_TRANSIT_TIME then
      if not current_block[3]--[[is_metal]] then
        local height = math.min(current_block[2], 14)
        local orig_grb_w, orig_grb_h = characters[senderCharacter].telegraph_garbage_images[height][current_block[1]]:getDimensions()
        local grb_scale_x = 24 / orig_grb_w
        local grb_scale_y = 16 / orig_grb_h
        draw(characters[senderCharacter].telegraph_garbage_images[height--[[height]]][current_block[1]--[[width]]], draw_x, draw_y, 0, grb_scale_x, grb_scale_y)
      else
        local orig_mtl_w, orig_mtl_h = characters[senderCharacter].telegraph_garbage_images["metal"]:getDimensions()
        local mtl_scale_x = 24 / orig_mtl_w
        local mtl_scale_y = 16 / orig_mtl_h
        draw(characters[senderCharacter].telegraph_garbage_images["metal"], draw_x, draw_y, 0, mtl_scale_x, mtl_scale_y)
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
          gprintf(stopperTime, draw_x*GFX_SCALE, (draw_y-8)*GFX_SCALE, 70, "center", nil, 1, large_font)
        end
      end

    end
    draw_x = draw_x + TELEGRAPH_BLOCK_WIDTH 
    current_block = g_queue_to_draw:pop()
  end
  
  if not drewChain and telegraph_to_render.garbage_queue.ghost_chain then
    local draw_x = telegraph_to_render.pos_x
    local draw_y = telegraph_to_render.pos_y
    local height = math.min(telegraph_to_render.garbage_queue.ghost_chain, 14)
    local orig_grb_w, orig_grb_h = characters[senderCharacter].telegraph_garbage_images[height][6]:getDimensions()
    local grb_scale_x = 24 / orig_grb_w
    local grb_scale_y = 16 / orig_grb_h
    draw(characters[senderCharacter].telegraph_garbage_images[height][6], draw_x, draw_y, 0, grb_scale_x, grb_scale_y)

    -- Render a "G" for ghost
    if config.debug_mode then
      gprintf("G", draw_x*GFX_SCALE, (draw_y-8)*GFX_SCALE, 70, "center", nil, 1, large_font)
    end
  end

end
