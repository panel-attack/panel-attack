local function panelToString(panel)
  return "row:"..panel.row..",col:"..panel.column..",color:"..panel.color..",state:"..panel.state
end

-- Represents an individual panel in the stack
Panel =
class(
  function(p, id, row, column, frameTimes)
    local metatable = getmetatable(p)
    metatable.__tostring = function(panel)
      return "row:"..panel.row..",col:"..panel.column..",color:"..panel.color..",state:"..panel.state
    end
    setmetatable(p, metatable)
    p:clear()
    p.id = id
    p.row = row
    p.column = column
    p.frameTimes = frameTimes
    
  end
)

Panel.types = { empty = 0, panel = 1, garbage = 2}
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

local normalState = {}
local swappingState = {}
local matchedState = {}
local poppingState = {}
local poppedState = {}
local hoverState = {}
local fallingState = {}
local landingState = {}
local dimmedState = {}

local function getPanelBelow(panel, panels)
  if panel.row <= 1 then
    return nil
  else
    return panels[panel.row - 1][panel.column]
  end
end

function normalState.changeState(panel, panels)
  local panelBelow = getPanelBelow(panel, panels)

  if panel.type == Panel.types.panel
    and panel.color ~= 0 then
    if panelBelow and panelBelow.stateChanged then
      if panelBelow.state == Panel.states.hovering then
        panel:enterHoverState(panelBelow)
        panel.stateChanged = true
      elseif panelBelow.state == Panel.states.swapping
        and panelBelow.queuedState ~= nil
        and panelBelow.queuedState.state == Panel.states.hovering
        and panelBelow.propagatesChaining then
        panel:enterHoverState(panelBelow)
      elseif panelBelow.color == 0 and panelBelow.state == Panel.states.normal then
        panel:enterHoverState(panelBelow)
        panel.stateChanged = true
      end
      -- all other transformations from normal state are actively set by stack routines:
      -- swap
      -- checkMatches
      -- death
    end
  elseif panel.type == Panel.types.garbage then
    if not panel.supportedFromBelow(panels) then
      panel:fall(panels)
    end
  end
end

function swappingState.changeState(panel, panels)
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
function swappingState.propagateChaining(panel, panels)
  local panelBelow = getPanelBelow(panel, panels)

  if panelBelow and panelBelow.stateChanged and panelBelow.propagatesChaining then
    panel.queuedState = { state = Panel.states.hovering, timer = panel.frameTimes.HOVER}
    panel.stateChanged = true
    panel.propagatesChaining = true
  end
end

function matchedState.changeState(panel, panels)
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

function poppingState.changeState(panel, panels)
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

function poppedState.changeState(panel, panels)
  -- It's time for this panel
  -- to be gone forever :'(
    panel:onPopped()
    panel:clear()
    -- Flag as popped so panels above can know whether they should be chaining or not
    panel.propagateChaining = true
    panel.stateChanged = true
  end

function hoverState.changeState(panel, panels)
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

function fallingState.changeState(panel, panels)
  if panel.row == 1 then
    -- if it's on the bottom row, it should surely land
    panel:land()
  elseif panel:supportedFromBelow(panels) then
    if panel.type == Panel.types.garbage then
      panel.state = Panel.states.normal
      panel.stateChanged = true
    elseif panel.color ~= 0 then
      local panelBelow = getPanelBelow(panel, panels)
      -- if there's a panel below, this panel's going to land
      -- no need to nil check as there was a row 1 check further up
      if panelBelow.state == Panel.states.falling  then
        -- if the panel below had a falling state it should've fallen before
        error("Trying to fall down into a panel that is falling but didn't fall")
      else
        -- if it lands on a hovering panel, it inherits that panel's hover time instead
        if panelBelow.state == Panel.states.hovering then
          panel:enterHoverState(panelBelow)
        else
          panel:land()
        end
      end
    end
  else
    -- empty panel below
    panel:fall(panels)
  end

  -- stateChanged is set in the fall/land functions respectively
end

function landingState.changeState(panel, panels)
  panel.state = Panel.states.normal
  panel.stateChanged = true
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
function Panel.clear(self)
  -- color 0 is an empty panel.
  -- colors 1-7 are normal colors, 8 is [!], 9 is garbage.
  self.color = 0
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
  self:clear_flags()
end

-- states:
-- swapping, matched, popping, popped, hovering,
-- falling, dimmed, landing, normal
-- flags:
-- from_left
-- dont_swap
-- chaining

local exclude_hover_set = {
  matched = true,
  popping = true,
  popped = true,
  hovering = true,
  falling = true
}
function Panel.exclude_hover(self)
  return exclude_hover_set[self.state] or self.type == Panel.types.garbage
end

local exclude_match_set = {
  swapping = true,
  matched = true,
  popping = true,
  popped = true,
  dimmed = true,
  falling = true
}
function Panel.exclude_match(self)
  return exclude_match_set[self.state] or self.color == 0 or self.color == 9 or
      (self.state == Panel.states.hovering and not self.match_anyway)
end

local exclude_swap_set = {
  matched = true,
  popping = true,
  popped = true,
  hovering = true,
  dimmed = true
}
function Panel.exclude_swap(self)
  return exclude_swap_set[self.state] or self.dont_swap or self.type == Panel.types.garbage
