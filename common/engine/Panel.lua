local class = require("common.lib.class")
local Signal = require("common.lib.signal")

-- clears information relating to state, matches and various stuff
-- a true argument must be supplied to clear the chaining flag as well
local function clear_flags(panel, clearChaining)
  -- determines what can happen with this panel
  -- or what will happen with it if nothing else happens with it
  -- in normal state normally nothing happens until you touch it or its surroundings
  panel.state = "normal"

  -- combo fields
  -- index compared against size determines the pop timing
  panel.combo_index = nil
  -- size compared against index determines the pop timing
  -- also used for determining popFX size
  panel.combo_size = nil

  -- number of the chain link if this panel got matched as part of a chain (I think)
  panel.chain_index = nil

  -- a direction indicator so we can check if swaps are possible with currently swapping panels
  -- ...and their surroundings
  panel.isSwappingFromLeft = nil
  -- if a panel is not supposed to be swappable it gets flagged down with this
  -- in the future this should probably get axed
  -- in about all scenarios swapping is forbidden cause a panel should hover after completing its swap
  -- or something like that...so we could check "queuedHover" instead (see below)
  panel.dont_swap = nil
  -- if a panel is swapping while the panel below finishes its popped state
  -- then this panel should be forced to hover after and the panels above as well
  -- indicated by this bool for itself and the panels above
  panel.queuedHover = nil

  -- this is optional to be cleared cause a lot of times we want to keep that information
  if clearChaining then
    panel.chaining = nil
  end
  -- Animation timer for "bounce" after falling from garbage.
  panel.fell_from_garbage = nil

  -- a convenience bool to know whether we should take a closer look at a panel this frame or not
  panel.stateChanged = false

  -- panels are updated bottom to top
  -- panels will check if this is set on the panel below to update their chaining state
  -- in combination with their own state
  panel.propagatesChaining = false

  -- a flag to determine if a hovering panel can be matched or not
  -- PA always checks matches and then updates everything at once
  -- that's a historical thing based on the original implementation
  -- if we first updated swapping panels, then checked matches and then updated all panels we might be able to get rid of this flag
  panel.matchAnyway = false
end

-- Sets all variables to the default settings
local function clear(panel, clearChaining, clearColor)
  -- color 0 is an empty panel.
  -- colors 1-7 are normal colors, 8 is [!], 9 is garbage.
  if clearColor then
    panel.color = 0
  end
  -- A panel's timer indicates for how many more frames it will:
  --  . be swapping
  --  . sit in the MATCHED state before being set POPPING
  --  . sit in the POPPING state before actually being POPPED
  --  . sit and be POPPED before disappearing for good
  --  . hover before FALLING
  -- depending on which one of these states the panel is in.
  panel.timer = 0
  -- is_swapping is set if the panel is swapping.
  -- The panel's timer then counts down from 3 to 0,
  -- causing the swap to end 3 frames later.
  -- The timer is also used to offset the panel's
  -- position on the screen.

  -- total time for the panel to go from being matched to converting into a non-garbage panel
  panel.initial_time = nil
  -- variables for handling pop FX
  panel.pop_time = nil
  panel.pop_index = nil

  -- garbage fields
  -- garbage is anchored at the bottom left corner with 0 for x and y offset
  panel.x_offset = nil
  panel.y_offset = nil
  -- total width and height of the garbage block
  panel.width = nil
  panel.height = nil
  -- may indicate shock garbage
  panel.metal = nil
  -- all panels in a garbage block have the same shake_time
  -- the shake_time gets cleared once the panel lands for the first time while on screen
  panel.shake_time = nil

  -- garbage panels and regular panels behave differently in about any scenario
  panel.isGarbage = false

  -- Also flags
  clear_flags(panel, clearChaining)
end


-- Represents an individual panel in the stack
Panel =
class(
  function(p, id, row, column, frameTimes)
    clear(p, true, true)
    p.id = id
    p.row = row
    p.column = column
    p.frameTimes = frameTimes
    Signal.turnIntoEmitter(p)
    p:createSignal("pop")
    p:createSignal("popped")
    p:createSignal("land")
  end
)

