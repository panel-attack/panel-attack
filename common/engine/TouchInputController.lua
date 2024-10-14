local logger = require("common.lib.logger")
local TouchDataEncoding = require("common.engine.TouchDataEncoding")
local util = require("common.lib.util")
local consts = require("common.engine.consts")
local class = require("common.lib.class")

local TOUCH_SWAP_COOLDOWN = 5  -- default number of cooldown frames between touch-input swaps, applied after the first 2 swaps after a touch is initiated, to prevent excessive or accidental stealths

-- An object that manages touches on the screen and translates them to swaps on a stack
TouchInputController =
  class(
  function(self, stack)
    self.stack = stack
    -- whether the stack (panels) are touched.  Still true if touch is dragged off the stack, but not released yet.
    self.touchingStack = false
    --if any is {row = 0, col = 0}, this is the equivalent if the variable being nil and not refering to any panel on the stack
    -- cell that is currently touched, used to determine touch events (initiate, hold/drag, release) and as input for the current frame
    self.touchedCell = {row = 0, col = 0}
    -- cell that was touched last frame, used to determine touch events (initiate, hold/drag, release)
    self.previousTouchedCell = {row = 0, col = 0}
    -- this is the destination column we will always be trying to swap toward. 
    -- Set to self.touchedCell.col or if that's 0, use self.previousTouchedCell.col, or if that's 0, use existing self.touchTargetColumn. 
    -- if target is reached by self.cur_col, set self.touchTargetColumn to 0.
    self.touchTargetColumn = 0
    -- origin of a failed swap due to the target panel being unswappable, leave the cursor here even if the touch is released.
    self.lingeringTouchCursor = {row = 0, col = 0}
    -- number of swaps that have been initiated since the last touch
    self.swapsThisTouch = 0
    -- if this is zero, a swap can happen.
    -- set to TOUCH_SWAP_COOLDOWN on each swap after the first. decrement by 1 each frame.
    self.touchSwapCooldownTimer = 0
  end
)

-- Interprets the current touch state and returns an encoded character for the raise and cursor state
function TouchInputController:encodedCharacterForCurrentTouchInput()
  local shouldRaise = false
  local rowTouched = 0
  local columnTouched = 0
  --we'll encode the touched panel and if raise is happening in a unicode character
  --only one touched panel is supported, no multitouch.
  local mouseX, mouseY = GAME:transform_coordinates(love.mouse.getPosition())
  if love.mouse.isDown(1) then
    --note: a stack is still "touchingStack" if we touched the stack, and have dragged the mouse or touch off the stack, until we lift the touch
    --check whether the mouse is over this stack
    if self:isMouseOverStack(mouseX, mouseY) then
      self.touchingStack = true
      rowTouched, columnTouched = self:touchedPanelCoordinate(mouseX, mouseY)
    elseif self.touchingStack then --we have touched the stack, and have moved the touch off the edge, without releasing
      --let's say we are still touching the panel we had touched last.
      rowTouched = self.touchedCell.row
      columnTouched = self.touchedCell.col
    elseif self.touchingRaise then
      --note: changed this to an elseif.  
      --This means we won't be able to press raise by accident if we dragged too far off the stack, into the raise button
      --but we also won't be able to input swaps and press raise at the same time, though the network protocol allows touching a panel and raising at the same time
      --Endaris has said we don't need to be able to swap and raise at the same time anyway though (swap suspends raise).
      shouldRaise = true
    else
      shouldRaise = false
    end
  else
    self.touchingStack = false
    shouldRaise = false
    rowTouched = 0
    columnTouched = 0
  end
  if love.mouse.isDown(2) then
    --if using right mouse button on the stack, we are inputting "raise"
    --also works if we have left mouse buttoned the stack, dragged off, are still holding left mouse button, and then also hold down right mouse button.
    if self.touchingStack or self:isMouseOverStack(mouseX, mouseY) then
      shouldRaise = true
    end
  end
  
  self.previousTouchedCell.row = self.touchedCell.row
  self.previousTouchedCell.col = self.touchedCell.col
  self.touchedCell.row = rowTouched
  self.touchedCell.col = columnTouched

  local cursorRow, cursorColumn = self:handleTouch()

  local result = TouchDataEncoding.touchDataToLatinString(shouldRaise, cursorRow, cursorColumn, self.stack.width)
  return result