end

function Panel.support_garbage(self)
  return self.color ~= 0 or self.hovering
end

-- "Block garbage fall" means
-- "falling-ness should not propogate up through this panel"
-- We need this because garbage doesn't hover, it just falls
-- opportunistically.
local block_garbage_fall_set = {
  matched = true,
  popping = true,
  popped = true,
  hovering = true,
  swapping = true
}
function Panel.block_garbage_fall(self)
  return block_garbage_fall_set[self.state] or self.color == 0
end

function Panel.dangerous(self)
  return self.color ~= 0 and not (self.state == Panel.states.falling and self.type == Panel.types.garbage)
end

function Panel.has_flags(self)
  return (self.state ~= Panel.states.normal) or self.isSwappingFromLeft or self.dont_swap or self.chaining
end

function Panel.clear_flags(self)
  self.combo_index = nil
  self.combo_size = nil
  self.chain_index = nil
  self.isSwappingFromLeft = nil
  self.dont_swap = nil
  self.chaining = nil
  -- Animation timer for "bounce" after falling from garbage.
  self.fell_from_garbage = nil
  self.state = Panel.states.normal
  self.queuedState = nil
  self.stateChanged = false
  self.propagatesChaining = false
end

function Panel.update(self, panels)
  self.stateChanged = false
  self.propagatesChaining = false

  self:runStateAction(panels)
end

function Panel.startSwap(self, isSwappingFromLeft, newColumn)
  local chaining = self.chaining
  self:clear_flags()
  self.stateChanged = true
  self.state = Panel.states.swapping
  self.chaining = chaining
  self.timer = 4
  self.isSwappingFromLeft = isSwappingFromLeft
  self.column = newColumn
end

function Panel.enterHoverState(self, panelBelow)
  if self.type == Panel.types.garbage then
    if self.y_offset == -1 then
      local color = self.color
      self:clear()
      self.color = color
      self.chaining = true
      self.timer = self.frameTimes.GPHOVER
      self.fell_from_garbage = 12
      self.state = Panel.states.hovering
    else
      self.state = Panel.states.normal
    end
  else
    local chaining = self.chaining
    self:clear_flags()
    self.state = Panel.states.hovering
    self.chaining = chaining or panelBelow.propagatesChaining

    if panelBelow.color == 0 then
      -- use max hover time
      self.timer = self.frameTimes.HOVER
    else
      -- inherit hovertime from panel below
      if panelBelow.state == Panel.states.hovering then
        self.timer = panelBelow.timer
      else
        -- if the panel below is swapping, hover for the sum of remaining swaptime + hovertime
        self.timer = self.frameTimes.HOVER + panelBelow.timer -- -1? it's like that in the original code
      end
    end
  end

  self.propagatesChaining = panelBelow.propagatesChaining
  self.stateChanged = true
end

-- panels in these states automatically transform when the timer reaches 0
local timerBasedStates = {Panel.states.swapping, Panel.states.hovering, Panel.states.landing, Panel.states.matched, Panel.states.popping, Panel.states.popped}

function Panel.runStateAction(self, panels)
  self.stateChanged = false
  self.propagateChaining = false

  if self.state == Panel.states.matched then
    phi = 5
  end

  if table.contains(timerBasedStates, self.state) then
    -- decrement timer
    if self.timer and self.timer > 0 then
      self.timer = self.timer - 1
      if self.timer == 0 then
        self:timerRanOut(panels)
      end
    end
  elseif self.state == Panel.states.falling or self.state == Panel.states.normal then
    self:changeState(panels)
  end

  if self.state == Panel.states.swapping then
    swappingState.propagateChaining(self, panels)
  end
end

function Panel.timerRanOut(self, panels)
  if self.queuedState then
    self.state = self.queuedState.state
    self.timer = self.queuedState.timer
    self.stateChanged = true
  else
    self:changeState(panels)
  end
end

function Panel.changeState(self, panels)
  local stateTable = nil
  if self.state == Panel.states.normal then
    stateTable = normalState
  elseif self.state == Panel.states.swapping then
    stateTable = swappingState
  elseif self.state == Panel.states.matched then
    stateTable = matchedState
  elseif self.state == Panel.states.popping then
    stateTable = poppingState
  elseif self.state == Panel.states.popped then
    stateTable = poppedState
  elseif self.state == Panel.states.hovering then
    stateTable = hoverState
  elseif self.state == Panel.states.falling then
    stateTable = fallingState
  elseif self.state == Panel.states.landing then
    stateTable = landingState
  end

  stateTable.changeState(self, panels)
end

function Panel.supportedFromBelow(self, panels)
  if self.row == 1 then
    return true
  end

  if self.type == Panel.types.garbage then
    -- check if it supported in any column over the entire width of the garbage
    for column = self.column, self.column + math.abs(self.x_offset) - 1 do
      if panels[self.row - 1][column].color ~= 0 then
        return true
      end
    end
    return false
  else
    return panels[self.row - 1][self.column].color ~= 0
  end
end

function Panel.fall(self, panels)
  local row = self.row
  local col = self.column
  local panelBelow = getPanelBelow(self, panels)
  panels[row - 1][col], panels[row][col] = self, panelBelow
  self.row = row - 1
  panelBelow = row
  panels[row][col]:clear()
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