function Panel.__tostring(panel)
  return "row:"..panel.row..",col:"..panel.column..",color:"..panel.color..",state:"..panel.state..",timer:"..panel.timer
end

-- for external access
function Panel:clear(clearChaining, clearColor)
  clear(self, clearChaining, clearColor)
end

-- convenience function for getting panel in the row below if there is one
local function getPanelBelow(panel, panels)
  -- by definition, there is a row 0 that always has dimmed state panels
  -- dimmed state panels never use this function so we can omit the sanity check for performance
  -- if panel.row <= 1 then
  --   return nil
  -- else
    return panels[panel.row - 1][panel.column]
  -- end
end

-- returns true if there are "stable" panels below that keep it from falling down
local function supportedFromBelow(panel, panels)
  if panel.row <= 1 then
    return true
  end

  if panel.isGarbage then
    -- check if it supported in any column over the entire width of the garbage
    local startColumn = panel.column - panel.x_offset
    local endColumn = panel.column - panel.x_offset + panel.width - 1
    for column = startColumn, endColumn do
      local panelBelow = panels[panel.row - 1][column]
      if panelBelow.color ~= 0 then
        if panelBelow.isGarbage == false then
          return true
        else
          -- panels belonging to the same brick of garbage can't be considered as supporting
          if panel.garbageId == panelBelow.garbageId then
            -- unless the y offset is different
            return panel.y_offset ~= panelBelow.y_offset
          else
            return true
          end
        end
      end
    end
    return false
  else
    return panels[panel.row - 1][panel.column].color ~= 0
  end
end

-- switches the panel with the panel below and refreshes its state/flags
local function fall(panel, panels)
  local panelBelow = getPanelBelow(panel, panels)
  Panel.switch(panel, panelBelow, panels)
  -- panelBelow is now actually panelAbove
  if panel.isGarbage then
    -- panels above should fall immediately rather than starting to hover
    panelBelow.propagatesFalling = true
    panelBelow.stateChanged = true
  end
  if panel.state ~= "falling" then
    panel.state = "falling"
    panel.timer = 0
    panel.stateChanged = true
  end
end

-- makes the panel enter landing state and informs the stack about the event depending on whether it's garbage or not
local function land(panel)
  panel:emitSignal("land", panel)
  if panel.isGarbage then
    panel.state = "normal"
  else
    if panel.fell_from_garbage then
    -- terminate falling animation related stuff
      panel.fell_from_garbage = nil
    end
    panel.state = "landing"
      -- This timer is solely for animation, should probably put that elsewhere
    panel.timer = 12
  end
  panel.stateChanged = true
end

-- decrements the panels timer by 1 if it's above 0
local function decrementTimer(panel)
  if panel.timer > 0 then
    panel.timer = panel.timer - 1
  end
end

-- dedicated setter to troubleshoot timers constantly being overwritten by engine
function Panel.setTimer(self, frames)
  self.timer = frames
end

-- all possible states a panel can have
-- the state tables provide functions that describe their state update/transformations
-- the state tables provide booleans that describe which actions are possible in their state
-- the state table of a panel can be acquired via getStateTable(panel)
local normalState = {}
local swappingState = {}
local matchedState = {}
local poppingState = {}
local poppedState = {}
local hoverState = {}
local fallingState = {}
local landingState = {}
local dimmedState = {}
local deadState = {}