end

function TouchInputController:isMouseOverStack(mouseX, mouseY)
  return 
    mouseX >= self.stack.panelOriginX * self.stack.gfxScale and mouseX <= (self.stack.panelOriginX + (self.stack.width * 16)) * self.stack.gfxScale and
    mouseY >= self.stack.panelOriginY * self.stack.gfxScale and mouseY <= (self.stack.panelOriginY + (self.stack.height* 16)) * self.stack.gfxScale
end

-- Returns the touched panel coordinate or nil if the stack isn't currently touched
function TouchInputController:touchedPanelCoordinate(mouseX, mouseY)
  local stackHeight = self.stack.height
  local stackWidth = self.stack.width
  local stackLeft = (self.stack.panelOriginX * self.stack.gfxScale)
  local stackTop = (self.stack.panelOriginY * self.stack.gfxScale)
  local panelSize = 16 * self.stack.gfxScale
  local stackRight = stackLeft + stackWidth * panelSize
  local stackBottom = stackTop + stackHeight * panelSize

  if mouseX < stackLeft then
    return 0, 0
  end
  if mouseY < stackTop then
    return 0, 0
  end
  if mouseX >= stackRight then
    return 0, 0
  end
  if mouseY >= stackBottom then
    return 0, 0
  end

  local displacement =  self.stack.displacement * self.stack.gfxScale
  local row = math.floor((stackBottom - mouseY + displacement) / panelSize)
  local column = math.floor((mouseX - stackLeft) / panelSize) + 1

  return row, column
end

function TouchInputController:lingeringTouchIsSet()
  if self.lingeringTouchCursor.col ~= 0 and self.lingeringTouchCursor.row ~= 0 then
    return true
  end
  return false
end

function TouchInputController:clearLingeringTouch()
  self.lingeringTouchCursor.row = 0
  self.lingeringTouchCursor.col = 0
end

function TouchInputController:clearSelection()
  self:clearLingeringTouch()
  self.swapsThisTouch = 0
  self.touchSwapCooldownTimer = 0
end

