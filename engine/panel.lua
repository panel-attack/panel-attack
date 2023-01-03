-- Represents an individual panel in the stack
Panel =
class(
  function(p, id, row, column, frameTimes)
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

function normalState.changeState(panel, panels)
  local row = panel.row
  local col = panel.column
  local panelBelow = panels[row - 1][col]

  if panelBelow.changedState then
    if panelBelow.state == Panel.states.hovering then
      panel:enterHoverState(panelBelow)
    end
    -- all other transformations from normal state are actively set by stack routines for:
    -- swap
    -- checkMatches
    -- death
  end
end

function matchedState.changeState(panel, panels)
  -- This panel's match just finished the whole
  -- flashing and looking distressed thing.
  -- It is given a pop time based on its place
  -- in the match.
  panel.state = Panel.states.popping
  panel.timer = panel.combo_index * panel.framecounts.POP
end

function poppingState.changeState(panel, panels)

end

function poppedState.changeState(panel, panels)
  -- It's time for this panel
  -- to be gone forever :'(
    panel:clear()
    -- Flag as popped so panels above can know whether they should be chaining or not
    panel.justPopped = true
end

function hoverState.changeState(panel, panels)
  local row = panel.row
  local col = panel.column

  if panels[row - 1][col].state == Panel.states.hovering then
    -- if the panel below is hovering as well, always match its hovertime
    panel.timer = panels[row - 1][col].timer
  elseif panels[row - 1][col].color ~= 0 then
    -- if the panel below is not hovering and not empty, we land (commonly happens for panels transformed from garbage)
    panel.state = Panel.states.landing
    -- TODO Endaris: This timer is solely for animation, should put that elsewhere
    panel.timer = 12
    panel.changedState = true
  else
    -- This panel is no longer hovering.
    -- it will now fall without sitting around
    -- for any longer!
    panel.state = Panel.states.falling
    panels[row][col], panels[row - 1][col] = panels[row - 1][col], panels[row][col]
    panel.timer = 0
    panel.changedState = true
  end
end

function fallingState.changeState(panel, panels)
  local row = panel.row
  local col = panel.column
  local panelBelow = panels[row - 1][col]

  local function land()
    panel.state = Panel.states.landing
    panel.timer = 12
    if self:shouldChangeSoundEffects() then
      self.sfx_land = true
    end
  end

  local function fall()
    panels[row - 1][col], panels[row][col] = panels[row][col], panels[row - 1][col]
    panels[row][col]:clear()
  end

  if row == 1 then
    -- if it's on the bottom row, it should surely land
    land()
  elseif panels[row - 1][col].color ~= 0 then
    -- if there's a panel below, this panel's gonna land
    if panels[row - 1][col].state == Panel.states.falling then
      -- if the panel below had a falling state it should've fallen before
      error("Trying to fall down on a panel that is falling but didn't fell")
    else
      -- if it lands on a hovering panel, it inherits that panel's hover time instead
      if panels[row - 1][col].state == Panel.states.hovering then
        panel.state = Panel.states.hovering
        panel:enterHoverState(panelBelow)
      else
        land()
      end
    end
  else
    -- empty panel below
    fall()
  end
end

function landingState.changeState(panel, panels)
  panel.state = Panel.states.normal
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
  self.type = Panel.states.empty
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
  self.changedState = false
end

function Panel.update(self, panels)
  if self.stateChanged then
    self.stateChanged = false
  end

  self:runStateAction(panels)
end

function Panel.swapStarted(self, isSwappingFromLeft, newColumn)
  local chaining = self.chaining
  self:clear_flags()
  self.changedState = true
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
      self.timer = self.framecounts.GPHOVER
      self.fell_from_garbage = 12
    else
      self.state = Panel.states.normal
    end
  else
    local chaining = self.chaining
    self:clear_flags()
    self.state = Panel.states.hovering

    if panelBelow.type == Panel.types.empty then
      -- use max hover time
      self.timer = self.framecounts.HOVER
      self.chaining = chaining or panelBelow.justPopped
    else
      -- inherit hovertime from panel below
      self.timer = panelBelow.timer
      self.chaining = chaining
    end
  end
end

-- panels in these states automatically transform when the timer reaches 0
local timerBasedStates = {Panel.states.swapping, Panel.states.hovering, Panel.states.landing, Panel.states.matched, Panel.states.popping, Panel.states.popped}

function Panel.runStateAction(self, panels)
  self.stateChanged = false
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
  if self.type == Panel.types.garbage then
    -- check if it supported in any column over the entire width of the garbage
    for column = self.column, self.column + math.abs(self.x_offset) - 1 do
      if panels[self.row - 1][column].type ~= Panel.types.empty then
        return true
      end
    end
    return false
  else
    return panels[self.row - 1][self.column].type ~= Panel.types.empty
  end
end