normalState.update = function(panel, panels)
  if panel.isGarbage then
    if not supportedFromBelow(panel, panels) then
      -- Garbage blocks fall without a hover time
      fall(panel, panels)
    end
  else
    -- empty panels can only be normal or swapping and don't passively enter other states
    if panel.color ~= 0 then
      local panelBelow = getPanelBelow(panel, panels)
      if panelBelow.stateChanged then
        if panelBelow.state == "hovering" then
          -- normal panels inherit the hover time from the panel below
          normalState.enterHoverState(panel, panelBelow, panelBelow.timer, panels)
        elseif panelBelow.color == 0 then
          if panelBelow.propagatesFalling then
            -- the panel below is empty because garbage below dropped
            -- in that case, skip the hover and fall immediately with the garbage
            fall(panel, panels)
          elseif panelBelow.state == "normal" then
            -- this is a normal fall, give full hover time
            normalState.enterHoverState(panel, panelBelow, panel.frameTimes.HOVER, panels)
          end
          -- else
          -- if the color 0 panel is not in normal state it means that it's swapping so we just do nothing until the swap finished and then run into the one above
        elseif panelBelow.queuedHover == true
          and panelBelow.propagatesChaining
          and panelBelow.state == "swapping" then
          -- if the panel(s) below is/are swapping but propagate(s) chaining due to a pop further below,
          -- the hovertime is the sum of remaining swap time(s) and the hover time of the first hovering panel below that we can find
          -- so first add up all the timers of swapping panels (usually 1)
          local hoverTime = panelBelow.timer
          local hoverPanel = getPanelBelow(panelBelow, panels)
          while hoverPanel and hoverPanel.state == "swapping" do
            -- for every swapping panel below we add up the remaining time of the swap
            -- this is how the old code did it, it is unclear whether that is actually correct behaviour confirmed in PdP/TA
            hoverTime = hoverTime + hoverPanel.timer
            hoverPanel = getPanelBelow(hoverPanel, panels)
          end
          -- and then add the timer of the hover panel
          -- we need to do it like this because the hover panel could hover with either normal hover time or garbage hover time
          if hoverPanel.state == "hovering" then
            hoverTime = hoverTime + hoverPanel.timer
          else
            -- there is no hovering panel below the the swapping panel
            -- meaning the swapping panel is directly above the panels that just popped, meaning no garbage is involved
            -- so we add regular hover time on top of swap time
            hoverTime = hoverTime + panel.frameTimes.HOVER
          end

          normalState.enterHoverState(panel, panelBelow, hoverTime, panels)
        end
        -- all other transformations from normal state are actively set by stack routines:
        -- swap
        -- checkMatches
        -- death
      end
    end
  end
end

normalState.enterHoverState = function(panel, panelBelow, hoverTime, panels)
  clear_flags(panel, false)
  panel.state = "hovering"
  if panelBelow.propagatesChaining then
    panel.propagatesChaining = true
    panel.chaining = true

    if panelBelow.color == 0
    or panelBelow.matchAnyway then
      -- panels above a match that just finished popping are matchable for 1 frame right after entering hoverstate
      panel.matchAnyway = true
      -- panels above cleared garbage are NOT
    else
      -- the simple propagation of matchAnyway may be inhibited by panels that are swapping or just finished their swap
      -- swapping panels will never get the matchAnyway flag
      -- so we drill down to the next panel below that definitely isn't considered swapping
      while panelBelow.state == "swapping"
      -- this second condition also applies to panels newly hovering over a garbage hover
      or (panelBelow.stateChanged and panelBelow.propagatesChaining and not panelBelow.matchAnyway and panelBelow.state == "hovering") do
        panelBelow = getPanelBelow(panelBelow, panels)
      end

      -- if the hover was initiated by a garbage hover, then the panel we should have arrived at, doesn't propagate chaining
      -- so we won't match anyway
      if panelBelow.propagatesChaining then
        panel.matchAnyway = panelBelow.color == 0 or panelBelow.matchAnyway
      end
    end
  end

  panel.timer = hoverTime
  panel.stateChanged = true
end

swappingState.update = function(panel, panels)
  decrementTimer(panel)
  if panel.timer == 0 then
    swappingState.changeState(panel, panels)
  else
    swappingState.propagateChaining(panel, panels)
  end
end

local function swappingStateFinishSwap(panel)
  panel.state = "normal"
  panel.dont_swap = nil
  panel.isSwappingFromLeft = nil
  panel.stateChanged = true
end

swappingState.changeState = function(panel, panels)

  local panelBelow = getPanelBelow(panel, panels)

  if panel.color == 0 then
    swappingStateFinishSwap(panel)
  else
    if panelBelow then
      if panelBelow.color == 0 or panelBelow.state == "hovering" or panel.queuedHover then
        swappingState.enterHoverState(panel, panelBelow)
      else
        swappingStateFinishSwap(panel)
      end
    else
      swappingStateFinishSwap(panel)
    end
  end