-- Given the current touch state, returns the new row and column of the cursor
function TouchInputController:handleTouch()
  if self.touchSwapCooldownTimer > 0 then
    self.touchSwapCooldownTimer = self.touchSwapCooldownTimer - 1
  end

  if self.stack.cursorLock then
    -- whatever you touch, nothing shall happen if the cursor is locked
    return 0, 0
  else
    -- depending on panel state transformations we may have to undo a lingering touch
    -- if panel at cur_row, cur_col gets certain flags, deselect it, and end the touch
    if self:shouldUnselectPanel() then
      self:clearSelection()
      return 0, 0
    end

    self:updateTouchTargetColumn()

    if self:touchInitiated() then
      self.swapsThisTouch = 0
      self.touchSwapCooldownTimer = 0

      -- check for attempt to swap with self.lingeringTouchCursor
      if self:lingeringTouchIsSet() then
        if self.lingeringTouchCursor.row == self.touchedCell.row
          and math.abs(self.touchedCell.col - self.lingeringTouchCursor.col) == 1 then
          -- the touched panel is on the same row and adjacent to the selected panel
          -- thus fulfilling the minimum condition to be swapped
          local cursorRow, cursorColumn = self:tryPerformTouchSwap(self.touchedCell.col)
          if cursorColumn ~= self.stack.cur_col then
          -- if the swap succeeded, the lingering touch has to be cleared
            self:clearLingeringTouch()
          end

          return cursorRow, cursorColumn
        else
          -- We touched somewhere else on the stack
          -- clear cursor, lingering and touched panel so we can do another initial touch next frame
          self:clearLingeringTouch()
          -- this is so previousTouchedCell is 0, 0 on the next frame allowing us to run into touchInitiated again
          self.touchedCell.row = 0
          self.touchedCell.col = 0
          return 0, 0
        end
      else
        if self:panelIsSelectable(self.touchedCell.row, self.touchedCell.col) then
          return self.touchedCell.row, self.touchedCell.col
        else
          return 0, 0
        end
      end
    elseif self:touchOngoing() then
      if self:lingeringTouchIsSet() then
        -- buffered swaps are currently not enabled due to balancing concerns
        -- always keep the current cursor location and don't try to process a swap under this condition
        -- the lingering cursor should not be cleared so the code keeps running into this branch until the player releases the touch
        return self.stack.cur_row, self.stack.cur_col
      else
        return self:tryPerformTouchSwap(self.touchedCell.col)
      end
    elseif self:touchReleased() then
      if self:lingeringTouchIsSet() then
        -- once a lingering touch cursor is active, the player has to release and tap again to move the panel
        self.touchTargetColumn = 0
      elseif self.touchTargetColumn ~= 0 then
        -- remove the cursor from display if it has reached self.touchTargetColumn
        return self:tryPerformTouchSwap(self.touchTargetColumn)
      end
      return self.lingeringTouchCursor.row, self.lingeringTouchCursor.col
    else
      -- there is no on-going touch but there may still be a target to swap to from the last release
      if self.touchTargetColumn ~= 0 then
        return self:tryPerformTouchSwap(self.touchTargetColumn)
      end

      return self.lingeringTouchCursor.row, self.lingeringTouchCursor.col
    end
  end
end

function TouchInputController:updateTouchTargetColumn()
  if self.touchedCell and self.touchedCell.col ~= 0 then
    self.touchTargetColumn = self.touchedCell.col
  elseif self.previousTouchedCell and self.previousTouchedCell.col ~= 0 then
    self.touchTargetColumn = self.previousTouchedCell.col
    --else retain the value set to self.touchTargetColumn previously
  end

  -- upon arriving at the target column or when the cursor is lost, target is lost as well
  if self.touchTargetColumn == self.stack.cur_col or self.stack.cur_col == 0 then
    self.touchTargetColumn = 0
  end
end

function TouchInputController:shouldUnselectPanel()
  if (self.stack.cur_row ~= 0 and self.stack.cur_col ~= 0) then
    return not self:panelIsSelectable(self.stack.cur_row, self.stack.cur_col)
  end
  return false
end

function TouchInputController:panelIsSelectable(row, column)
  local panel = self.stack.panels[row][column]
  if not panel.isGarbage and
     (panel.state == "normal" or
      panel.state == "landing" or
      panel.state == "swapping") then
    return true
  else
    return false
  end
end

