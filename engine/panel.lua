local function panelToString(panel)
  return "row:"..panel.row..",col:"..panel.column..",color:"..panel.color..",state:"..panel.state
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
    p:clear(true, true)
    p.id = id
    p.row = row
    p.column = column
    p.frameTimes = frameTimes
  end
)

Panel.types = { panel = 0, garbage = 1}
Panel.states = {
  normal = 0,
  swapping = 1,
  matched = 2,
  popping = 3,
  popped = 4,
  hovering = 5,
  falling = 6,
  landing = 7,
  dimmed = 8,
  dead = 9
}

-- all possible states a panel can have
-- the state tables provide functions that describe their state transformations
-- the state tables provide booleans that describe which actions are possible in their state
-- the state table of a panel can be acquired via Panel:getStateTable()
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

local function getPanelBelow(panel, panels)
  if panel.row <= 1 then
    return nil
  else
    return panels[panel.row - 1][panel.column]
  end
end

normalState.changeState = function(panel, panels)
  local panelBelow = getPanelBelow(panel, panels)

  if panel.type == Panel.types.panel
    and panel.color ~= 0 then
    if panelBelow and panelBelow.stateChanged then
      if panelBelow.state == Panel.states.hovering then
        panel:enterHoverState(panelBelow)
        panel.stateChanged = true
      elseif panelBelow.state == Panel.states.swapping
        and panelBelow.queuedHover == true
        and panelBelow.propagatesChaining then
        panel:enterHoverState(panelBelow)
      elseif panelBelow.color == 0 and panelBelow.state == Panel.states.normal then
        if panelBelow.propagatesFalling then
          -- the panel below is empty because garbage below dropped
          -- in that case, skip the hover and fall immediately with the garbage
          panel:fall(panels)
        else
          panel:enterHoverState(panelBelow)
        end
      end
      -- all other transformations from normal state are actively set by stack routines:
      -- swap
      -- checkMatches
      -- death
    end
  elseif panel.type == Panel.types.garbage then
    if not panel:supportedFromBelow(panels) then
      panel:fall(panels)
    end
  end
end

swappingState.changeState = function(panel, panels)
  local panelBelow = getPanelBelow(panel, panels)

  if panelBelow and panelBelow.color == 0 then
    panel:enterHoverState(panelBelow)
  elseif panelBelow and panelBelow.state == Panel.states.hovering then
    panel:enterHoverState(panelBelow)
  else
    panel.state = Panel.states.normal
    panel.dont_swap = nil
    panel.isSwappingFromLeft = nil
    panel.stateChanged = true
  end
end

-- if a panel exits popped state while there is swapping panel above, 
-- the panels above the swapping panel should still get chaining state and start to hover immediately
swappingState.propagateChaining = function(panel, panels)
  local panelBelow = getPanelBelow(panel, panels)

  if panelBelow and panelBelow.stateChanged and panelBelow.propagatesChaining then
    panel.queuedHover = true
    panel.stateChanged = true
    panel.propagatesChaining = true
  end
end

matchedState.changeState = function(panel, panels)
  if panel.type == Panel.types.panel then
    -- This panel's match just finished the whole flashing and looking distressed thing.
    -- It is given a pop time based on its place in the match.
    panel.state = Panel.states.popping
    panel.timer = panel.combo_index * panel.frameTimes.POP
    panel.stateChanged = true
  elseif panel.type == Panel.types.garbage then
    panel:enterHoverState()
  end
end

poppingState.changeState = function(panel, panels)
  panel:onPop()
  -- If it is the last panel to pop, it has to skip popped state
  if panel.combo_size == panel.combo_index then
    poppedState.changeState(panel, panels)
  else
    panel.state = Panel.states.popped
    panel.timer = (panel.combo_size - panel.combo_index) * panel.frameTimes.POP
    panel.stateChanged = true
  end
end

poppedState.changeState = function(panel, panels)
  -- It's time for this panel
  -- to be gone forever :'(
  panel:onPopped()
  panel:clear(true, true)
  -- Flag so panels above can know whether they should be chaining or not
  panel.propagatesChaining = true
  panel.stateChanged = true
end

