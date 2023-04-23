local logger = require("logger")

local function sortByPopOrder(panelList, isGarbage)
  table.sort(panelList, function(a, b)
    if a.row == b.row then
      if isGarbage then
        -- garbage pops right to left
        return a.column > b.column
      else
        -- matches pop left to right
        return a.column < b.column
      end
    else
      if isGarbage then
        -- garbage pops bottom to top
        return a.row < b.row
      else
        -- matches pop top to bottom
        return a.row > b.row
      end
    end
  end)

  return panelList
end

local function getMetalCount(panels)
  local metalCount = 0
  for i = 1, #panels do
    if panels[i].color == 8 then
      metalCount = metalCount + 1
    end
  end
  return metalCount
end

local function isNewChainLink(matchingPanels)
  return table.trueForAny(matchingPanels, function(panel)
    return panel.chaining
  end)
end

local function getOnScreenCount(stackHeight, panels)
  local count = 0
  for i = 1, #panels do
    if panels[i].row <= stackHeight then
      count = count + 1
    end
  end
  return count
end

function Stack:checkMatches()
  if self.do_countdown then
    return
  end

  local matchingPanels = self:getMatchingPanels()
  local comboSize = #matchingPanels

  if comboSize > 0 then
    local metalCount = getMetalCount(matchingPanels)
    local isChainLink = isNewChainLink(matchingPanels)
    if isChainLink then
      self:incrementChainCounter()
    end
    -- interrupt any ongoing manual raise
    self.manual_raise = false

    local attackGfxOrigin = self:applyMatchToPanels(matchingPanels, isChainLink, comboSize)
    local garbagePanels = self:getConnectedGarbagePanels(matchingPanels)
    local garbagePanelCountOnScreen = 0
    if #garbagePanels > 0 then
      garbagePanelCountOnScreen = getOnScreenCount(self.height, garbagePanels)
      local garbageMatchTime = self.FRAMECOUNTS.MATCH + self.FRAMECOUNTS.POP * (comboSize + garbagePanelCountOnScreen)
      self:matchGarbagePanels(garbagePanels, garbageMatchTime, isChainLink, garbagePanelCountOnScreen)
    end

    local preStopTime = self.FRAMECOUNTS.MATCH + self.FRAMECOUNTS.POP * (comboSize + garbagePanelCountOnScreen)
    self.pre_stop_time = math.max(self.pre_stop_time, preStopTime)
    self:awardStopTime(isChainLink, comboSize)

    if isChainLink or comboSize > 3 or metalCount > 0 then
      self:pushGarbage(attackGfxOrigin, isChainLink, comboSize, metalCount)
      self:queueAttackSoundEffect(isChainLink, self.chain_counter, comboSize, metalCount)
    end

    self.analytic:register_destroyed_panels(comboSize)
    self:updateScoreWithBonus(comboSize)
    self:enqueueCards(attackGfxOrigin, isChainLink, comboSize)
  end

  self:clearChainingFlags()
end

