local logger = require("logger")
local TouchDataEncoding = require("engine.TouchDataEncoding")

local TOUCH_SWAP_COOLDOWN = 5  -- default number of cooldown frames between touch-input swaps, applied after the first 2 swaps after a touch is initiated, to prevent excessive or accidental stealths

-- An object that manages touches on the screen and translates them to swaps on a stack
TouchInputController =
  class(
  function(self, stack)
    self.touchingStack = false -- whether the stack (panels) are touched.  Still true if touch is dragged off the stack, but not released yet.
    self.stack = stack
    --if any is {row = 0, col = 0}, this is the equivalent if the variable being nil.  They do not describe any panel in the stack at the moment.
    self.touchedPanel = {row = 0, col = 0}  -- panel that is currently touched
    self.panelFirstTouched = {row = 0, col = 0}  --panel that was first touched, since touchedPanel was 0,0.
    self.previousTouchedPanel = {row = 0, col = 0}  --panel that was touched last frame
    self.touchTargetColumn = 0 -- this is the destination column we will always be trying to swap toward. Set to self.touchedPanel.col or if that's 0, use self.previousTouchedPanel.col, or if that's 0, use existing self.touchTargetColumn.  if target is reached by self.cur_col, set self.touchTargetColumn to 0.
    self.lingeringTouchCursor = {row = 0, col = 0} --origin of a failed swap, leave the cursor here even if the touch is released.  Also, leave the cursor here if a panel was touched, and then released without the touch moving.  This will allow us to tap an adjacent panel to try to swap with it.
    self.swapsThisTouch = 0  -- number of swaps that have been initiated since the last time self.panelFirstTouched was 0,0
    self.touchSwapCooldownTimer = 0 -- if this is zero, a swap can happen.  set to TOUCH_SWAP_COOLDOWN on each swap after the first. decrement by 1 each frame.
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
    if mouseX >= self.stack.pos_x * GFX_SCALE and mouseX <= (self.stack.pos_x * GFX_SCALE) + (self.stack.width * 16) * GFX_SCALE and
    mouseY >= self.stack.pos_y * GFX_SCALE and mouseY <= (self.stack.pos_y * GFX_SCALE) + (self.stack.height* 16) * GFX_SCALE then
      self.touchingStack = true
      --px and py represent the origin of the panel we are currently checking if it's touched.
      local px, py
      local stop_looking = false
      for row = 0, self.stack.height do
        for col = 1, self.stack.width do
          --print("checking panel "..row..","..col)
          px = (self.stack.pos_x * GFX_SCALE) + ((col - 1) * 16) * GFX_SCALE
          --to do: maybe self.stack.displacement - shake here? ignoring shake for now.
          py = (self.stack.pos_y * GFX_SCALE) + ((11 - (row)) * 16 + self.stack.displacement) * GFX_SCALE
          --check if mouse is touching panel in row, col
          if mouseX >= px and mouseX < px + 16 * GFX_SCALE and mouseY >= py and mouseY < py + 16 * GFX_SCALE then
            rowTouched = math.max(row, 1) --if touching row 0, let's say we are touching row 1
            columnTouched = col
            if self.stack.previousTouchedPanel 
              and row == self.stack.previousTouchedPanel.row and col == self.stack.previousTouchedPanel.col then
              --we want this to be the selected panel in the case more than one panel is touched
              stop_looking = true
              break --don't look further
            end
            --otherwise, we'll continue looking for touched panels, and the panel with the largest panel coordinates (ie closer to 12,6) will be chosen as self.stack.touchedPanel
            --this may help us implement stealth.
          end
          if stop_looking then
              break
          end
        end
      end
    elseif self.touchingStack then --we have touched the stack, and have moved the touch off the edge, without releasing
      --let's say we are still touching the panel we had touched last.
      rowTouched = self.touchedPanel.row
      columnTouched = self.touchedPanel.col
    elseif false then -- TODO replace with button
      --note: changed this to an elseif.  
      --This means we won't be able to press raise by accident if we dragged too far off the stack, into the raise button
      --but we also won't be able to input swaps and press raise at the same time, though the network protocol allows touching a panel and raising at the same time
      --Endaris has said we don't need to be able to swap and raise at the same time anyway though.
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
    if self.touchingStack or mouseX >= self.stack.pos_x * GFX_SCALE and mouseX <= (self.stack.pos_x * GFX_SCALE) + (self.stack.width * 16) * GFX_SCALE and
    mouseY >= self.stack.pos_y * GFX_SCALE and mouseY <= (self.stack.pos_y * GFX_SCALE) + (self.stack.height* 16) * GFX_SCALE then
      shouldRaise = true
    end
  end
  
  self.previousTouchedPanel = deepcpy(self.touchedPanel)
  self.touchedPanel = {row = rowTouched, col = columnTouched}

  local cursorRow, cursorColumn = self:handleSwap()
  
  local result = TouchDataEncoding.touchDataToLatinString(shouldRaise, cursorRow, cursorColumn, self.stack.width)
  return result
end

function TouchInputController:lingeringTouchIsSet()
  if self.lingeringTouchCursor.col ~= 0 and self.lingeringTouchCursor.row ~= 0 then
    return true
  end
  return false
end

-- Given the current touch state, returns the new cursor row and column
function TouchInputController:handleSwap()
  local cursorColumn = 0
  local cursorRow = 0

  if not self.stack.cursor_lock then
    cursorColumn = self.stack.cur_col
    cursorRow = self.stack.cur_row

    if self.touchSwapCooldownTimer > 0 then
        self.touchSwapCooldownTimer = self.touchSwapCooldownTimer - 1
    end

    --touch was initiated
    if (not self.previousTouchedPanel or (self.previousTouchedPanel.row == 0 and self.previousTouchedPanel.col == 0)) and
        self.touchedPanel and not (self.touchedPanel.row == 0 and self.touchedPanel.col == 0) then
      self.panelFirstTouched = deepcpy(self.touchedPanel)
      self.touchTargetColumn = self.touchedPanel.col
      self.swapsThisTouch = 0
      self.touchSwapCooldownTimer = 0
      
      -- check for attempt to swap with self.lingeringTouchCursor
      -- ie we touched a panel horizontally adjacent to self.lingeringTouchCursor
      if self:lingeringTouchIsSet() then
        local linger_swap_attempted = false
        local linger_swap_successful = false
        if self.lingeringTouchCursor.row == self.touchedPanel.row then
          local linger_swap_delta = self.touchedPanel.col - self.lingeringTouchCursor.col
          if linger_swap_delta == 1  then
            --try to swap right
            linger_swap_attempted = true
            linger_swap_successful = self.stack:canSwap(self.lingeringTouchCursor.row, self.lingeringTouchCursor.col)
            if linger_swap_successful then
              cursorColumn = self.lingeringTouchCursor.col
              cursorRow = self.lingeringTouchCursor.row
            end
          elseif linger_swap_delta == -1 then
            -- try to swap left
            linger_swap_attempted = true
            linger_swap_successful = self.stack:canSwap(self.touchedPanel.row, self.touchedPanel.col)
            if linger_swap_successful then
              cursorColumn = self.touchedPanel.col
              cursorRow = self.touchedPanel.row
            end
          end
          if linger_swap_successful then
            self.lingeringTouchCursor = {row = 0, col = 0} --(else leave it as it was, so we can try to tap adjacent again later)
            self.swapsThisTouch = self.swapsThisTouch + 1
          end
        end
        if linger_swap_attempted == false then
          -- We touched somewhere else on the stack
          -- clear cursor, lingering and touched panel so we can do another initial touch next frame
          self.lingeringTouchCursor = {row = 0, col = 0}
          self.touchedPanel = {row = 0, col = 0}
          cursorColumn = 0
          cursorRow = 0
        end
      else
        cursorColumn = self.touchedPanel.col
        cursorRow = self.touchedPanel.row
      end
    end
    
    --touch is ongoing
    if self.touchedPanel and not (self.touchedPanel.row == 0 and self.touchedPanel.col == 0) then
      --if lingeringTouchCursor isn't set, we'll set a target for normal drag swapping.
      if self:lingeringTouchIsSet() == false then
        self.touchTargetColumn = self.touchedPanel.col
      else -- lingeringTouchCursor is set
        --don't drag the panel at lingeringTouchCursor
        self.touchTargetColumn = 0
        --the following was decided against, commenting it out
        -- --if we've dragged our touch off the lingering cursor location, and back again, let's make the panel draggable once more
        -- if self.previousTouchedPanel.col ~= self.lingeringTouchCursor.col and self.touchedPanel.col == self.lingeringTouchCursor.col then
          -- self.lingeringTouchCursor = {row = 0, col = 0}
        -- end
      end
    end

    --touch was released
    if (self.previousTouchedPanel and not (self.previousTouchedPanel.row == 0 and self.previousTouchedPanel.col == 0)) and (not self.touchedPanel or (self.touchedPanel.row == 0 and self.touchedPanel.col == 0)) then
      self.panelFirstTouched = {row = 0, col = 0} 
      -- --check if we need to set lingering panel because user tapped a panel, didn't move it, and released it.
      -- if self.swapsThisTouch == 0 and self.previousTouchedPanel.row == self.cur_row and self.previousTouchedPanel.col == self.cur_col then --to do: or we tried to swap and couldn't
        -- print("lingeringTouchCursor set to "..self.cur_row..","..self.cur_col) 
        -- self.lingeringTouchCursor = {row = self.cur_row, col = self.cur_col}
      -- end
      --if no lingeringTouchCursor, remove cursor from the display.
      -- and the cursor has reached self.touchTargetColumn
      if self:lingeringTouchIsSet() == false and self.stack.cur_col == self.touchTargetColumn then
        cursorColumn = 0
        cursorRow = 0
      end
      self.touchTargetColumn = 0
      self.swapsThisTouch = 0
    end

    --if panel at cur_row, cur_col gets certain flags, deselect it, and end the touch
    if (self.stack.cur_row ~= 0 and self.stack.cur_col ~= 0) then
      local panel = self.stack.panels[self.stack.cur_row][self.stack.cur_col]
      if panel:exclude_hover() or panel.state == "matched" then
        cursorColumn = 0
        cursorRow = 0
        self.swapsThisTouch = 0
        self.lingeringTouchCursor = {row = 0, col = 0}
        self.touchTargetColumn = 0
      end
    end

    if self:lingeringTouchIsSet() then
      -- Don't auto swap while lingering touch is set
    elseif self.touchTargetColumn ~= 0 then
      if self.touchSwapCooldownTimer == 0 then
        --try to swap toward self.touchTargetColumn
        if self.stack.cur_col ~= 0 and self.touchTargetColumn ~= self.stack.cur_col then
          local cursor_target_delta = self.touchTargetColumn - self.stack.cur_col
          local swap_successful = false
          local swap_origin = {row = 0, col = 0}
          local swap_destination = {row = 0, col = 0}
          if (cursor_target_delta) > 0 then
            --try to swap right
            swap_origin = {row = self.stack.cur_row, col = self.stack.cur_col}
            swap_destination = {row = self.stack.cur_row, col = self.stack.cur_col + 1}
            swap_successful = self.stack:canSwap(swap_origin.row, swap_origin.col)
            if swap_successful then
              cursorColumn = swap_destination.col
            end
          elseif cursor_target_delta < 0 then
            --try to swap left
            swap_origin = {row = self.stack.cur_row, col = self.stack.cur_col}
            swap_destination = {row = self.stack.cur_row, col = self.stack.cur_col - 1}
            swap_successful = self.stack:canSwap(swap_destination.row, swap_destination.col)
            if swap_successful then
              cursorColumn = swap_destination.col
            end
          else -- we are already at the desired column
            if self.touchedPanel.col == 0 and self.touchedPanel.row == 0 then
              -- We aren't touching anything anymore, clear the cursor
              cursorColumn = 0
              cursorRow = 0
              self.touchTargetColumn = 0
            end
          end
          if swap_successful then 
            self.swapsThisTouch = self.swapsThisTouch + 1
            if self.swapsThisTouch >= 2 then --third swap onward is slowed down to prevent excessive or accidental stealths
              self.touchSwapCooldownTimer = TOUCH_SWAP_COOLDOWN
            end
          else  --we failed to swap toward the target
            --if both origin and destination are blank panels
            if (self.stack.panels[swap_origin.row][swap_origin.col].color == 0
              and self.stack.panels[swap_destination.row][swap_destination.col].color == 0) then
              --we tried to swap two empty panels.  Let's put the cursor on swap_destination
              cursorColumn = swap_destination.col
              cursorRow = swap_destination.row
            --elseif there are clearing panels in the way of the swap 
            elseif self.stack.panels[swap_destination.row][swap_destination.col]:exclude_swap() then
              --let's set lingeringTouchCursor to the origin of the failed swap
              logger.trace("lingeringTouchCursor was set because destination panel was not swappable")
              self.lingeringTouchCursor = {row = self.stack.cur_row, col = self.stack.cur_col}
            end
          end
        end
      end --of self.touchSwapCooldownTimer was 0
    else
      cursorColumn = 0
      cursorRow = 0
    end
  end

  return cursorRow, cursorColumn
end

function TouchInputController:stackIsCreatingNewRow()
  if self.panelFirstTouched and self.panelFirstTouched.row and self.panelFirstTouched.row ~= 0 then
    self.panelFirstTouched.row = bound(1,self.panelFirstTouched.row + 1, self.stack.top_cur_row)
  end
  if self.lingeringTouchCursor and self.lingeringTouchCursor.row and self.lingeringTouchCursor.row ~= 0 then
    self.lingeringTouchCursor.row = bound(1,self.lingeringTouchCursor.row + 1, self.stack.top_cur_row)
  end
end

-- Returns a debug string useful for printing on screen during debugging
function TouchInputController:debugString()
  local inputs_to_print = ""
  inputs_to_print = inputs_to_print .. "\ncursor:".. self.stack.cur_col ..",".. self.stack.cur_row
  inputs_to_print = inputs_to_print .. "\ntouchedPanel:"..self.touchedPanel.col..","..self.touchedPanel.row
  inputs_to_print = inputs_to_print .. "\npanelFirstTouched:"..self.panelFirstTouched.col..","..self.panelFirstTouched.row
  inputs_to_print = inputs_to_print .. "\npreviousTouchedPanel:"..self.previousTouchedPanel.col..","..self.previousTouchedPanel.row
  inputs_to_print = inputs_to_print .. "\ntouchTargetColumn:"..self.touchTargetColumn
  inputs_to_print = inputs_to_print .. "\nlingeringTouchCursor:"..self.lingeringTouchCursor.col..","..self.lingeringTouchCursor.row
  inputs_to_print = inputs_to_print .. "\nswapsThisTouch:"..self.swapsThisTouch
  inputs_to_print = inputs_to_print .. "\ntouchSwapCooldownTimer:"..self.touchSwapCooldownTimer
  inputs_to_print = inputs_to_print .. "\ntouchingStack:"..(self.touchingStack and "true" or "false")
  return inputs_to_print
end

return TouchInputController