end

-- if a panel exits popped state while there is swapping panel above, 
-- the panels above the swapping panel should still get chaining state and start to hover immediately
swappingState.propagateChaining = function(panel, panels)
  local panelBelow = getPanelBelow(panel, panels)

  if panelBelow and panelBelow.stateChanged and panelBelow.propagatesChaining then
    panel.queuedHover = (panel.color ~= 0)
    panel.stateChanged = true
    panel.propagatesChaining = true
  end
end

swappingState.enterHoverState = function(panel, panelBelow)
  clear_flags(panel, false)
  panel.state = "hovering"
  -- swapping panels do NOT get the chaining flag if the panelBelow propagates chaining when the swap ends 
  --panel.chaining = panel.chaining
  -- all panels above may still get the chaining flag though if it is currently propagating
  panel.propagatesChaining = panelBelow.propagatesChaining
  -- panels that just finished their swap and enter hover may match on the next frame depending on the other hoverblocks below
  if panelBelow.color ~= 0 and panelBelow.state == "hovering" then
    panel.matchAnyway = panelBelow.matchAnyway
  else
    panel.matchAnyway = false
  end

  -- swapping panels always get full hover time
  panel.timer = panel.frameTimes.HOVER
  panel.stateChanged = true
end

matchedState.update = function(panel, panels)
  decrementTimer(panel)

  if panel.isGarbage and panel.timer == panel.pop_time then
    -- technically this is criminal and garbage panels should enter popping state too
    -- there is also little reason why garbage uses pop_time and normal panels timer
    panel:emitSignal("pop", panel)
  end
  if panel.timer == 0 then
    matchedState.changeState(panel, panels)
  end
end

matchedState.changeState = function(panel, panels)
  if panel.isGarbage then
    if panel.y_offset == -1 then
      -- this means the matched garbage panel is part of the bottom row of the garbage
      -- so it will actually convert itself into a non-garbage panel and start to hover
      matchedState.enterHoverState(panel)
    else
      -- upper rows of chain type garbage just return to being unmatched garbage
      panel.state = "normal"
    end
  else
    -- This panel's match just finished the whole flashing and looking distressed thing.
    -- It is given a pop time based on its place in the match.
    panel.state = "popping"
    panel.timer = panel.combo_index * panel.frameTimes.POP
    panel.stateChanged = true
  end
end

matchedState.enterHoverState = function(panel)
  -- this is the hover enter after garbage match that converts the garbage panel into a regular panel
  -- clear resets its garbage flag to false, turning it into a normal panel!
  clear(panel, false, false)
  panel.chaining = true
  panel.propagatesChaining = true
  if not panel.frameTimes.GARBAGE_HOVER then
    logger.info("Trying to set garbage hover on a panel not having garbage hover"
      .. "\n" .. table_to_string(panel))
  end
  panel.timer = panel.frameTimes.GARBAGE_HOVER
  panel.fell_from_garbage = 12
  panel.state = "hovering"
  panel.stateChanged = true
end

poppingState.update = function(panel, panels)
  decrementTimer(panel)
  if panel.timer == 0 then
    poppingState.changeState(panel, panels)
  end
end

poppingState.changeState = function(panel, panels)
  panel:emitSignal("pop", panel)
  -- If it is the last panel to pop, it has to skip popped state
  if panel.combo_size == panel.combo_index then
    poppedState.changeState(panel, panels)
  else
    panel.state = "popped"
    panel.timer = (panel.combo_size - panel.combo_index) * panel.frameTimes.POP
    panel.stateChanged = true
  end
end

poppedState.update = function(panel, panels)
  decrementTimer(panel)
  if panel.timer == 0 then
    poppedState.changeState(panel, panels)
  end
end

poppedState.changeState = function(panel, panels)
  -- It's time for this panel
  -- to be gone forever :'(
  panel:emitSignal("popped", panel)
  clear(panel, true, true)
  -- Flag so panels above can know whether they should be chaining or not
  panel.propagatesChaining = true
  panel.stateChanged = true
