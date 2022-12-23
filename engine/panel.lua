-- Represents an individual panel in the stack
Panel =
class(
  function(p, id, row, column)
    p:clear()
    p.id = id
    p.row = row
    p.column = column
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
  self.type = nil
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
  self.changedState = false
end

function Panel.update(self, panels)
  if self.stateChanged then
    self.stateChanged = false
  end

  local panelBelow = panels[self.row - 1][self.column]

  if panelBelow and panelBelow.stateChanged then
    self:panelBelowChanged(panelBelow)
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

function Panel.panelBelowChanged(self, panelBelow)
  if self.state == Panel.states.normal then
    if panelBelow.type == Panel.types.empty then
      self:enterHoverState()
    end
  end
end

function Panel.enterHoverState(self)

end

-- panels in these states automatically transform when the timer reaches 0
local timerBasedStates = {Panel.states.swapping, Panel.states.hovering, Panel.states.landing, Panel.states.matched, Panel.states.popping, Panel.states.popped}

function Panel.runStateAction(self, panels)
  if table.contains(timerBasedStates, self.state) then
    -- decrement timer
    if self.timer and self.timer > 0 then
      self.timer = self.timer - 1
      if self.timer == 0 then
        self:timerRanOut()
      end
    end
  elseif self.state == Panel.states.falling then
    
    self.stateChanged = true
  end
end

function Panel.timerRanOut(self)
  self.stateChanged = true
end