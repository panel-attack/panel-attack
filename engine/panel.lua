-- clears information relating to state, matches and various stuff
-- a true argument must be supplied to clear the chaining flag as well
local function clear_flags(panel, clearChaining)
  -- determines what can happen with this panel
  -- or what will happen with it if nothing else happens with it
  -- in normal state normally nothing happens until you touch it or its surroundings
  panel.state = Panel.states.normal

  -- combo fields
  -- index compared against size determines the pop timing
  panel.combo_index = nil
  -- also used for popFX
  panel.combo_size = nil

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
    local metatable = getmetatable(p)
    metatable.__tostring = function(panel)
      return "row:"..panel.row..",col:"..panel.column..",color:"..panel.color..",state:"..panel.state..",timer:"..panel.timer
    end
    setmetatable(p, metatable)
    clear(p, true, true)
    p.id = id
    p.row = row
    p.column = column
    p.frameTimes = frameTimes
  end
)

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

-- the panel enters hover state
-- hover state is the most complex in terms of different timers and garbage vs non-garbage
-- it also propagates chain state
local function enterHoverState(panel, panelBelow)
  if panel.isGarbage then
    -- this is the hover enter after garbage match that converts the garbage panel into a regular panel
    -- clear resets its garbage flag to false, turning it into a normal panel!
    clear(panel, false, false)
    panel.chaining = true
    panel.timer = panel.frameTimes.GPHOVER
    panel.fell_from_garbage = 12
    panel.state = "hovering"
    panel.propagatesChaining = true
  else
    local hoverTime = nil
    if panel.state == "falling" then
      -- falling panels inherit the hover time from the panel below
      hoverTime = panelBelow.timer
    elseif panel.state == "swapping" then
      -- panels coming out of a swap always receive full hovertime
      -- even when swapped on top of another hovering panel
      hoverTime = panel.frameTimes.HOVER
    elseif panel.state == "normal"
        or panel.state == "landing" then
      -- normal panels inherit the hover time from the panel below
      if panelBelow.color ~= 0 then
        if panelBelow.state == "swapping"
          and panelBelow.propagatesChaining then
          -- if the panel below is swapping but propagates chaining due to a pop further below,
          --  the hovertime is the sum of remaining swap time and max hover time
          hoverTime = panelBelow.timer + panel.frameTimes.HOVER
        else
          hoverTime = panelBelow.timer
        end
      else
      -- if the panel below does not have a color, full hover time is given
        hoverTime = panel.frameTimes.HOVER
      end
    else
      error("Panel in state " .. panel.state .. " is trying to hover")
    end

    clear_flags(panel, false)
    panel.state = "hovering"
    panel.chaining = panel.chaining or panelBelow.propagatesChaining
    panel.propagatesChaining = panelBelow.propagatesChaining

    panel.timer = hoverTime
  end

  panel.stateChanged = true
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
  if panel.isGarbage then
    panel.state = "normal"
    panel:onGarbageLand()
  else
    if panel.state == "falling" then
      -- don't alert the stack on 0 height falls
      panel:onLand()
    end
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

-- gets the table holding the information and functions of the state the panel is in
local function getStateTable(panel)
  if panel.state == "normal" then
    return normalState
  elseif panel.state == "swapping" then
    return swappingState
  elseif panel.state == "matched" then
    return matchedState
  elseif panel.state == "popping" then
    return poppingState
  elseif panel.state == "popped" then
    return poppedState
  elseif panel.state == "hovering" then
    return hoverState
  elseif panel.state == "falling" then
    return fallingState
  elseif panel.state == "landing" then
    return landingState
  elseif panel.state == "dimmed" then
    return dimmedState
  elseif panel.state == "dead" then
    return deadState
  end
end

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
          enterHoverState(panel, panelBelow)
        elseif panelBelow.color == 0 and panelBelow.state == "normal" then
          if panelBelow.propagatesFalling then
            -- the panel below is empty because garbage below dropped
            -- in that case, skip the hover and fall immediately with the garbage
            fall(panel, panels)
          else
            enterHoverState(panel, panelBelow)
          end
        elseif panelBelow.queuedHover == true
        and panelBelow.propagatesChaining
        and panelBelow.state == "swapping" then
          enterHoverState(panel, panelBelow)
        end
        -- all other transformations from normal state are actively set by stack routines:
        -- swap
        -- checkMatches
        -- death
      end
    end
  end
end