end

hoverState.update = function(panel, panels)
  decrementTimer(panel)
  if panel.matchAnyway then
    panel.matchAnyway = false
  end
  if panel.timer == 0 then
    hoverState.changeState(panel, panels)
  end

  if not panel.stateChanged and panel.fell_from_garbage then
    panel.fell_from_garbage = panel.fell_from_garbage - 1
  end
end

hoverState.changeState = function(panel, panels)
  local panelBelow = getPanelBelow(panel, panels)

  if panelBelow then
    if panelBelow.state == "hovering" then
      -- if the panel below is hovering as well, always match its hovertime
      panel.timer = panelBelow.timer
    elseif panelBelow.color ~= 0 then
      -- if the panel below is not hovering and not empty, we land (commonly happens for panels transformed from garbage)
      land(panel)
    else
      -- This panel is no longer hovering.
      -- it will immediately commence to fall
      fall(panel, panels)
    end
  else
    error("Hovering panel in row 1 detected, commencing self-destruction sequence")
  end
end

fallingState.update = function(panel, panels)
  if panel.row == 1 then
    -- if it's on the bottom row, it should surely land
    land(panel)
  elseif supportedFromBelow(panel, panels) then
    if panel.isGarbage then
      land(panel)
    else
      local panelBelow = getPanelBelow(panel, panels)
      -- no need to nil check because the panel would always get landed at row 1 before getting here
      if panelBelow.state == "hovering" then
        fallingState.enterHoverState(panel, panelBelow)
      else
        land(panel)
      end
    end
  else
    -- empty panel below
    fall(panel, panels)
  end

  -- stateChanged is set in the fall/land functions respectively
  if not panel.stateChanged and panel.fell_from_garbage then
    panel.fell_from_garbage = panel.fell_from_garbage - 1
  end
end

fallingState.enterHoverState = function(panel, panelBelow)
  clear_flags(panel, false)
  panel.state = "hovering"
  panel.stateChanged = true
  -- NOTE: specifically don't add "chaining" if we don't already have it
  -- since we didn't finish falling when the hover started
  panel.propagatesChaining = panelBelow.propagatesChaining
-- falling panels inherit the hover time from the panel below
  panel.timer = panelBelow.timer
end

landingState.update = function(panel, panels)
  normalState.update(panel, panels)

  if not panel.stateChanged then
    decrementTimer(panel)
    if panel.timer == 0 then
      landingState.changeState(panel)
    end
  end
end

landingState.changeState = function(panel)
  panel.state = "normal"
  panel.stateChanged = true
end

-- while these dimmedState functions should be correct, they are currently unused
-- new row generation and turning row 0 into row 1 is still handled by the stack as of now
dimmedState.update = function(panel, panels)
  if panel.row >= 1 then
    dimmedState.changeState(panel)
  end
end

dimmedState.changeState = function(panel)
  panel.state = "normal"
  panel.stateChanged = true
end

deadState.update = function(panel, panels)
  -- dead is dead
end

-- returns false if this panel can be swapped
-- true if it can not be swapped
function Panel.canSwap(self)
  -- the panel was flagged as unswappable inside of the swap function
  -- this flag should honestly go die and the connected checks should be part of the canSwap func if possible
  if self.dont_swap then
    return false
  -- can't swap garbage panels or even garbage to start with
  elseif self.isGarbage then
    return false
  else
    if self.state == "normal"
    or self.state == "swapping"
    or self.state == "falling"
    or self.state == "landing" then
      return true
    else
      -- matched, popping, popped, hovering, dimmed, dead
      return false
    end
  end
end

-- returns a table with panel color indices (used for puzzle color randomization)
function Panel.regularColorsArray()
  return {
    1, -- hearts
    2, -- circles
    3, -- triangles
    4, -- stars
    5, -- diamonds
    6, -- inverse triangles
  }
  -- Note see the methods below for square, shock, and colorless
end

