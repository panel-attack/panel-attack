local logger = require("logger")

local TELEGRAPH_HEIGHT = 16
local TELEGRAPH_PADDING = 2 -- vertical space between telegraph and stack
local TELEGRAPH_BLOCK_WIDTH = 26
local TELEGRAPH_ATTACK_MAX_SPEED = 8 -- fastest an attack can travel toward the telegraph per frame

local clone_pool = {}

Telegraph = class(function(self, sender, owner)

  -- Stores the actual queue of garbages in the telegraph but not queued long enough to exceed the "stoppers"
  self.garbage_queue = GarbageQueue(sender)

  -- Attacks must stay in the telegraph a certain amount of time before they can be sent, we track this with "stoppers"
  -- note: keys for stoppers such as self.stoppers.chain[some_key]
  -- will be the garbage block's index in the queue , and value will be the frame the stopper expires).
  -- keys for self.stoppers.combo[some_key] will be garbage widths, and values will be frame_to_release
  self.stoppers = {chain = {}, combo = {}, metal = nil}

  self.sender = sender -- The stack that sent this garbage
  self.owner = owner -- The stack that is receiving the garbage
  self:updatePosition()
  self.attacks = {} -- A copy of the chains and combos earned used to render the animation of going to the telegraph
  self.senderCurrentlyChaining = false -- Set when we start a new chain, cleared when the sender is done chaining, used to know if we should grow a chain or start a new one, and to know if we are allowed to send the attack since the sender is done.
  -- (typically sending is prevented by garbage chaining)

  self:preloadGraphics()
end)

function Telegraph:preloadGraphics()
  if config.renderAttacks or config.renderTelegraph then
    local character = self.sender.character
    self.gfx = {}
    self.gfx.attack = {}
    self.gfx.attack.image = characters[character].telegraph_garbage_images["attack"]
    self.gfx.attack.width, self.gfx.attack.height = self.gfx.attack.image:getDimensions()
    self.gfx.attack.scale = 16 / math.max(self.gfx.attack.width, self.gfx.attack.height)
    if config.renderTelegraph then
      -- metal
      self.gfx.telegraph = {}
      self.gfx.telegraph.metal = {}
      self.gfx.telegraph.metal.image = characters[character].telegraph_garbage_images["metal"]
      local metalWidth, metalHeight = self.gfx.telegraph.metal.image:getDimensions()
      self.gfx.telegraph.metal.xScale = 24 / metalWidth
      self.gfx.telegraph.metal.yScale = 16 / metalHeight

      -- chain garbage
      self.gfx.telegraph.chain = {}
      for garbageHeight = 1, 14 do
        self.gfx.telegraph.chain[garbageHeight] = {}
        self.gfx.telegraph.chain[garbageHeight].image = characters[character].telegraph_garbage_images[garbageHeight][6]
        local imageWidth, imageHeight = self.gfx.telegraph.chain[garbageHeight].image:getDimensions()
        self.gfx.telegraph.chain[garbageHeight].xScale = 24 / imageWidth
        self.gfx.telegraph.chain[garbageHeight].yScale = 16 / imageHeight
      end

      -- combo garbage
      self.gfx.telegraph.combo = {}
      for garbageWidth = 1, 6 do
        self.gfx.telegraph.combo[garbageWidth] = {}
        self.gfx.telegraph.combo[garbageWidth].image = characters[character].telegraph_garbage_images[1][garbageWidth]
        local imageWidth, imageHeight = self.gfx.telegraph.combo[garbageWidth].image:getDimensions()
        self.gfx.telegraph.combo[garbageWidth].xScale = 24 / imageWidth
        self.gfx.telegraph.combo[garbageWidth].yScale = 16 / imageHeight
      end
    end
  end
end

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

function Telegraph:updatePosition()
  self.pos_x = self.owner.pos_x - 4
  self.pos_y = self.owner.pos_y - 4 - TELEGRAPH_HEIGHT - TELEGRAPH_PADDING
end

