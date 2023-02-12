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
    self.panel_first_touched = {row = 0, col = 0}  --panel that was first touched, since touchedPanel was 0,0.
    self.prev_touchedPanel = {row = 0, col = 0}  --panel that was touched last frame
    self.touch_target_col = 0 -- this is the destination column we will always be trying to swap toward. Set to self.touchedPanel.col or if that's 0, use self.prev_touchedPanel.col, or if that's 0, use existing self.touch_target_col.  if target is reached by self.cur_col, set self.touch_target_col to 0.
    self.lingering_touch_cursor = {row = 0, col = 0} --origin of a failed swap, leave the cursor here even if the touch is released.  Also, leave the cursor here if a panel was touched, and then released without the touch moving.  This will allow us to tap an adjacent panel to try to swap with it.
    self.swaps_this_touch = 0  -- number of swaps that have been initiated since the last time self.panel_first_touched was 0,0
    self.touch_swap_cooldown_timer = 0 -- if this is zero, a swap can happen.  set to TOUCH_SWAP_COOLDOWN on each swap after the first. decrement by 1 each frame.
    self.force_touch_release = false
  end
)

function TouchInputController:encodedCharacterForCurrentTouchInput()
  local iraise, irow_touched, icol_touched = false, 0, 0
  --we'll encode the touched panel and if raise is happening in a unicode character
  --only one touched panel is supported, no multitouch.
  local mx, my = GAME:transform_coordinates(love.mouse.getPosition())
  if love.mouse.isDown(1) then
    --note: a stack is still "touched" if we touched the stack, and have dragged the mouse or touch off the stack, until we lift the touch
    --check whether the mouse is over this stack
    if mx >= self.stack.pos_x * GFX_SCALE and mx <= (self.stack.pos_x * GFX_SCALE) + (self.stack.width * 16) * GFX_SCALE and
    my >= self.stack.pos_y * GFX_SCALE and my <= (self.stack.pos_y * GFX_SCALE) + (self.stack.height* 16) * GFX_SCALE then
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
          if mx >= px and mx < px + 16 * GFX_SCALE and my >= py and my < py + 16 * GFX_SCALE then
            irow_touched = math.max(row, 1) --if touching row 0, let's say we are touching row 1
            icol_touched = col
            if self.stack.prev_touchedPanel 
              and row == self.stack.prev_touchedPanel.row and col == self.stack.prev_touchedPanel.col then
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
      irow_touched = self.touchedPanel.row
      icol_touched = self.touchedPanel.col
    elseif false then -- TODO replace with button
      --note: changed this to an elseif.  
      --This means we won't be able to press raise by accident if we dragged too far off the stack, into the raise button
      --but we also won't be able to input swaps and press raise at the same time, though the network protocol allows touching a panel and raising at the same time
      --Endaris has said we don't need to be able to swap and raise at the same time anyway though.
      iraise = true
    else
      iraise = false
    end
  else
    self.touchingStack = false
    iraise = false
    irow_touched = 0
    icol_touched = 0
  end
  if love.mouse.isDown(2) then
    --if using right mouse button on the stack, we are inputting "raise"
    --also works if we have left mouse buttoned the stack, dragged off, are still holding left mouse button, and then also hold down right mouse button.
    if self.touchingStack or mx >= self.stack.pos_x * GFX_SCALE and mx <= (self.stack.pos_x * GFX_SCALE) + (self.stack.width * 16) * GFX_SCALE and
    my >= self.stack.pos_y * GFX_SCALE and my <= (self.stack.pos_y * GFX_SCALE) + (self.stack.height* 16) * GFX_SCALE then
      iraise = true
    end
  end
  
  local result = TouchDataEncoding.touchDataToLatinString(iraise, icol_touched, irow_touched, self.stack.width)
  
  return result
end