swappingState.update = function(panel, panels)
  decrementTimer(panel)
  if panel.timer == 0 then
    if panel.queuedHover then
      enterHoverState(panel, getPanelBelow(panel, panels))
    else
      swappingState.changeState(panel, panels)
    end
  else
    swappingState.propagateChaining(panel, panels)
  end
end

swappingState.changeState = function(panel, panels)
  local function finishSwap()
    panel.state = "normal"
    panel.dont_swap = nil
    panel.isSwappingFromLeft = nil
    panel.stateChanged = true
  end

  local panelBelow = getPanelBelow(panel, panels)

  if panel.color == 0 then
    finishSwap()
  else
    if panelBelow and panelBelow.color == 0 then
      enterHoverState(panel, panelBelow)
    elseif panelBelow and panelBelow.state == "hovering" then
      enterHoverState(panel, panelBelow)
    else
      finishSwap()
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

matchedState.update = function(panel, panels)
  decrementTimer(panel)
  if panel.timer == 0 then
    matchedState.changeState(panel, panels)
  elseif panel.isGarbage and panel.timer == panel.pop_time then
    -- technically this is criminal and garbage panels should enter popping state too
    -- there is also little reason why garbage uses pop_time and normal panels timer
    panel:onPop()
  end
end

matchedState.changeState = function(panel, panels)
  if panel.isGarbage then
    if panel.y_offset == -1 then
      -- this means the matched garbage panel is part of the bottom row of the garbage
      -- so it will actually convert itself into a non-garbage panel and start to hover
      enterHoverState(panel)
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

poppingState.update = function(panel, panels)
  decrementTimer(panel)
  if panel.timer == 0 then
    poppingState.changeState(panel, panels)
  end
end

poppingState.changeState = function(panel, panels)
  panel:onPop()
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
  panel:onPopped()
  clear(panel, true, true)
  -- Flag so panels above can know whether they should be chaining or not
  panel.propagatesChaining = true
  panel.stateChanged = true
end

hoverState.update = function(panel, panels)
  decrementTimer(panel)
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
        enterHoverState(panel, panelBelow)
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

normalState.allowsMatch = true
swappingState.allowsMatch = false
matchedState.allowsMatch = false
poppingState.allowsMatch = false
poppedState.allowsMatch = false
hoverState.allowsMatch = false
fallingState.allowsMatch = false
landingState.allowsMatch = true
dimmedState.allowsMatch = false
deadState.allowsMatch = false

-- returns false if this panel can be matched
-- true if it cannot be matched
function Panel.canMatch(self)
  -- panels without colors can't match
  if self.color == 0 or self.color == 9 then
    return false
  else
    local state = getStateTable(self)
    return state.allowsMatch
  end
end

normalState.allowsSwap = true
swappingState.allowsSwap = true
matchedState.allowsSwap = false
poppingState.allowsSwap = false
poppedState.allowsSwap = false
hoverState.allowsSwap = false
fallingState.allowsSwap = true
landingState.allowsSwap = true
dimmedState.allowsSwap = false
deadState.allowsSwap = false

-- returns false if this panel is allowed to be swapped based on its color, state and dont_swap flag
-- true if it can not be swapped
function Panel.allowsSwap(self)
  -- the panel was flagged as unswappable inside of the swap function
  -- this flag should honestly go die and the connected checks should be part of the canSwap func if possible
  if self.dont_swap then
    return false
  -- can't swap garbage panels or even garbage to start with
  elseif self.isGarbage then
    return false
  else
    local state = getStateTable(self)
    return state.allowsSwap
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
  -- clear it here to not have to make an extra iteration through all panels
  self.matching = false
  self.matchesMetal = false
  self.matchesGarbage = false

  local stateTable = getStateTable(self)
  stateTable.update(self, panels)
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

  local coordinates1 = { row = panel1.row, column = panel1.column}
  local coordinates2 = { row = panel2.row, column = panel2.column}

  -- update the coordinates on the panels
  panel1.row = coordinates2.row
  panel1.column = coordinates2.column
  panel2.row = coordinates1.row
  panel2.column = coordinates1.column

  panels[coordinates1.row][coordinates1.column] = panel2
  panels[coordinates2.row][coordinates2.column] = panel1
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
  self:setTimer(self.frameTimes.MATCH + 1)
  if isChainLink then
    self.chaining = true
  end
  if self.fell_from_garbage then
    self.fell_from_garbage = nil
  end
  self.combo_index = comboIndex
  self.combo_size = comboSize
end