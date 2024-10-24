local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local PanelGenerator = require("common.engine.PanelGenerator")
local consts = require("common.engine.consts")
require("table.clear")

-- score lookup tables
local SCORE_COMBO_PdP64 = {} --size 40
local SCORE_COMBO_TA = {  0,    0,    0,   20,   30,
                         50,   60,   70,   80,  100,
                        140,  170,  210,  250,  290,
                        340,  390,  440,  490,  550,
                        610,  680,  750,  820,  900,
                        980, 1060, 1150, 1240, 1330, [0]=0}

local SCORE_CHAIN_TA = {  0,   50,   80,  150,  300,
                        400,  500,  700,  900, 1100,
                       1300, 1500, 1800, [0]=0}

local COMBO_GARBAGE = {{}, {}, {},
                  --  +4      +5     +6
                      {3},     {4},   {5},
                  --  +7      +8     +9
                      {6},   {3,4}, {4,4},
                  --  +10     +11    +12
                      {5,5}, {5,6}, {6,6},
                  --  +13         +14
                      {6,6,6},  {6,6,6,6},
                 [20]={6,6,6,6,6,6},
                 [27]={6,6,6,6,6,6,6,6}}
for i=1,72 do
  COMBO_GARBAGE[i] = COMBO_GARBAGE[i] or COMBO_GARBAGE[i-1]
end

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
  for _, panel in ipairs(matchingPanels) do
    if panel.chaining then
      return true
    end
  end

  return false
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

-- returns true if this panel can be matched
-- false if it cannot be matched
local function canMatch(panel)
  -- panels without colors can't match
  if panel.color == 0 or panel.color == 9 then
    return false
  else
    if panel.state == "normal"
      or panel.state == "landing"
      or (panel.matchAnyway and panel.state == "hovering")  then
      return true
    else
      -- swapping, matched, popping, popped, hover, falling, dimmed, dead
      return false
    end
  end
end