hoverState.changeState = function(panel, panels)
  local panelBelow = getPanelBelow(panel, panels)

  if panelBelow then
    if panelBelow.state == Panel.states.hovering then
      -- if the panel below is hovering as well, always match its hovertime
      panel.timer = panelBelow.timer
    elseif panelBelow.color ~= 0 then
      -- if the panel below is not hovering and not empty, we land (commonly happens for panels transformed from garbage)
      panel:land()
    else
      -- This panel is no longer hovering.
      -- it will immediately commence to fall
      panel:fall(panels)
    end
  else
    error("Hovering panel in row 1 detected, commencing self-destruction sequence")
  end
end

fallingState.changeState = function(panel, panels)
  if panel.row == 1 then
    -- if it's on the bottom row, it should surely land
    panel:land()
  elseif panel:supportedFromBelow(panels) then
    if panel.type == Panel.types.garbage then
      panel:land()
    else
      local panelBelow = getPanelBelow(panel, panels)
      -- no need to nil check because the panel would always get landed at row 1 before getting here
      if panelBelow.state == Panel.states.hovering then
        panel:enterHoverState(panelBelow)
      else
        panel:land()
      end
    end
  else
    -- empty panel below
    panel:fall(panels)
  end

  -- stateChanged is set in the fall/land functions respectively
end


landingState.changeState = function(panel, panels)
  -- landing state only exists for the animation
  -- functionally it's just a normal state
  normalState.changeState(panel, panels)

  if not panel.stateChanged then
    panel.timer = panel.timer - 1
    if panel.timer == 0 then
      panel.state = Panel.states.normal
      panel.stateChanged = true
    end  
  end
end

dimmedState.changeState = function(panel, panels)
  if panel.row >= 1 then
    panel.state = Panel.states.normal
    panel.stateChanged = true
  end
end

deadState.changeState = function(panel, panels)
  error("There is no conclusion more natural than death")
end

-- exclude hover
normalState.excludeHover = false
swappingState.excludeHover = false
matchedState.excludeHover = true
poppingState.excludeHover = true
poppedState.excludeHover = true
hoverState.excludeHover = true
fallingState.excludeHover = true
landingState.excludeHover = false
dimmedState.excludeHover = true
deadState.excludeHover = true

function Panel.exclude_hover(self)
  if self.type == Panel.types.garbage then
    return true
  else
    local state = self:getStateTable()
    return state.excludeHover
  end
end

normalState.excludeMatch = false
swappingState.excludeMatch = true
matchedState.excludeMatch = true
poppingState.excludeMatch = true
poppedState.excludeMatch = true
hoverState.excludeMatch = false
fallingState.excludeMatch = true
landingState.excludeMatch = false
dimmedState.excludeMatch = true
deadState.excludeMatch = true

function Panel.exclude_match(self)
  -- panels without colors can't match
  if self.color == 0 or self.color == 9 then
    return true
  -- i'm still figuring out how exactly that match_anyway flag works
  elseif self.state == Panel.states.hovering and not self.match_anyway then
    return true
  else
    local state = self:getStateTable()
    return state.excludeMatch
  end
end

normalState.excludeSwap = false
swappingState.excludeSwap = false
matchedState.excludeSwap = true
poppingState.excludeSwap = true
poppedState.excludeSwap = true
hoverState.excludeSwap = true
fallingState.excludeSwap = false
landingState.excludeSwap = false
dimmedState.excludeSwap = true
deadState.excludeSwap = true

function Panel.exclude_swap(self)
  -- the panel was flagged as unswappable inside of the swap function
  -- this flag should honestly go die and the connected checks should be part of the canSwap func if possible
  if self.dont_swap then
    return true
  -- can't swap garbage panels or even garbage to start with
  elseif self.type == Panel.types.garbage then
    return true
  else
    local state = self:getStateTable()
    return state.excludeSwap
  end
end

-- Garbage blocks fall without a hover time
-- rather than starting to hover, panels on top should fall together with the garbage

normalState.propagatesFalling = true
swappingState.propagatesFalling = false
matchedState.propagatesFalling = false
poppingState.propagatesFalling = false
poppedState.propagatesFalling = false
hoverState.propagatesFalling = false
-- it's reasonable to assume this never
fallingState.propagatesFalling = true
landingState.propagatesFalling = true
dimmedState.propagatesFalling = false
deadState.propagatesFalling = false