-- returns a table of panels that are forming matches on this frame
function Stack:getMatchingPanels()
  local panels = self.panels
  local candidatePanels = {}

  for row = 1, self.height do
    for col = 1, self.width do
      local panel = panels[row][col]
      if panel.stateChanged and panel:canMatch() then
        candidatePanels[#candidatePanels + 1] = panel
      end
    end
  end

  local matchingPanels = {}
  local verticallyConnected
  local horizontallyConnected
  local panel
  for i = 1, #candidatePanels do
    verticallyConnected = {}
    horizontallyConnected = {}
    -- check in all 4 directions until we found a panel of a different color
    -- below
    for row = candidatePanels[i].row - 1, 1, -1 do
      panel = panels[row][candidatePanels[i].column]
      if panel.color == candidatePanels[i].color and panel:canMatch() then
        verticallyConnected[#verticallyConnected + 1] = panel
      else
        break
      end
    end
    -- above
    for row = candidatePanels[i].row + 1, self.height do
      panel = panels[row][candidatePanels[i].column]
      if panel.color == candidatePanels[i].color and panel:canMatch() then
        verticallyConnected[#verticallyConnected + 1] = panel
      else
        break
      end
    end
    -- to the left
    for column = candidatePanels[i].column - 1, 1, -1 do
      panel = panels[candidatePanels[i].row][column]
      if panel.color == candidatePanels[i].color and panel:canMatch() then
        horizontallyConnected[#horizontallyConnected + 1] = panel
      else
        break
      end
    end
    -- to the right
    for column = candidatePanels[i].column + 1, self.width do
      panel = panels[candidatePanels[i].row][column]
      if panel.color == candidatePanels[i].color and panel:canMatch() then
        horizontallyConnected[#horizontallyConnected + 1] = panel
      else
        break
      end
    end

    if (#verticallyConnected >= 2 or #horizontallyConnected >= 2) and not candidatePanels[i].matching then
      matchingPanels[#matchingPanels + 1] = candidatePanels[i]
      candidatePanels[i].matching = true
    end

    if #verticallyConnected >= 2 then
      -- vertical match
      for j = 1, #verticallyConnected do
        if not verticallyConnected[j].matching then
          verticallyConnected[j].matching = true
          matchingPanels[#matchingPanels + 1] = verticallyConnected[j]
        end
      end
    end
    if #horizontallyConnected >= 2 then
      -- horizontal match
      for j = 1, #horizontallyConnected do
        if not horizontallyConnected[j].matching then
          horizontallyConnected[j].matching = true
          matchingPanels[#matchingPanels + 1] = horizontallyConnected[j]
        end
      end
    end
    
    -- Clear out the tables for the next iteration
    for k, _ in ipairs(verticallyConnected) do 
      verticallyConnected[k] = nil 
    end
    for k, _ in ipairs(horizontallyConnected) do 
      horizontallyConnected[k] = nil 
    end
  end

  for i = 1, #matchingPanels do
    if matchingPanels[i].state == "hovering" then
      -- hovering panels that match can never chain (see Panel.matchAnyway for an explanation)
      matchingPanels[i].chaining = false
    end
  end

  return matchingPanels
end

function Stack:incrementChainCounter()
  if self.chain_counter ~= 0 then
    self.chain_counter = self.chain_counter + 1
  else
    self.chain_counter = 2
  end
end

function Stack:applyMatchToPanels(matchingPanels, isChain, comboSize)
  matchingPanels = sortByPopOrder(matchingPanels, false)

  for i = 1, comboSize do
    matchingPanels[i]:match(isChain, i, comboSize)
  end

  local firstCellToPop = {row = matchingPanels[1].row, column = matchingPanels[1].column}

  return firstCellToPop
end

-- returns an integer indexed table of all garbage panels that are connected to the matching panels
-- effectively a more optimized version of the past flood queue approach
function Stack:getConnectedGarbagePanels(matchingPanels)
  local garbagePanels = {}
  local panelsToCheck = Queue()

  local function pushIfNotMatchingAlready(matchingPanel, panelToCheck, matchAll)
    if not panelToCheck.matching then
      if matchAll then
        panelToCheck.matchesMetal = true
        panelToCheck.matchesGarbage = true
      else
        panelToCheck.matchesMetal = matchingPanel.metal
        panelToCheck.matchesGarbage = not matchingPanel.metal
      end
      panelsToCheck:push(panelToCheck)
    end
  end

  for i = 1, #matchingPanels do
    local panel = matchingPanels[i]
    -- Put all panels adjacent to the matching panel into the queue
    -- below
    if panel.row > 1 then
      local panelToCheck = self.panels[panel.row - 1][panel.column]
      pushIfNotMatchingAlready(panel, panelToCheck, true)
    end
    -- above
    if panel.row < #self.panels then
      local panelToCheck = self.panels[panel.row + 1][panel.column]
      pushIfNotMatchingAlready(panel, panelToCheck, true)
    end
    -- to the left
    if panel.column > 1 then
      local panelToCheck = self.panels[panel.row][panel.column - 1]
      pushIfNotMatchingAlready(panel, panelToCheck, true)
    end
    -- to the right
    if panel.column < self.width then
      local panelToCheck = self.panels[panel.row][panel.column + 1]
      pushIfNotMatchingAlready(panel, panelToCheck, true)
    end
  end

  -- any panel in panelsToCheck is guaranteed to be adjacent to a panel that is already matching
  while panelsToCheck:len() > 0 do
    local panel = panelsToCheck:pop()
    -- avoid rechecking a panel already matched
    if not panel.matching then
      if panel.isGarbage and panel.state == "normal" then
        if (panel.metal and panel.matchesMetal) or (not panel.metal and panel.matchesGarbage) then
          -- if a panel is adjacent to a matching non-garbage panel or a matching garbage panel of the same type, 
          -- it should match too
          panel.matching = true
          garbagePanels[#garbagePanels + 1] = panel

          -- additionally all non-matching panels adjacent to the new garbage panel get added to the queue
          -- pushIfNotMatchingAlready sets a flag which garbage type can match
          if panel.row > 1 then
            local panelToCheck = self.panels[panel.row - 1][panel.column]
            pushIfNotMatchingAlready(panel, panelToCheck)
          end

          if panel.row < #self.panels then
            local panelToCheck = self.panels[panel.row + 1][panel.column]
            pushIfNotMatchingAlready(panel, panelToCheck)
          end

          if panel.column > 1 then
            local panelToCheck = self.panels[panel.row][panel.column - 1]
            pushIfNotMatchingAlready(panel, panelToCheck)
          end

          if panel.column < self.width then
            local panelToCheck = self.panels[panel.row][panel.column + 1]
            pushIfNotMatchingAlready(panel, panelToCheck)
          end
        end
      end
    end
    -- repeat until we can no longer add new panels to the queue because all adjacent panels to our matching ones
    -- are either matching already or non-garbage panels or garbage panels of the other type
  end

  return garbagePanels
end

function Stack:matchGarbagePanels(garbagePanels, garbageMatchTime, isChain, onScreenCount)
  garbagePanels = sortByPopOrder(garbagePanels, true)

  for i = 1, #garbagePanels do
    local panel = garbagePanels[i]
    panel.y_offset = panel.y_offset - 1
    panel.height = panel.height - 1
    panel.state = "matched"
    panel:setTimer(garbageMatchTime + 1)
    panel.initial_time = garbageMatchTime
    -- these two may end up with nonsense values for off-screen garbage but it doesn't matter
    panel.pop_time = self.FRAMECOUNTS.POP * (onScreenCount - i)
    panel.pop_index = math.min(i, 10)
  end

  self:convertGarbagePanels(isChain)
end

-- checks the stack for garbage panels that have a negative y offset and assigns them a color from the gpanel_buffer
function Stack:convertGarbagePanels(isChain)
  -- color assignments are done per row so we need to iterate the stack properly
  for row = 1, #self.panels do
    local garbagePanelRow = nil
    for column = 1, self.width do
      local panel = self.panels[row][column]
      if panel.y_offset == -1 and panel.color == 9 then
        -- the bottom row of the garbage piece is about to transform into panels
        if garbagePanelRow == nil then
          garbagePanelRow = self:getGarbagePanelRow()
        end
        panel.color = string.sub(garbagePanelRow, column, column) + 0
        if isChain then
          panel.chaining = true
        end
      end
    end
  end
end

function Stack:refillGarbagePanelBuffer()
  local garbagePanels = PanelGenerator.makeGarbagePanels(self.match.seed + self.garbageGenCount, self.NCOLORS, self.gpanel_buffer,
                                                         self.match.mode, self.level)
  self.gpanel_buffer = self.gpanel_buffer .. garbagePanels
  logger.debug("Generating garbage with seed: " .. self.match.seed + self.garbageGenCount .. " buffer: " .. self.gpanel_buffer)
  self.garbageGenCount = self.garbageGenCount + 1
end

function Stack:getGarbagePanelRow()
  if string.len(self.gpanel_buffer) <= 10 * self.width then
    self:refillGarbagePanelBuffer()
  end
  local garbagePanelRow = string.sub(self.gpanel_buffer, 1, 6)
  self.gpanel_buffer = string.sub(self.gpanel_buffer, 7)
  return garbagePanelRow
end

function Stack:pushGarbage(coordinate, isChain, comboSize, metalCount)
  for i = 3, metalCount do
    if self.garbageTarget and self.telegraph then
      self.telegraph:push({width = 6, height = 1, isMetal = true, isChain = false}, coordinate.column, coordinate.row, self.clock)
    end
    self:recordComboHistory(self.clock, 6, 1, true)
    self.analytic:registerShock()
  end

  local combo_pieces = combo_garbage[comboSize]
  for i = 1, #combo_pieces do
    if self.garbageTarget and self.telegraph then
      -- Give out combo garbage based on the lookup table, even if we already made shock garbage,
      self.telegraph:push({width = combo_pieces[i], height = 1, isMetal = false, isChain = false}, coordinate.column, coordinate.row,
                          self.clock)
    end
    self:recordComboHistory(self.clock, combo_pieces[i], 1, false)
  end

  if isChain then
    if self.garbageTarget and self.telegraph then
      self.telegraph:push({width = 6, height = self.chain_counter - 1, isMetal = false, isChain = true}, coordinate.column, coordinate.row,
                          self.clock)
    end
    self:recordChainHistory()
  end
end

function Stack:recordComboHistory(time, width, height, metal)
  if self.combos[time] == nil then
    self.combos[time] = {}
  end

  self.combos[time][#self.combos[time] + 1] = {width = width, height = height, metal = metal}
end

function Stack:recordChainHistory()
  if self.chain_counter == 2 then
    self.currentChainStartFrame = self.clock
    self.chains[self.currentChainStartFrame] = {starts = {}}
  end
  local currentChainData = self.chains[self.currentChainStartFrame]
  currentChainData.size = self.chain_counter
  currentChainData.starts[#currentChainData.starts + 1] = self.clock
end

function Stack:awardStopTime(isChain, comboSize)
  if comboSize > 3 or isChain then
    local stopTime
    if self.panels_in_top_row and isChain then
      if self.level then
        local length = (self.chain_counter > 4) and 6 or self.chain_counter
        stopTime = -8 * self.level + 168 + (length - 1) * (-2 * self.level + 22)
      else
        stopTime = stop_time_danger[self.difficulty]
      end
    elseif self.panels_in_top_row then
      if self.level then
        local length = (comboSize < 9) and 2 or 3
        stopTime = self.chain_coefficient * length + self.chain_constant
      else
        stopTime = stop_time_danger[self.difficulty]
      end
    elseif isChain then
      if self.level then
        local length = math.min(self.chain_counter, 13)
        stopTime = self.chain_coefficient * length + self.chain_constant
      else
        stopTime = stop_time_chain[self.difficulty]
      end
    else
      if self.level then
        stopTime = self.combo_coefficient * comboSize + self.combo_constant
      else
        stopTime = stop_time_combo[self.difficulty]
      end
    end
    self.stop_time = math.max(self.stop_time, stopTime)
  end
end

function Stack:queueAttackSoundEffect(isChainLink, chainSize, comboSize, metalCount)
  if self:shouldChangeSoundEffects() then
    self.combo_chain_play = Stack.attackSoundInfoForMatch(isChainLink, chainSize, comboSize, metalCount)
  end
end

function Stack.attackSoundInfoForMatch(isChainLink, chainSize, comboSize, metalCount)
  if metalCount > 0 then
    -- override SFX with shock sound
    return {type = e_chain_or_combo.shock, size = metalCount}
  elseif isChainLink then
    return {type = e_chain_or_combo.chain, size = chainSize}
  elseif comboSize > 3 then
    return {type = e_chain_or_combo.combo, size = comboSize}
  end
  return nil
end

function Stack:enqueueCards(attackGfxOrigin, isChainLink, comboSize)
  if comboSize > 3 and isChainLink then
    -- we did a combo AND a chain; cards should not overlap so offset the attack origin to one row above for the chain
    self:enqueue_card(false, attackGfxOrigin.column, attackGfxOrigin.row, comboSize)
    self:enqueue_card(true, attackGfxOrigin.column, attackGfxOrigin.row + 1, self.chain_counter)
  elseif comboSize > 3 then
    -- only a combo
    self:enqueue_card(false, attackGfxOrigin.column, attackGfxOrigin.row, comboSize)
  elseif isChainLink then
    -- only a chain
    self:enqueue_card(true, attackGfxOrigin.column, attackGfxOrigin.row, self.chain_counter)
  end
end

-- awards bonus score for chains/combos
-- always call after the logic for incrementing the chain counter
function Stack:updateScoreWithBonus(comboSize)
  -- don't check isChain for this!
  -- needs to be outside of chaining to reproduce matches during a chain giving the same score as the chain link
  self:updateScoreWithChain()

  self:updateScoreWithCombo(comboSize)
end

function Stack:updateScoreWithCombo(comboSize)
  if comboSize > 3 then
    if (score_mode == SCOREMODE_TA) then
      self.score = self.score + score_combo_TA[math.min(30, comboSize)]
    elseif (score_mode == SCOREMODE_PDP64) then
      if (comboSize < 41) then
        self.score = self.score + score_combo_PdP64[comboSize]
      else
        self.score = self.score + 20400 + ((comboSize - 40) * 800)
      end
    end
  end
end

function Stack:updateScoreWithChain()
  local chain_bonus = self.chain_counter
  if (score_mode == SCOREMODE_TA) then
    if (self.chain_counter > 13) then
      chain_bonus = 0
    end
    self.score = self.score + score_chain_TA[chain_bonus]
  end
end

function Stack:clearChainingFlags()
  for row = 1, self.height do
    for column = 1, self.width do
      local panel = self.panels[row][column]
      -- if a chaining panel wasn't matched but was eligible, we have to remove its chain flag
      if not panel.matching and panel.chaining and not panel.matchAnyway and panel:canMatch() then
        if row > 1 then
          -- no swapping panel below so this panel loses its chain flag
          if self.panels[row - 1][column].state ~= "swapping" then
            panel.chaining = nil
          end
          -- a panel landed on the bottom row, so it surely loses its chain flag.
        else
          panel.chaining = nil
        end
      end
    end
  end
end