function TouchInputController:handleSwap()
  if not self.stack.cursor_lock then
    if not self.force_touch_release then
      if self.touch_swap_cooldown_timer > 0 then
         self.touch_swap_cooldown_timer = self.touch_swap_cooldown_timer - 1
      end

      --touch was initiated
      if (not self.prev_touchedPanel or (self.prev_touchedPanel.row == 0 and self.prev_touchedPanel.col == 0)) and self.touchedPanel and not (self.touchedPanel.row == 0 and self.touchedPanel.col == 0) then
        self.panel_first_touched = deepcpy(self.touchedPanel)
        self.touch_target_col = self.touchedPanel.col
        self.swaps_this_touch = 0
        self.touch_swap_cooldown_timer = 0
        
        -- check for attempt to swap with self.lingering_touch_cursor
        -- ie we touched a panel horizontally adjacent to self.lingering_touch_cursor
        local linger_swap_attempted = false
        local linger_swap_successful = false
        if self.lingering_touch_cursor.col ~= 0 and self.lingering_touch_cursor.row == self.touchedPanel.row then
          local linger_swap_delta = self.touchedPanel.col - self.lingering_touch_cursor.col
          if linger_swap_delta == 1  then
           --try to swap right
           linger_swap_attempted = true
           linger_swap_successful = self.stack:canSwap(self.lingering_touch_cursor.row, self.lingering_touch_cursor.col)
            if linger_swap_successful then
              self.stack.do_swap = {self.lingering_touch_cursor.row, self.lingering_touch_cursor.col}
            end
          elseif linger_swap_delta == -1 then
            -- try to swap left
            linger_swap_attempted = true
            linger_swap_successful = self.stack:canSwap(self.touchedPanel.row, self.touchedPanel.col)
            if linger_swap_successful then
              self.stack.do_swap = {self.touchedPanel.row,self.touchedPanel.col}
            end
          else
            logger.trace("linger_swap_delta was not -1 or 1, it was "..linger_swap_delta..".  not attempting a swap")
          end
          if linger_swap_successful  then
            self.lingering_touch_cursor = {row = 0, col = 0} --(else leave it as it was, so we can try to tap adjacent again later)
            self.stack.cur_col = self.stack.cur_col + linger_swap_delta
            self.swaps_this_touch = self.swaps_this_touch + 1
          end
        end
        if not linger_swap_attempted then
          --we touched somewhere else on the stack
          --put the cursor at touchedPanel
          self.stack.cur_row = self.touchedPanel.row
          self.stack.cur_col = self.touchedPanel.col
          --remove linger panel selection
          self.lingering_touch_cursor = {row = 0, col = 0}
        end
      end
      
      --touch is ongoing
      if self.touchedPanel and not (self.touchedPanel.row == 0 and self.touchedPanel.col == 0) then
        --if lingering_touch_cursor isn't set, we'll set a target for normal drag swapping.
        if not self.lingering_touch_cursor or (self.lingering_touch_cursor.row == 0 and self.lingering_touch_cursor.col == 0) then
          self.touch_target_col = self.touchedPanel.col
        else -- lingering_touch_cursor is set
          --don't drag the panel at lingering_touch_cursor
          self.touch_target_col = 0
          --the following was decided against, commenting it out
          -- --if we've dragged our touch off the lingering cursor location, and back again, let's make the panel draggable once more
          -- if self.prev_touchedPanel.col ~= self.lingering_touch_cursor.col and self.touchedPanel.col == self.lingering_touch_cursor.col then
            -- self.lingering_touch_cursor = {row = 0, col = 0}
          -- end
        end
      end
    end

    --touch was released
    if (self.prev_touchedPanel and not (self.prev_touchedPanel.row == 0 and self.prev_touchedPanel.col == 0)) and (not self.touchedPanel or (self.touchedPanel.row == 0 and self.touchedPanel.col == 0)) then
      self.force_touch_release = false
      self.panel_first_touched = {row = 0, col = 0} 
      -- --check if we need to set lingering panel because user tapped a panel, didn't move it, and released it.
      -- if self.swaps_this_touch == 0 and self.prev_touchedPanel.row == self.cur_row and self.prev_touchedPanel.col == self.cur_col then --to do: or we tried to swap and couldn't
        -- print("lingering_touch_cursor set to "..self.cur_row..","..self.cur_col) 
        -- self.lingering_touch_cursor = {row = self.cur_row, col = self.cur_col}
      -- end
      --if no lingering_touch_cursor, remove cursor from the display.
      -- and the cursor has reached self.touch_target_col
      if not self.lingering_touch_cursor or (self.lingering_touch_cursor.row == 0 and self.lingering_touch_cursor.col == 0) and self.stack.cur_col == self.touch_target_col then
        self.stack.cur_row = 0
        self.stack.cur_col = 0
        self.swaps_this_touch = 0
      end
    end

    --try to swap toward self.touch_target_col
    if self.touch_swap_cooldown_timer == 0 then
      --if panel at cur_row, cur_col gets certain flags, deselect it, and end the touch
      if (self.stack.cur_row ~= 0 and self.stack.cur_col ~= 0) then
        local panel = self.stack.panels[self.stack.cur_row][self.stack.cur_col]
        if panel:exclude_hover() or panel.state == "matched" then
          self.stack.cur_row = 0
          self.stack.cur_col = 0
          self.swaps_this_touch = 0
          self.lingering_touch_cursor = {row = 0, col = 0}
          self.touch_target_col = 0
          if self.touchingStack then
            self.force_touch_release = true
          end
        end
      end
      if not self.force_touch_release and self.touch_target_col ~= 0 and self.stack.cur_col ~= 0 and self.touch_target_col ~= self.stack.cur_col then
        local cursor_target_delta = self.touch_target_col - self.stack.cur_col
        local swap_successful = false
        local swap_origin = {row = 0, col = 0}
        local swap_destination = {row = 0, col = 0}
        if (cursor_target_delta) > 0 then
          --try to swap right
          swap_origin = {row = self.stack.cur_row, col = self.stack.cur_col}
          swap_destination = {row = self.stack.cur_row, col = self.stack.cur_col + 1}
          swap_successful = self.stack:canSwap(swap_origin.row, swap_origin.col)
          if swap_successful then
            self.stack.do_swap = {swap_origin.row, swap_origin.col}
            self.stack.cur_col = swap_destination.col
          end
        elseif cursor_target_delta < 0 then
          --try to swap left
          swap_origin = {row = self.stack.cur_row, col = self.stack.cur_col}
          swap_destination = {row = self.stack.cur_row, col = self.stack.cur_col - 1}
          swap_successful = self.stack:canSwap(swap_destination.row, swap_destination.col)
          if swap_successful then
            self.stack.do_swap = {swap_destination.row, swap_destination.col}
            self.stack.cur_col = swap_destination.col
          end
        end
        if swap_successful then 
          self.swaps_this_touch = self.swaps_this_touch + 1
          if self.swaps_this_touch >= 2 then --third swap onward is slowed down to prevent excessive or accidental stealths
            self.touch_swap_cooldown_timer = TOUCH_SWAP_COOLDOWN
          end
        else  --we failed to swap toward the target
          --if both origin and destination are blank panels
          if (self.stack.panels[swap_origin.row][swap_origin.col].color == 0
            and self.stack.panels[swap_destination.row][swap_destination.col].color == 0) then
            --we tried to swap two empty panels.  Let's put the cursor on swap_destination
            self.stack.cur_row = swap_destination.row
            self.stack.cur_col = swap_destination.col
          --elseif there are clearing panels in the way of the swap 
          elseif self.stack.panels[swap_destination.row][swap_destination.col]:exclude_swap() then
            --let's set lingering_touch_cursor to the origin of the failed swap
            logger.trace("lingering_touch_cursor was set because destination panel was not swappable")
            self.lingering_touch_cursor = {row = self.stack.cur_row, col = self.stack.cur_col}
          end
        end
      end
    end --of self.touch_swap_cooldown_timer was 0
  end
end

function TouchInputController:stackIsCreatingNewRow()
  if self.panel_first_touched and self.panel_first_touched.row and self.panel_first_touched.row ~= 0 then
    self.panel_first_touched.row = bound(1,self.panel_first_touched.row + 1, self.stack.top_cur_row)
  end
  if self.lingering_touch_cursor and self.lingering_touch_cursor.row and self.lingering_touch_cursor.row ~= 0 then
    self.lingering_touch_cursor.row = bound(1,self.lingering_touch_cursor.row + 1, self.stack.top_cur_row)
  end
end

return TouchInputController