-- returns the coordinate of the cursor after the swap
-- returns 0, 0 or an alternative coordinate if no swap happened
function TouchInputController:tryPerformTouchSwap(targetColumn)
  if self.touchSwapCooldownTimer == 0
  and self.stack.cur_col ~= 0 and targetColumn ~= self.stack.cur_col then
    local swapSuccessful = false
    -- +1 for swapping to the right, -1 for swapping to the left
    local swapDirection = math.sign(targetColumn - self.stack.cur_col)
    local swapOrigin = {row = self.stack.cur_row, col = self.stack.cur_col}
    local swapDestination = {row = self.stack.cur_row, col = self.stack.cur_col + swapDirection}

    if swapDirection == 1 then
      swapSuccessful = self.stack:canSwap(swapOrigin.row, swapOrigin.col)
    else
      swapSuccessful = self.stack:canSwap(swapDestination.row, swapDestination.col)
    end

    if swapSuccessful then
      self.swapsThisTouch = self.swapsThisTouch + 1
      --third swap onward is slowed down to prevent excessive or accidental stealths
      if self.swapsThisTouch >= 2 then
        self.touchSwapCooldownTimer = TOUCH_SWAP_COOLDOWN
      end
      return self.stack.cur_row, swapDestination.col
    else
      --we failed to swap toward the target
      --if both origin and destination are blank panels
      if (self.stack.panels[swapOrigin.row][swapOrigin.col].color == 0
        and self.stack.panels[swapDestination.row][swapDestination.col].color == 0) then
        --we tried to swap two empty panels.  Let's put the cursor on swap_destination
        return swapDestination.row, swapDestination.col
      elseif not self.stack.panels[swapDestination.row][swapDestination.col]:canSwap() then
        -- there are unswappable (likely clearing) panels in the way of the swap 
        -- let's set lingeringTouchCursor to the origin of the failed swap
        logger.trace("lingeringTouchCursor was set because destination panel was not swappable")
        self.lingeringTouchCursor.row = self.stack.cur_row
        self.lingeringTouchCursor.col = self.stack.cur_col
        -- and cancel the swap for consecutive frames
        self.touchTargetColumn = 0
      end
    end
  end
  -- either we didn't move or the cursor stays where it is, could be either 0,0 or on the previously touched panel
  -- in any case, the respective tracking fields (lingering, previous etc) have been set on a previous frame already
  return self.stack.cur_row, self.stack.cur_col
end

function TouchInputController:touchInitiated()
  return (not self.previousTouchedCell or (self.previousTouchedCell.row == 0 and self.previousTouchedCell.col == 0)) 
  and self.touchedCell and not (self.touchedCell.row == 0 and self.touchedCell.col == 0)
end

function TouchInputController:touchOngoing()
  return self.touchedCell and not (self.touchedCell.row == 0 and self.touchedCell.col == 0)
  and self.previousTouchedCell and self.previousTouchedCell.row ~= 0 and self.previousTouchedCell.column ~= 0
end

function TouchInputController:touchReleased()
  return (self.previousTouchedCell and not (self.previousTouchedCell.row == 0 and self.previousTouchedCell.col == 0))
  and (not self.touchedCell or (self.touchedCell.row == 0 and self.touchedCell.col == 0))
end

function TouchInputController:stackIsCreatingNewRow()
  if self.lingeringTouchCursor and self.lingeringTouchCursor.row and self.lingeringTouchCursor.row ~= 0 then
    self.lingeringTouchCursor.row = util.bound(1,self.lingeringTouchCursor.row + 1, self.stack.top_cur_row)
  end
end

-- Returns a debug string useful for printing on screen during debugging
function TouchInputController:debugString()
  local inputs_to_print = ""
  inputs_to_print = inputs_to_print .. "\ncursor:".. self.stack.cur_col ..",".. self.stack.cur_row
  inputs_to_print = inputs_to_print .. "\ntouchedCell:"..self.touchedCell.col..","..self.touchedCell.row
  inputs_to_print = inputs_to_print .. "\npreviousTouchedCell:"..self.previousTouchedCell.col..","..self.previousTouchedCell.row
  inputs_to_print = inputs_to_print .. "\ntouchTargetColumn:"..self.touchTargetColumn
  inputs_to_print = inputs_to_print .. "\nlingeringTouchCursor:"..self.lingeringTouchCursor.col..","..self.lingeringTouchCursor.row
  inputs_to_print = inputs_to_print .. "\nswapsThisTouch:"..self.swapsThisTouch
  inputs_to_print = inputs_to_print .. "\ntouchSwapCooldownTimer:"..self.touchSwapCooldownTimer
  inputs_to_print = inputs_to_print .. "\ntouchingStack:"..(self.touchingStack and "true" or "false")
  return inputs_to_print
end

return TouchInputController