function Stack:checkMatches()
  if self.do_countdown then
    return
  end

  local matchingPanels = self:getMatchingPanels()
  local comboSize = #matchingPanels

  if comboSize > 0 then
    local frameConstants = self.levelData.frameConstants
    local metalCount = getMetalCount(matchingPanels)
    local isChainLink = isNewChainLink(matchingPanels)
    if isChainLink then
      self:incrementChainCounter()
    end
    -- interrupt any ongoing manual raise
    self.manual_raise = false

    local attackGfxOrigin = self:applyMatchToPanels(matchingPanels, isChainLink, comboSize)
    local garbagePanels = self:getConnectedGarbagePanels(matchingPanels)
    logger.debug("Matched " .. comboSize .. " panels, clearing " .. #garbagePanels .. " panels of garbage")
    local garbagePanelCountOnScreen = 0
    if #garbagePanels > 0 then
      garbagePanelCountOnScreen = getOnScreenCount(self.height, garbagePanels)
      local garbageMatchTime = frameConstants.FLASH + frameConstants.FACE + frameConstants.POP * (comboSize + garbagePanelCountOnScreen)
      self:matchGarbagePanels(garbagePanels, garbageMatchTime, isChainLink, garbagePanelCountOnScreen)
    end

    local preStopTime = frameConstants.FLASH + frameConstants.FACE + frameConstants.POP * (comboSize + garbagePanelCountOnScreen)
    self.pre_stop_time = math.max(self.pre_stop_time, preStopTime)
    self:awardStopTime(isChainLink, comboSize)

    if isChainLink or comboSize > 3 or metalCount > 0 then
      self:pushGarbage(attackGfxOrigin, isChainLink, comboSize, metalCount)
      self:queueAttackSoundEffect(isChainLink, self.chain_counter, comboSize, metalCount)
      self:emitSignal("attackSent", "attack")
    end

    self.analytic:register_destroyed_panels(comboSize)
    self:updateScoreWithBonus(comboSize)
    self:enqueueCards(attackGfxOrigin, isChainLink, comboSize)
  end

  self:clearChainingFlags()
end

local candidatePanels = table.new(144, 0)
local verticallyConnected = table.new(11, 0)
local horizontallyConnected = table.new(5, 0)

-- returns a table of panels that are forming matches on this frame
function Stack:getMatchingPanels()
  local matchingPanels = {}
  local panels = self.panels

  for row = 1, self.height do
    for col = 1, self.width do
      local panel = panels[row][col]
      if panel.stateChanged and canMatch(panel) then
        candidatePanels[#candidatePanels + 1] = panel
      end
    end
  end

  local panel
  for _, candidatePanel in ipairs(candidatePanels) do
    -- check in all 4 directions until we found a panel of a different color
    -- below
    for row = candidatePanel.row - 1, 1, -1 do
      panel = panels[row][candidatePanel.column]
      if panel.color == candidatePanel.color  and canMatch(panel) then
        verticallyConnected[#verticallyConnected + 1] = panel
      else
        break
      end
    end
    -- above
    for row = candidatePanel.row + 1, self.height do
      panel = panels[row][candidatePanel.column]
      if panel.color == candidatePanel.color  and canMatch(panel) then
        verticallyConnected[#verticallyConnected + 1] = panel
      else
        break
      end
    end
    -- to the left
    for column = candidatePanel.column - 1, 1, -1 do
      panel = panels[candidatePanel.row][column]
      if panel.color == candidatePanel.color  and canMatch(panel) then
        horizontallyConnected[#horizontallyConnected + 1] = panel
      else
        break
      end
    end
    -- to the right
    for column = candidatePanel.column + 1, self.width do
      panel = panels[candidatePanel.row][column]
      if panel.color == candidatePanel.color and canMatch(panel) then
        horizontallyConnected[#horizontallyConnected + 1] = panel
      else
        break
      end
    end

    if (#verticallyConnected >= 2 or #horizontallyConnected >= 2) and not candidatePanel.matching then
      matchingPanels[#matchingPanels + 1] = candidatePanel
      candidatePanel.matching = true
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
    table.clear(verticallyConnected)
    table.clear(horizontallyConnected)
  end

  table.clear(candidatePanels)

  for i = 1, #matchingPanels do
    if matchingPanels[i].state == "hovering" then
      -- hovering panels that match can never chain (see Panel.matchAnyway for an explanation)
      matchingPanels[i].chaining = nil
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
        -- We need to "OR" in these flags in case a different path caused a match too
        if matchingPanel.metal then
          panelToCheck.matchesMetal = true
        else
          panelToCheck.matchesGarbage = true
        end
      end

      -- We may add a panel multiple times but it will be "matching" after the first time and skip any work in the loop.
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

  if self:canPlaySfx() then
    SFX_garbage_match_play = true
  end
  
  for i = 1, #garbagePanels do
    local panel = garbagePanels[i]
    panel.y_offset = panel.y_offset - 1
    panel.height = panel.height - 1
    panel.state = "matched"
    panel:setTimer(garbageMatchTime + 1)
    panel.initial_time = garbageMatchTime
    -- these two may end up with nonsense values for off-screen garbage but it doesn't matter
    panel.pop_time = self.levelData.frameConstants.POP * (onScreenCount - i)
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
  PanelGenerator:setSeed(self.match.seed + self.garbageGenCount)
  -- privateGeneratePanels already appends to the existing self.gpanel_buffer
  local garbagePanels = PanelGenerator.privateGeneratePanels(20, self.width, self.levelData.colors, self.gpanel_buffer, not self.allowAdjacentColors)
  -- and then we append that result to the remaining buffer
  self.gpanel_buffer = self.gpanel_buffer .. garbagePanels
  -- that means the next 10 rows of garbage will use the same colors as the 10 rows after
  -- that's a bug but it cannot be fixed without breaking replays
  -- it is also hard to abuse as 
  -- a) players would need to accurately track the 10 row cycles
  -- b) "solve into the same thing" only applies to a limited degree:
  --   a garbage panel row of 123456 solves into 1234 for ====00 but into 3456 for 00====
  --   that means information may be incomplete and partial memorization may prove unreliable
  -- c) garbage panels change every (10 + n * 20 rows) with n>0 in ℕ 
  --    so the player needs to always survive 20 rows to start abusing
  --    and can then only abuse for every 10 rows out of 20
  -- overall it is to be expected that the strain of trying to memorize outweighs the gains
  -- this bug should be fixed with the next breaking change to the engine

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
  logger.debug("P" .. self.which .. "@" .. self.clock .. ": Pushing garbage for " .. (isChain and "chain" or "combo") .. " with " .. comboSize .. " panels")
  for i = 3, metalCount do
    self.outgoingGarbage:push({
      width = 6,
      height = 1,
      isMetal = true,
      isChain = false,
      frameEarned = self.clock,
      rowEarned = coordinate.row,
      colEarned = coordinate.column
    })
    self.analytic:registerShock()
  end

  local combo_pieces = COMBO_GARBAGE[comboSize]
  for i = 1, #combo_pieces do
    -- Give out combo garbage based on the lookup table, even if we already made shock garbage,
    self.outgoingGarbage:push({
      width = combo_pieces[i],
      height = 1,
      isMetal = false,
      isChain = false,
      frameEarned = self.clock,
      rowEarned = coordinate.row,
      colEarned = coordinate.column
    })
  end

  if isChain then
    local rowOffset = 0
    if #combo_pieces > 0 then
      -- If we did a combo also, we need to enqueue the attack graphic one row higher cause thats where the chain card will be.
      rowOffset = 1
    end
    self.outgoingGarbage:addChainLink(self.clock, coordinate.column, coordinate.row +  rowOffset)
  end
end

-- calculates the stoptime that would be awarded for a certain chain/combo based on the stack's settings
function Stack:calculateStopTime(comboSize, toppedOut, isChain, chainCounter)
  local stopTime = 0
  local stop = self.levelData.stop
  if comboSize > 3 or isChain then
    if toppedOut and isChain then
      if stop.formula == 1 then
        local length = (chainCounter > 4) and 6 or chainCounter
        stopTime = stop.dangerConstant + (length - 1) * stop.dangerCoefficient
      elseif stop.formula == 2 then
        stopTime = stop.dangerConstant
      end
    elseif toppedOut then
      if stop.formula == 1 then
        local length = (comboSize < 9) and 2 or 3
        stopTime = stop.coefficient * length + stop.chainConstant
      elseif stop.formula == 2 then
        stopTime = stop.dangerConstant
      end
    elseif isChain then
      if stop.formula == 1 then
        local length = math.min(chainCounter, 13)
        stopTime = stop.coefficient * length + stop.chainConstant
      elseif stop.formula == 2 then
        stopTime = stop.chainConstant
      end
    else
      if stop.formula == 1 then
        stopTime = stop.coefficient * comboSize + stop.comboConstant
      elseif stop.formula == 2 then
        stopTime = stop.comboConstant
      end
    end
  end

  return stopTime
end

function Stack:awardStopTime(isChain, comboSize)
  local stopTime = self:calculateStopTime(comboSize, self.panels_in_top_row, isChain, self.chain_counter)
  if stopTime > self.stop_time then
    self.stop_time = stopTime
  end
end

function Stack:queueAttackSoundEffect(isChainLink, chainSize, comboSize, metalCount)
  if self:canPlaySfx() then
    self.combo_chain_play = Stack.attackSoundInfoForMatch(isChainLink, chainSize, comboSize, metalCount)
  end
end

function Stack.attackSoundInfoForMatch(isChainLink, chainSize, comboSize, metalCount)
  if metalCount > 0 then
    -- override SFX with shock sound
    return {type = consts.ATTACK_TYPE.shock, size = metalCount}
  elseif isChainLink then
    return {type = consts.ATTACK_TYPE.chain, size = chainSize}
  elseif comboSize > 3 then
    return {type = consts.ATTACK_TYPE.combo, size = comboSize}
  end
  return nil
end

function Stack:enqueueCards(attackGfxOrigin, isChainLink, comboSize)
  if comboSize > 3 and isChainLink then
    -- we did a combo AND a chain; cards should not overlap so offset the chain card to one row above the combo card
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
    if (score_mode == consts.SCOREMODE_TA) then
      self.score = self.score + SCORE_COMBO_TA[math.min(30, comboSize)]
    elseif (score_mode == consts.SCOREMODE_PDP64) then
      if (comboSize < 41) then
        self.score = self.score + SCORE_COMBO_PdP64[comboSize]
      else
        self.score = self.score + 20400 + ((comboSize - 40) * 800)
      end
    end
  end
end

function Stack:updateScoreWithChain()
  local chain_bonus = self.chain_counter
  if (score_mode == consts.SCOREMODE_TA) then
    if (self.chain_counter > 13) then
      chain_bonus = 0
    end
    self.score = self.score + SCORE_CHAIN_TA[chain_bonus]
  end
end

function Stack:clearChainingFlags()
  for row = 1, self.height do
    for column = 1, self.width do
      local panel = self.panels[row][column]
      -- if a chaining panel wasn't matched but was eligible, we have to remove its chain flag
      if not panel.matching and panel.chaining and not panel.matchAnyway and (canMatch(panel) or panel.color == 9) then
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