-- returns a table with panel color indices (for puzzle color randomization)
function Panel.extendedRegularColorsArray()
  local result = Panel.regularColorsArray()
  result[#result + 1] = 7 -- squares
  return result
end

-- returns a table with panel color indices
function Panel.allPossibleColorsArray()
  local result = Panel.extendedRegularColorsArray()
  result[#result + 1] = 8 -- shock
  result[#result + 1] = 9 -- colorless
  return result
end

-- updates the panel for this frame based on its state and its surroundings
function Panel.update(self, panels)
  -- reset all flags that only count for 1 frame to alert panels above of special behavior
  self.stateChanged = false
  self.propagatesChaining = false
  self.propagatesFalling = false

  -- the flags for indicating a (possible garbage) match during the checkMatch process
  -- clear it here to not have to make an extra iteration through all panels during checkMatches
  self.matching = false
  self.matchesMetal = false
  self.matchesGarbage = false

  if self.state == "normal" then
    normalState.update(self, panels)
  elseif self.state == "swapping" then
    swappingState.update(self, panels)
  elseif self.state == "matched" then
    matchedState.update(self, panels)
  elseif self.state == "popping" then
    poppingState.update(self, panels)
  elseif self.state == "popped" then
    poppedState.update(self, panels)
  elseif self.state == "hovering" then
    hoverState.update(self, panels)
  elseif self.state == "falling" then
    fallingState.update(self, panels)
  elseif self.state == "landing" then
    landingState.update(self, panels)
  elseif self.state == "dimmed" then
    dimmedState.update(self, panels)
  elseif self.state == "dead" then
    deadState.update(self, panels)
  end
end

-- sets all necessary information to make the panel start swapping
function Panel.startSwap(self, isSwappingFromLeft)
  local chaining = self.chaining
  clear_flags(self)
  self.stateChanged = true
  self.state = "swapping"
  self.chaining = chaining
  self.timer = 4
  self.isSwappingFromLeft = isSwappingFromLeft
  if self.fell_from_garbage then
    -- fell_from_garbage is used for a bounce animation upon falling from matched garbage
    -- upon starting a swap, it should no longer animate
    self.fell_from_garbage = nil
  end
end

-- a switch is NOT a swap
-- a switch is the universal act of switching the positions of 2 adjacent panels on the board
-- this may be used for falling and also swapping interactions as a surefire way to update both panels
function Panel.switch(panel1, panel2, panels)
  -- confirm the panel positions are up to date
  assert(panel1.id == panels[panel1.row][panel1.column].id)
  assert(panel2.id == panels[panel2.row][panel2.column].id)

  -- confirm the panels are directly adjacent to each other
  local rowDiff = panel1.row - panel2.row
  local colDiff = panel1.column - panel2.column
  assert(math.abs(rowDiff + colDiff) == 1)

  local p1row = panel1.row
  local p1col = panel1.column

  -- update the coordinates on the panels
  panel1.row = panel2.row
  panel1.column = panel2.column
  panel2.row = p1row
  panel2.column = p1col

  panels[panel2.row][panel2.column] = panel2
  panels[panel1.row][panel1.column] = panel1
end

-- function used by the stack to determine whether there are panels in a row (read: the top row)
-- name is pretty misleading but I don't have a good idea rn
function Panel.dangerous(self)
  if self.isGarbage then
    return self.state ~= "falling"
  else
    return self.color ~= 0
  end
end

-- puts a non-garbage panel into the matched state
-- isChainLink: true if the match the panel is part of forms a new chain link
-- comboIndex: index for determining pop order among all panels of the match
-- comboSize: used for popFX and calculation of timers related to popping/popped state
--
-- garbagePanels have to process by row due to color generation and have their extra logic in checkMatches
function Panel:match(isChainLink, comboIndex, comboSize)
  self.state = "matched"
  -- +1 because match always occurs before the timer decrements on the frame
  self:setTimer(self.frameTimes.FLASH + self.frameTimes.FACE + 1)
  if isChainLink then
    self.chaining = true
  end
  if self.fell_from_garbage then
    self.fell_from_garbage = nil
  end
  self.combo_index = comboIndex
  self.combo_size = comboSize
end

return Panel