function Panel.block_garbage_fall(self)
  if self.color == 0 then
    return true
  else
    local stateTable = self:getStateTable()
    return not stateTable.propagatesFalling
  end
end

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

function Panel.extendedRegularColorsArray()
  local result = Panel.regularColorsArray()
  result[#result + 1] = 7 -- squares
  return result
end

function Panel.allPossibleColorsArray()
  local result = Panel.extendedRegularColorsArray()
  result[#result + 1] = 8 -- shock
  result[#result + 1] = 9 -- colorless
  return result
end

-- Sets all variables to the default settings
function Panel.clear(self, clearChaining, clearColor)
  -- color 0 is an empty panel.
  -- colors 1-7 are normal colors, 8 is [!], 9 is garbage.
  if clearColor then
    self.color = 0
  end
  -- A panel's timer indicates for how many more frames it will:
  --  . be swapping
  --  . sit in the MATCHED state before being set POPPING
  --  . sit in the POPPING state before actually being POPPED
  --  . sit and be POPPED before disappearing for good
  --  . hover before FALLING
  -- depending on which one of these states the panel is in.
  self.timer = 0
  -- is_swapping is set if the panel is swapping.
  -- The panel's timer then counts down from 3 to 0,
  -- causing the swap to end 3 frames later.
  -- The timer is also used to offset the panel's
  -- position on the screen.

  self.initial_time = nil
  self.pop_time = nil
  self.pop_index = nil
  self.x_offset = nil
  self.y_offset = nil
  self.width = nil
  self.height = nil
  self.type = Panel.types.panel
  self.metal = nil
  self.shake_time = nil
  self.match_anyway = nil

  -- Also flags
  self:clear_flags(clearChaining)
end

function Panel.dangerous(self)
  if self.type == Panel.types.garbage then
    return self.state ~= Panel.states.falling
  else
    return self.color ~= 0
  end
end

function Panel.has_flags(self)
  return (self.state ~= Panel.states.normal) or self.isSwappingFromLeft or self.dont_swap or self.chaining
end

function Panel.clear_flags(self, clearChaining)
  self.combo_index = nil
  self.combo_size = nil
  self.chain_index = nil
  self.isSwappingFromLeft = nil
  self.dont_swap = nil
  if clearChaining then
    self.chaining = nil
  end
  -- Animation timer for "bounce" after falling from garbage.
  self.fell_from_garbage = nil
  self.state = Panel.states.normal
  self.queuedHover = nil
  self.stateChanged = false
  self.propagatesChaining = false
end

function Panel.update(self, panels)
  self.stateChanged = false
  self.propagatesChaining = false

  self:runStateAction(panels)
end

function Panel.startSwap(self, isSwappingFromLeft)
  local chaining = self.chaining
  self:clear_flags()
  self.stateChanged = true
  self.state = Panel.states.swapping
  self.chaining = chaining
  self.timer = 4
  self.isSwappingFromLeft = isSwappingFromLeft
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

function Panel.enterHoverState(self, panelBelow)
  if self.type == Panel.types.garbage then
    if self.y_offset == -1 then
      self:clear(false, false)
      self.chaining = true
      self.timer = self.frameTimes.GPHOVER
      self.fell_from_garbage = 12
      self.state = Panel.states.hovering
      self.propagatesChaining = true
    else
      self.state = Panel.states.normal
    end
  else
    local hoverTime = nil
    if self.state == Panel.states.falling then
      -- falling panels inherit the hover time from the panel below
      hoverTime = panelBelow.timer
    elseif self.state == Panel.states.swapping then
      -- panels coming out of a swap always receive full hovertime
      -- even when swapped on top of another hovering panel
      hoverTime = self.frameTimes.HOVER
    elseif self.state == Panel.states.normal
        or self.state == Panel.states.landing then
      -- normal panels inherit the hover time from the panel below
      if panelBelow.color ~= 0 then
        if panelBelow.state == Panel.states.swapping
          and panelBelow.propagatesChaining then
          -- if the panel below is swapping but propagates chaining due to a pop further below,
          --  the hovertime is the sum of remaining swap time and max hover time
          hoverTime = panelBelow.timer + self.frameTimes.HOVER
        else
          hoverTime = panelBelow.timer
        end
      else
      -- if the panel below does not have a color, full hover time is given
        hoverTime = self.frameTimes.HOVER
      end
    else
      error("Panel in state " .. self.state .. " is trying to hover")
    end

    self:clear_flags(false)
    self.state = Panel.states.hovering
    self.chaining = self.chaining or panelBelow.propagatesChaining
    self.propagatesChaining = panelBelow.propagatesChaining

    self.timer = hoverTime
  end

  self.stateChanged = true
end

-- panels in these states automatically transform when the timer reaches 0
local timerBasedStates = {Panel.states.swapping, Panel.states.hovering, Panel.states.matched, Panel.states.popping, Panel.states.popped}

function Panel.runStateAction(self, panels)
  -- reset all flags that only count for 1 frame to alert panels above of special behavior
  self.stateChanged = false
  self.propagatesChaining = false
  self.propagatesFalling = false

  if table.contains(timerBasedStates, self.state) then
    -- decrement timer
    if self.timer and self.timer > 0 then
      self.timer = self.timer - 1
      if self.timer == 0 then
        self:timerRanOut(panels)
      end
    end
  elseif self.state == Panel.states.falling
      or self.state == Panel.states.normal
      or self.state == Panel.states.landing then
    self:changeState(panels)
  end

  if self.state == Panel.states.swapping then
    swappingState.propagateChaining(self, panels)
  end
end

function Panel.timerRanOut(self, panels)
  if self.queuedHover then
    self:enterHoverState(getPanelBelow(self, panels))
  else
    self:changeState(panels)
  end
end

function Panel.changeState(self, panels)
  local stateTable = self:getStateTable()
  stateTable.changeState(self, panels)
end

function Panel.getStateTable(self)
  if self.state == Panel.states.normal then
    return normalState
  elseif self.state == Panel.states.swapping then
    return swappingState
  elseif self.state == Panel.states.matched then
    return matchedState
  elseif self.state == Panel.states.popping then
    return poppingState
  elseif self.state == Panel.states.popped then
    return poppedState
  elseif self.state == Panel.states.hovering then
    return hoverState
  elseif self.state == Panel.states.falling then
    return fallingState
  elseif self.state == Panel.states.landing then
    return landingState
  elseif self.state == Panel.states.dimmed then
    return dimmedState
  elseif self.state == Panel.states.dead then
    return deadState
  end
end

function Panel.supportedFromBelow(self, panels)
  if self.row <= 1 then
    return true
  end

  if self.type == Panel.types.garbage then
    -- check if it supported in any column over the entire width of the garbage
    for column = self.column - self.x_offset, self.column - self.x_offset + self.width - 1 do
      local panel = panels[self.row - 1][column]
      if panel.color ~= 0 then
        if panel.type == Panel.types.panel then
          return true
        else
          -- panels belonging to the same brick of garbage can't be considered as supporting
          if self.garbageId == panel.garbageId then
            -- unless the y offset is different
            return self.y_offset ~= panel.y_offset
          else
            return true
          end
        end
      end
    end
    return false
  else
    return panels[self.row - 1][self.column].color ~= 0
  end
end

function Panel.fall(self, panels)
  local panelBelow = getPanelBelow(self, panels)
  Panel.switch(self, panelBelow, panels)
  if self.type == Panel.types.garbage then
    -- panels above should fall immediately rather than starting to hover
    panelBelow.propagatesFalling = true
    panelBelow.stateChanged = true
  end
  if self.state ~= Panel.states.falling then
    self.state = Panel.states.falling
    self.timer = 0
    self.stateChanged = true
  end
end

function Panel.land(self)
  if self.type == self.types.panel then
    if self.state == Panel.states.falling then
      -- don't do stuff on 0 height falls
      self:onLand()
    end
    self.state = Panel.states.landing
      -- TODO Endaris: This timer is solely for animation, should put that elsewhere
    self.timer = 12
  elseif self.type == self.types.garbage then
    self.state = Panel.states.normal
    self:onGarbageLand()
  end
  self.stateChanged = true
end

function Panel.setTimer(self, frames)
  if self.state == Panel.states.matched then
    local x = 1+1
  end
  self.timer = frames
end

function Panel.decrementTimer(self)
  if self.timer > 0 then
    self.timer = self.timer - 1
  end
end