function Telegraph.saveClone(toSave)
  clone_pool[#clone_pool + 1] = toSave
end

function Telegraph.rollbackCopy(source, other)
  if other == nil then
    if #clone_pool == 0 then
      other = Telegraph(source.sender, source.owner)
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
  other.pos_x = source.pos_x
  other.pos_y = source.pos_y
  other.senderCurrentlyChaining = source.senderCurrentlyChaining

  -- We don't want saved copies to hold on to stacks, up to the rollback restore to set these back up.
  other.sender = nil
  other.owner = nil
  return other
end

-- Adds a piece of garbage to the queue
function Telegraph:push(garbage, attackOriginCol, attackOriginRow, frameEarned)
  assert(self.sender ~= nil and self.owner ~= nil, "telegraph needs owner and sender set")
  assert(frameEarned == self.sender.CLOCK, "expected sender clock to equal attack")

  self:privatePush(garbage, attackOriginCol, attackOriginRow, frameEarned + 1)
end

-- Adds a piece of garbage to the queue
function Telegraph.privatePush(self, garbage, attackOriginColumn, attackOriginRow, timeAttackInteracts)
  local garbageToSend
  if garbage.isChain then
    garbageToSend = self:grow_chain(timeAttackInteracts)
  else
    -- get combo_garbage_widths, n_resulting_metal_garbage
    garbageToSend = self:add_combo_garbage(garbage, timeAttackInteracts)
  end
  if config.renderAttacks then
    if not self.attacks[timeAttackInteracts] then
      self.attacks[timeAttackInteracts] = {}
    end
    -- we don't want to use the same object as in the garbage queue so they don't change each other
    garbageToSend = deepcpy(garbageToSend)
    self.attacks[timeAttackInteracts][#self.attacks[timeAttackInteracts] + 1] = {
      timeAttackInteracts = timeAttackInteracts,
      origin_col = attackOriginColumn,
      origin_row = attackOriginRow,
      stuff_to_send = garbageToSend
    }
  end
end

function Telegraph.add_combo_garbage(self, garbage, timeAttackInteracts)
  logger.debug("Telegraph.add_combo_garbage " .. (garbage.width or "nil") .. " " .. (garbage.isMetal and "true" or "false"))
  local garbageToSend = {}
  if garbage.isMetal and (GAME.battleRoom.trainingModeSettings == nil or not GAME.battleRoom.trainingModeSettings.mergeComboMetalQueue) then
    garbageToSend[#garbageToSend + 1] = {width = 6, height = 1, isMetal = true, isChain = false, timeAttackInteracts = timeAttackInteracts}
    self.stoppers.metal = timeAttackInteracts + GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME
  else
    garbageToSend[#garbageToSend + 1] = {
      width = garbage.width,
      height = garbage.height,
      isMetal = garbage.isMetal,
      isChain = garbage.isChain,
      timeAttackInteracts = timeAttackInteracts
    }
    self.stoppers.combo[garbage.width] = timeAttackInteracts + GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME
  end
  self.garbage_queue:push(garbageToSend)
  return garbageToSend
end

function Telegraph:chainingEnded(frameEnded)
  logger.debug("Player " .. self.sender.which .. " chain ended at " .. frameEnded)

  if not GAME.battleRoom.trainingModeSettings then
    assert(frameEnded == self.sender.CLOCK, "expected sender clock to equal attack")
  end

  self:privateChainingEnded(frameEnded)
end

function Telegraph:privateChainingEnded(timeAttackInteracts)

  self.senderCurrentlyChaining = false
  local chain = self.garbage_queue.chain_garbage[self.garbage_queue.chain_garbage.last]
  if chain.timeAttackInteracts >= timeAttackInteracts then
    logger.error("Finalizing a chain that ended before it was earned.")
  end
  logger.debug("finalizing chain at " .. timeAttackInteracts)
  chain.finalized = timeAttackInteracts
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
function Telegraph.pop_all_ready_garbage(self, time_to_check)
  local ready_garbage = {}
  local n_chain_stoppers, n_combo_stoppers = 0, 0 -- count of stoppers remaining
  local subject = self
  assert(time_to_check ~= nil)

  -- remove any chain stoppers that expire this frame,
  for chain_idx, chain_release_frame in pairs(subject.stoppers.chain) do
    if chain_release_frame <= time_to_check then
      logger.debug("removing a chain stopper at " .. chain_release_frame)
      subject.stoppers.chain[chain_idx] = nil
    else
      n_chain_stoppers = n_chain_stoppers + 1
    end
  end

  -- remove any combo stoppers that expire this frame,
  for combo_garbage_width, combo_release_frame in pairs(subject.stoppers.combo) do
    if combo_release_frame <= time_to_check then
      logger.debug("removing a combo stopper at " .. combo_release_frame)
      subject.stoppers.combo[combo_garbage_width] = nil
    else
      n_combo_stoppers = n_combo_stoppers + 1
    end
  end

  -- remove the metal stopper if it expires this frame
  if subject.stoppers.metal and subject.stoppers.metal <= time_to_check then
    logger.debug("removing a metal stopper at " .. subject.stoppers.metal)
    subject.stoppers.metal = nil
  end

  while subject.garbage_queue.chain_garbage:peek() do

    if not subject.stoppers.chain[subject.garbage_queue.chain_garbage.first] and subject.garbage_queue.chain_garbage:peek().finalized then
      logger.debug("committing chain at " .. time_to_check)
      ready_garbage[#ready_garbage + 1] = subject.garbage_queue:pop()
    else
      logger.debug("could be chaining or stopper")
      -- there was a stopper here or their chain could still be going, stop and return.
      if ready_garbage[1] then
        return ready_garbage
      else
        return nil
      end
    end
  end

  for combo_garbage_width = 1, 6 do
    local n_blocks_of_this_width = subject.garbage_queue.combo_garbage[combo_garbage_width]:len()

    local frame_to_release = subject.stoppers.combo[combo_garbage_width]
    if n_blocks_of_this_width > 0 then
      if not frame_to_release then
        logger.debug("committing combo at " .. time_to_check)
        for i = 1, n_blocks_of_this_width do
          ready_garbage[#ready_garbage + 1] = subject.garbage_queue:pop()
        end
      else
        -- there was a stopper here, stop and return
        if ready_garbage[1] then
          return ready_garbage
        else
          return nil
        end
      end
    end
  end

  while subject.garbage_queue.metal:peek() and not subject.stoppers.metal do
    logger.debug("committing metal at " .. time_to_check)
    ready_garbage[#ready_garbage + 1] = subject.garbage_queue:pop()
  end
  if ready_garbage[1] then
    return ready_garbage
  else
    return nil
  end
end

function Telegraph:telegraphRenderXPosition(index)

  local stackWidth = math.floor(self.owner.canvas:getWidth() / GFX_SCALE)
  local increment = -TELEGRAPH_BLOCK_WIDTH * self.owner.mirror_x

  local result = self.pos_x
  if self.owner.which == 1 then
    result = result + stackWidth + increment
  end

  result = result + (increment * index)

  return result
end

function Telegraph:attackStartFrame()
  return 1
end

function Telegraph:telegraphLoopAttackPosition(garbage_block, frames_since_earned)

  local resultX, resultY = garbage_block.origin_x, garbage_block.origin_y

  if frames_since_earned > self:attackStartFrame() + #telegraph_attack_animation_speed then
    frames_since_earned = self:attackStartFrame() + #telegraph_attack_animation_speed
  end

  -- We can't gaurantee every frame was rendered, so we must calculate the exact location regardless of how many frames happened.
  -- TODO make this more performant?
  for frame = 1, frames_since_earned - self:attackStartFrame() do
    resultX = resultX + telegraph_attack_animation[garbage_block.direction][frame].dx
    resultY = resultY + telegraph_attack_animation[garbage_block.direction][frame].dy
  end

  return resultX, resultY
end

function Telegraph:render()
  if config.renderAttacks then
    self:renderAttacks()
  end

  if config.renderTelegraph then
    self:renderTelegraph()
  end
end

function Telegraph:renderAttacks()
  for timeAttackInteracts, attacks_this_frame in pairs(self.attacks) do
    local frames_since_earned = self.sender.CLOCK - timeAttackInteracts
    if frames_since_earned <= self:attackStartFrame() then
      -- don't draw anything yet, card animation is still in progress.
    elseif frames_since_earned >= GARBAGE_TRANSIT_TIME then
      -- Attack is done, remove.
      self.attacks[timeAttackInteracts] = nil
    else
      for _, attack in ipairs(attacks_this_frame) do
        for _, garbage_block in ipairs(attack.stuff_to_send) do
          garbage_block.destination_x = self:telegraphRenderXPosition(
                                            self.garbage_queue:get_idx_of_garbage(garbage_block)) +
                                            (TELEGRAPH_BLOCK_WIDTH / 2) - ((TELEGRAPH_BLOCK_WIDTH / self.gfx.attack.width) / 2)
          garbage_block.destination_y = garbage_block.destination_y or (self.pos_y - TELEGRAPH_PADDING)

          if not garbage_block.origin_x or not garbage_block.origin_y then
            garbage_block.origin_x = (attack.origin_col - 1) * 16 + self.sender.pos_x
            garbage_block.origin_y = (11 - attack.origin_row) * 16 + self.sender.pos_y +
                                         self.sender.displacement - card_animation[#card_animation]
            garbage_block.x = garbage_block.origin_x
            garbage_block.y = garbage_block.origin_y
            garbage_block.direction = garbage_block.direction or math.sign(garbage_block.destination_x - garbage_block.origin_x) -- should give -1 for left, or 1 for right
          end

          if frames_since_earned <= self:attackStartFrame() + #telegraph_attack_animation_speed then
            -- draw telegraph attack animation, little loop down and to the side of origin.

            -- We can't gaurantee every frame was rendered, so we must calculate the exact location regardless of how many frames happened.
            -- TODO make this more performant?
            garbage_block.x, garbage_block.y = self:telegraphLoopAttackPosition(garbage_block, frames_since_earned)

            draw(self.gfx.attack.image, garbage_block.x, garbage_block.y, 0, self.gfx.attack.scale, self.gfx.attack.scale)
          else
            -- move toward destination

            local loopX, loopY = self:telegraphLoopAttackPosition(garbage_block, frames_since_earned)
            local framesHappened = frames_since_earned - (self:attackStartFrame() + #telegraph_attack_animation_speed)
            local totalFrames = GARBAGE_TRANSIT_TIME - (self:attackStartFrame() + #telegraph_attack_animation_speed)
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

function Telegraph:renderTelegraph()
    -- Render if we are "currently chaining" for debug purposes
  if config.debug_mode and self.senderCurrentlyChaining then
    draw(self.gfx.attack.image, self:telegraphRenderXPosition(-1), self.pos_y, 0, self.gfx.attack.scale, self.gfx.attack.scale)
  end

  -- then draw the telegraph's garbage queue, leaving an empty space until such a time as the attack arrives (earned_frame-GARBAGE_TRANSIT_TIME)
  local g_queue_to_draw = self.garbage_queue:makeCopy()
  local current_block = g_queue_to_draw:pop()
  local draw_y = self.pos_y
  local drewChain = false
  local attackAnimationLength = GARBAGE_TRANSIT_TIME
  if not config.renderAttacks then
    attackAnimationLength = 0
  end

  local currentIndex = 0
  while current_block do
    if self.sender.CLOCK - current_block.timeAttackInteracts >= attackAnimationLength then
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
          stopperTime = self.stoppers.chain[self.garbage_queue.chain_garbage.first]
          if stopperTime and current_block.finalized then
            stopperTime = stopperTime .. " F"
          end
        else
          if current_block.isMetal then
            stopperTime = self.stoppers.metal
          else
            stopperTime = self.stoppers.combo[current_block.width]
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

  if not drewChain and self.garbage_queue.ghost_chain then
    local draw_x = self:telegraphRenderXPosition(0)
    -- local draw_y = self.pos_y -- already defined like this further above
    local height = math.min(self.garbage_queue.ghost_chain, 14)
    local chainGfx = self.gfx.telegraph.chain[height]
    draw(chainGfx, draw_x, draw_y, 0, chainGfx.xScale, chainGfx.yScale)

    -- Render a "G" for ghost
    if config.debug_mode then
      gprintf("G", draw_x * GFX_SCALE, (draw_y - 8) * GFX_SCALE, 70, "center", nil, 1, large_font)
    end
  end
end