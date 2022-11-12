require("analytics")
local logger = require("logger")

-- Stuff defined in this file:
--  . the data structures that store the configuration of
--    the stack of panels
--  . the main game routine
--    (rising, timers, falling, cursor movement, swapping, landing)
--  . the matches-checking routine
local min, pairs, deepcpy = math.min, pairs, deepcpy
local max = math.max
local garbage_bounce_time = #garbage_bounce_table
local clone_pool = {}

-- Represents the full panel stack for one player
Stack =
  class(
  function(s, arguments)
    local which = arguments.which or 1
    assert(arguments.match ~= nil)
    local match = arguments.match
    assert(arguments.is_local ~= nil)
    local is_local = arguments.is_local
    local panels_dir = arguments.panels_dir or config.panels
    -- level or difficulty should be set
    assert(arguments.level ~= nil or arguments.difficulty ~= nil)
    local level = arguments.level
    local difficulty = arguments.difficulty
    local speed = arguments.speed
    local player_number = arguments.player_number or which
    local wantsCanvas = arguments.wantsCanvas or 1
    local character = arguments.character or config.character

    s.match = match
    s.character = character
    s.max_health = 1
    s.panels_dir = panels_dir
    s.portraitFade = 0
    s.is_local = is_local

    s.drawsAnalytics = true

    if not panels[panels_dir] then
      s.panels_dir = config.panels
    end

    if s.match.mode == "puzzle" then
      s.drawsAnalytics = false
    else
      s.do_first_row = true
    end

    if difficulty then
      if s.match.mode == "endless" then
        s.NCOLORS = difficulty_to_ncolors_endless[difficulty]
      elseif s.match.mode == "time" then
        s.NCOLORS = difficulty_to_ncolors_1Ptime[difficulty]
      end
    end

    -- frame.png dimensions
    if wantsCanvas then
      s.canvas = love.graphics.newCanvas(104 * GFX_SCALE, 204 * GFX_SCALE, {dpiscale=GAME:newCanvasSnappedScale()})
    end

    if level then
      s:setLevel(level)
      speed = speed or level_to_starting_speed[level]
    end
    s.health = s.max_health

    s.garbage_cols = {
      {1, 2, 3, 4, 5, 6, idx = 1},
      {1, 3, 5, idx = 1},
      {1, 4, idx = 1},
      {1, 2, 3, idx = 1},
      {1, 2, idx = 1},
      {1, idx = 1}
    }

    s.later_garbage = {} -- Queue of garbage that is done waiting in telegraph, and been popped out, and will be sent to our stack next frame
    s.garbage_q = GarbageQueue(s) -- Queue of garbage that is about to be dropped

    s:moveForPlayerNumber(which)

    s.panel_buffer = ""
    s.gpanel_buffer = ""
    s.input_buffer = ""
    s.confirmedInput = {} -- All inputs the player has input ever
    s.panels = {}
    s.width = 6
    s.height = 12
    for i = 0, s.height do
      s.panels[i] = {}
      for j = 1, s.width do
        s.panels[i][j] = Panel()
      end
    end

    s.CLOCK = 0
    s.game_stopwatch = 0
    s.game_stopwatch_running = false
    s.do_countdown = true
    s.max_runs_per_frame = 3

    s.displacement = 16
    -- This variable indicates how far below the top of the play
    -- area the top row of panels actually is.
    -- This variable being decremented causes the stack to rise.
    -- During the automatic rising routine, if this variable is 0,
    -- it's reset to 15, all the panels are moved up one row,
    -- and a new row is generated at the bottom.
    -- Only when the displacement is 0 are all 12 rows "in play."

    s.danger_col = {false, false, false, false, false, false}
    -- set true if this column is near the top
    s.danger_timer = 0 -- decides bounce frame when in danger

    s.difficulty = difficulty or 2

    s.speed = speed or 1 -- The player's speed level decides the amount of time
    -- the stack takes to rise automatically
    if s.speed_times == nil then
      s.panels_to_speedup = panels_to_next_speed[s.speed]
    end
    s.rise_timer = 1 -- When this value reaches 0, the stack will rise a pixel
    s.rise_lock = false -- If the stack is rise locked, it won't rise until it is
    -- unlocked.
    s.has_risen = false -- set once the stack rises once during the game

    s.stop_time = 0
    s.pre_stop_time = 0

    s.NCOLORS = s.NCOLORS or 5
    s.score = 0 -- der skore
    s.chain_counter = 0 -- how high is the current chain (starts at 2)

    s.panels_in_top_row = false -- boolean, for losing the game
    s.danger = s.danger or false -- boolean, panels in the top row (danger)
    s.danger_music = s.danger_music or false -- changes music state

    s.n_active_panels = 0
    s.n_prev_active_panels = 0
    s.n_chain_panels = 0

    -- These change depending on the difficulty and speed levels:
    s.FRAMECOUNT_HOVER = s.FRAMECOUNT_HOVER or FC_HOVER[s.difficulty]
    s.FRAMECOUNT_FLASH = s.FRAMECOUNT_FLASH or FC_FLASH[s.difficulty]
    s.FRAMECOUNT_FACE = s.FRAMECOUNT_FACE or FC_FACE[s.difficulty]
    s.FRAMECOUNT_POP = s.FRAMECOUNT_POP or FC_POP[s.difficulty]
    s.FRAMECOUNT_MATCH = s.FRAMECOUNT_FACE + s.FRAMECOUNT_FLASH
    s.FRAMECOUNT_RISE = speed_to_rise_time[s.speed]

    s.rise_timer = s.FRAMECOUNT_RISE

    -- Player input stuff:
    s.manual_raise = false -- set until raising is completed
    s.manual_raise_yet = false -- if not set, no actual raising's been done yet
    -- since manual raise button was pressed
    s.prevent_manual_raise = false
    s.swap_1 = false -- attempt to initiate a swap on this frame
    s.swap_2 = false

    s.taunt_up = nil -- will hold an index
    s.taunt_down = nil -- will hold an index
    s.taunt_queue = Queue()

    s.cur_wait_time = config.input_repeat_delay -- number of ticks to wait before the cursor begins
    -- to move quickly... it's based on P1CurSensitivity
    s.cur_timer = 0 -- number of ticks for which a new direction's been pressed
    s.cur_dir = nil -- the direction pressed
    s.cur_row = 7 -- the row the cursor's on
    s.cur_col = 3 -- the column the left half of the cursor's on
    s.top_cur_row = s.height + (s.match.mode == "puzzle" and 0 or -1)

    s.poppedPanelIndex = s.poppedPanelIndex or 1
    s.panels_cleared = s.panels_cleared or 0
    s.metal_panels_queued = s.metal_panels_queued or 0
    s.lastPopLevelPlayed = s.lastPopLevelPlayed or 1
    s.lastPopIndexPlayed = s.lastPopIndexPlayed or 1
    s.combo_chain_play = nil
    s.game_over = false -- only set if this player got a game over
    s.game_over_clock = 0 -- only set if game_over is true, the exact clock frame the player lost
    s.sfx_land = false
    s.sfx_garbage_thud = 0

    s.card_q = Queue()

    s.pop_q = Queue()

    s.which = which
    s.player_number = player_number --player number according to the multiplayer server, for game outcome reporting

    s.shake_time = 0

    s.prev_states = {}

    s.analytic = AnalyticsInstance(s.is_local)

    if s.match.mode == "vs" then
      s.telegraph = Telegraph(s, s) -- Telegraph holds the garbage that hasn't been committed yet and also tracks the attack animations
      -- NOTE: this is the telegraph above this stack, so the opponents puts garbage in this stack.
    end

    s.combos = {} -- Tracks the combos made throughout the whole game. Key is the clock time, value is the combo size

    s.chains = {} -- Tracks the chains mades throughout the whole game
    --[[
      .last_complete - the CLOCK index into the last chain or nil if no chains this game yet
      .current - the CLOCK index into the current chain or nil if no chain active
      indexes
        Key - CLOCK time the chain started
        Value -
	        start - CLOCK time the chain started (same as key)
	        finish - CLOCK time the chain finished
	        size - the chain size 2, 3, etc
    ]]

    s.panelGenCount = 0
    s.garbageGenCount = 0

    s.rollbackCount = 0 -- the number of times total we have done rollback
    s.lastRollbackFrame = -1 -- the last frame we had to rollback from

    s.framesBehindArray = {}
    s.totalFramesBehind = 0
    s.warningsTriggered = {}

  end)

function Stack.setLevel(self, level)
  self.level = level
  --difficulty           = level_to_difficulty[level]
  self.speed_times = {15 * 60, idx = 1, delta = 15 * 60}
  self.max_health = level_to_hang_time[level]
  self.FRAMECOUNT_HOVER = level_to_hover[level]
  self.FRAMECOUNT_GPHOVER = level_to_garbage_panel_hover[level]
  self.FRAMECOUNT_FLASH = level_to_flash[level]
  self.FRAMECOUNT_FACE = level_to_face[level]
  self.FRAMECOUNT_POP = level_to_pop[level]
  self.combo_constant = level_to_combo_constant[level]
  self.combo_coefficient = level_to_combo_coefficient[level]
  self.chain_constant = level_to_chain_constant[level]
  self.chain_coefficient = level_to_chain_coefficient[level]
  if self.match.mode == "2ptime" then
    self.NCOLORS = level_to_ncolors_time[level]
  else
    self.NCOLORS = level_to_ncolors_vs[level]
  end
end

-- Positions the stack draw position for the given player
function Stack.moveForPlayerNumber(stack, player_num)
  -- Position of elements should ideally be on even coordinates to avoid non pixel alignment
  -- on 150% scale
  if player_num == 1 then
    stack.pos_x = 80
    stack.score_x = 546
    stack.mirror_x = 1
    stack.origin_x = stack.pos_x
    stack.multiplication = 0
    stack.id = "_1P"
    stack.VAR_numbers = ""
  elseif player_num == 2 then
    stack.pos_x = 248
    stack.score_x = 642
    stack.mirror_x = -1
    stack.origin_x = stack.pos_x + (stack.canvas:getWidth() / GFX_SCALE) - 8
    stack.multiplication = 1
    stack.id = "_2P"
  end
  stack.pos_y = 4 + (108) / GFX_SCALE
  stack.score_y = 208
end

function Stack.divergenceString(stackToTest)
  local result = ""

  local panels = stackToTest.panels

  if panels then
      for i=#panels,1,-1 do
          for j=1,#panels[i] do
            result = result .. (tostring(panels[i][j].color)) .. " "
            if panels[i][j].state ~= "normal" then
              result = result .. (panels[i][j].state) .. " "
            end
          end
          result = result .. "\n"
      end
  end

  if stackToTest.telegraph then
    result = result .. "telegraph.chain count " .. stackToTest.telegraph.garbage_queue.chain_garbage:len() .. "\n"
    result = result .. "telegraph.senderCurrentlyChaining " .. tostring(stackToTest.telegraph.senderCurrentlyChaining) .. "\n"
    result = result .. "telegraph.attacks " .. table.length(stackToTest.telegraph.attacks) .. "\n"
  end
  
  result = result .. "garbage_q " .. stackToTest.garbage_q:len() .. "\n"
  result = result .. "later_garbage " .. table.length(stackToTest.later_garbage) .. "\n"
  result = result .. "Stop " .. stackToTest.stop_time .. "\n"
  result = result .. "Pre Stop " .. stackToTest.pre_stop_time .. "\n"
  result = result .. "Shake " .. stackToTest.shake_time .. "\n"
  result = result .. "Displacement " .. stackToTest.displacement .. "\n"
  result = result .. "Clock " .. stackToTest.CLOCK .. "\n"
  result = result .. "Panel Buffer " .. stackToTest.panel_buffer .. "\n"

  return result
end

-- Backup important variables into the passed in variable to be restored in rollback. Note this doesn't do a full copy.
function Stack.rollbackCopy(self, source, other)
  if other == nil then
    if #clone_pool == 0 then
      other = {}
    else
      other = clone_pool[#clone_pool]
      clone_pool[#clone_pool] = nil
    end
  end
  other.do_swap = source.do_swap
  other.speed = source.speed
  other.health = source.health
  other.garbage_cols = deepcpy(source.garbage_cols)
  --[[if source.garbage_cols then
    other.garbage_idxs = other.garbage_idxs or {}
    local n_g_cols = #(source.garbage_cols or other.garbage_cols)
    for i=1,n_g_cols do
      other.garbage_idxs[i]=source.garbage_cols[i].idx
    end
  else

  end--]]
  other.later_garbage = deepcpy(source.later_garbage)
  other.garbage_q = source.garbage_q:makeCopy()
  if source.telegraph then
    other.telegraph = source.telegraph:rollbackCopy(source.telegraph, other.telegraph)
  end
  local width = source.width or other.width
  local height_to_cpy = #source.panels
  other.panels = other.panels or {}
  local startRow = 1
  if self.panels[0] then
    startRow = 0
  end
  for i = startRow, height_to_cpy do
    if other.panels[i] == nil then
      other.panels[i] = {}
      for j = 1, width do
        other.panels[i][j] = Panel()
      end
    end
    for j = 1, width do
      local opanel = other.panels[i][j]
      local spanel = source.panels[i][j]
      opanel:clear()
      for k, v in pairs(spanel) do
        opanel[k] = v
      end
    end
  end
  for i = height_to_cpy + 1, #other.panels do
    other.panels[i] = nil
  end

  other.countdown_CLOCK = source.countdown_CLOCK
  other.starting_cur_row = source.starting_cur_row
  other.starting_cur_col = source.starting_cur_col
  other.countdown_cursor_state = source.countdown_cursor_state
  other.countdown_cur_speed = source.countdown_cur_speed
  other.countdown_timer = source.countdown_timer
  other.CLOCK = source.CLOCK
  other.game_stopwatch = source.game_stopwatch
  other.game_stopwatch_running = source.game_stopwatch_running
  other.prev_rise_lock = source.prev_rise_lock
  other.rise_lock = source.rise_lock
  other.top_cur_row = source.top_cur_row
  other.cursor_lock = source.cursor_lock
  other.displacement = source.displacement
  other.speed_times = deepcpy(source.speed_times)
  other.panels_to_speedup = source.panels_to_speedup
  other.stop_time = source.stop_time
  other.pre_stop_time = source.pre_stop_time
  other.score = source.score
  other.chain_counter = source.chain_counter
  other.n_active_panels = source.n_active_panels
  other.n_prev_active_panels = source.n_prev_active_panels
  other.n_chain_panels = source.n_chain_panels
  other.FRAMECOUNT_RISE = source.FRAMECOUNT_RISE
  other.rise_timer = source.rise_timer
  other.manual_raise = source.manual_raise
  other.manual_raise_yet = source.manual_raise_yet
  other.prevent_manual_raise = source.prevent_manual_raise
  other.cur_timer = source.cur_timer
  other.cur_dir = source.cur_dir
  other.cur_row = source.cur_row
  other.cur_col = source.cur_col
  other.shake_time = source.shake_time
  other.peak_shake_time = source.peak_shake_time
  other.do_countdown = source.do_countdown
  other.ready_y = source.ready_y
  other.combos = deepcpy(source.combos)
  other.chains = deepcpy(source.chains)
  other.panel_buffer = source.panel_buffer
  other.gpanel_buffer = source.gpanel_buffer
  other.panelGenCount = source.panelGenCount
  other.garbageGenCount = source.garbageGenCount
  other.panels_in_top_row = source.panels_in_top_row
  other.has_risen = source.has_risen
  other.metal_panels_queued = source.metal_panels_queued
  other.panels_cleared = source.panels_cleared
  other.danger_timer = source.danger_timer
  other.analytic = deepcpy(source.analytic)
  other.game_over_clock = source.game_over_clock

  return other
end

function Stack.restoreFromRollbackCopy(self, other)
  self:rollbackCopy(other, self)
  if self.telegraph then
    self.telegraph.owner = self.garbage_target
    self.telegraph.sender = self
  end
  -- The remaining inputs is the confirmed inputs not processed yet for this clock time
  -- We have processed CLOCK time number of inputs when we are at CLOCK, so we only want to process the CLOCK+1 input on
  self.input_buffer = table.concat(self.confirmedInput, nil, self.CLOCK + 1)
end

function Stack.rollbackToFrame(self, frame) 
  local currentFrame = self.CLOCK
  local difference = currentFrame - frame
  local safeToRollback = difference <= MAX_LAG
  if not safeToRollback then
    if self.garbage_target then
      self.garbage_target.tooFarBehindError = true
    end
    return -- EARLY RETURN
  end

  if frame < currentFrame then
    local prev_states = self.prev_states
    logger.debug("Rolling back " .. self.which .. " to " .. frame)
    assert(prev_states[frame])
    self:restoreFromRollbackCopy(prev_states[frame])

    if self.garbage_target and self.garbage_target.later_garbage then
      -- The garbage that we send this time might (rarely) not be the same
      -- as the garbage we sent before.  Wipe out the garbage we sent before...
      for k, v in pairs(self.garbage_target.later_garbage) do
        if k > frame then
          self.garbage_target.later_garbage[k] = nil
        end
      end
    end

    self.rollbackCount = self.rollbackCount + 1
    self.lastRollbackFrame = currentFrame
  end
end

function Stack:shouldSaveRollback()
  if not GAME.match then
    return false
  end

  if GAME.match.isFromReplay then
    return true
  end

  -- if we don't have a garbage target, its is assumed we aren't being attacked either, which means we don't need to rollback
  if not self.garbage_target then
    return false
  -- If we are behind the time that the opponent's new attacks would land, then we don't need to rollback
  -- don't save the rollback info for performance reasons
  -- this also includes local play and single player, since the clocks are <= 1 difference
  elseif self.garbage_target.CLOCK + GARBAGE_DELAY_LAND_TIME > self.CLOCK then
    return false
  end

  return true
end

-- Saves state in backups in case its needed for rollback
-- NOTE: the CLOCK time is the save state for simulating right BEFORE that clock time is simulated
function Stack.saveForRollback(self)

  if self:shouldSaveRollback() == false then
    return
  end

  local prev_states = self.prev_states
  local garbage_target = self.garbage_target
  self.garbage_target = nil
  self.prev_states = nil
  self:remove_extra_rows()
  prev_states[self.CLOCK] = self:rollbackCopy(self)
  self.prev_states = prev_states
  self.garbage_target = garbage_target
  local deleteFrame = self.CLOCK - MAX_LAG - 1
  if prev_states[deleteFrame] then
    Telegraph.saveClone(prev_states[deleteFrame].telegraph)

     -- Has a reference to stacks we don't want kept around
    prev_states[deleteFrame].telegraph = nil

    clone_pool[#clone_pool + 1] = prev_states[deleteFrame]
    prev_states[deleteFrame] = nil
  end
end

function Stack.set_garbage_target(self, new_target)
  self.garbage_target = new_target
  if self.telegraph then
    self.telegraph.owner = new_target
    self.telegraph:updatePosition()
  end
end

local MAX_TAUNT_PER_10_SEC = 4

function Stack.can_taunt(self)
  return self.taunt_queue:len() < MAX_TAUNT_PER_10_SEC or self.taunt_queue:peek() + 10 < love.timer.getTime()
end

function Stack.taunt(self, taunt_type)
  while self.taunt_queue:len() >= MAX_TAUNT_PER_10_SEC do
    self.taunt_queue:pop()
  end
  self.taunt_queue:push(love.timer.getTime())
end

-- Represents an individual panel in the stack
Panel =
  class(
  function(p)
    p:clear()
  end
)

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
  result[#result+1] = 7 -- squares
  return result
end

function Panel.allPossibleColorsArray()
  local result = Panel.extendedRegularColorsArray()
  result[#result+1] = 8 -- shock
  result[#result+1] = 9 -- colorless
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
  self.garbage = nil
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

do
  local exclude_hover_set = {
    matched = true,
    popping = true,
    popped = true,
    hovering = true,
    falling = true
  }
  function Panel.exclude_hover(self)
    return exclude_hover_set[self.state] or self.garbage
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
    return exclude_match_set[self.state] or self.color == 0 or self.color == 9 or (self.state == "hovering" and not self.match_anyway)
  end

  local exclude_swap_set = {
    matched = true,
    popping = true,
    popped = true,
    hovering = true,
    dimmed = true
  }
  function Panel.exclude_swap(self)
    return exclude_swap_set[self.state] or self.dont_swap or self.garbage
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
    return self.color ~= 0 and not (self.state == "falling" and self.garbage)
  end
end

function Panel.has_flags(self)
  return (self.state ~= "normal") or self.is_swapping_from_left or self.dont_swap or self.chaining
end

function Panel.clear_flags(self)
  self.combo_index = nil
  self.combo_size = nil
  self.chain_index = nil
  self.is_swapping_from_left = nil
  self.dont_swap = nil
  self.chaining = nil
  -- Animation timer for "bounce" after falling from garbage.
  self.fell_from_garbage = nil
  self.state = "normal"
end


function Stack.set_puzzle_state(self, puzzle)
  -- Copy the puzzle into our state
  local boardSizeInPanels = self.width * self.height
  while string.len(puzzle.stack) < boardSizeInPanels do
    puzzle.stack = "0" .. puzzle.stack
  end

  local puzzleString = puzzle.stack

  self.puzzle = puzzle
  self.panels = self:puzzleStringToPanels(puzzleString)
  self.do_countdown = puzzle.doCountdown or false
  self.puzzle.remaining_moves = puzzle.moves

  -- transform any cleared garbage into colorless garbage panels
  self.gpanel_buffer = "9999999999999999999999999999999999999999999999999999999999999999999999999"
end

function Stack.puzzleStringToPanels(self, puzzleString)
  local panels = {}
  local garbageStartRow = nil
  local garbageStartColumn = nil
  local isMetal = false
  local connectedGarbagePanels = nil
  local rowCount = string.len(puzzleString) / 6
  -- chunk the aprilstack into rows
  -- it is necessary to go bottom up because garbage block panels contain the offset relative to their bottom left corner
  for row = 1, rowCount do
      local rowString = string.sub(puzzleString, #puzzleString - 5, #puzzleString)
      puzzleString = string.sub(puzzleString, 1, #puzzleString - 6)
      -- copy the panels into the row
      panels[row] = {}
      for column = 6, 1, -1 do
          local color = string.sub(rowString, column, column)
          if not garbageStartRow and tonumber(color) then
            local panel = Panel()
            panel.color = tonumber(color)
            panels[row][column] = panel
          else
            -- start of a garbage block
            if color == "]" or color == "}" then
              garbageStartRow = row
              garbageStartColumn = column
              connectedGarbagePanels = {}
              if color == "}" then
                isMetal = true
              end
            end
            local panel = Panel()
            panel.garbage = true
            panel.color = 9
            panel.y_offset = row - garbageStartRow
            -- iterating the row right to left to make sure we catch the start of each garbage block
            -- but the offset is expected left to right, therefore we can't know the x_offset before reaching the end of the garbage
            -- instead save the column index in that field to calculate it later
            panel.x_offset = column
            panel.metal = isMetal
            panels[row][column] = panel
            table.insert(connectedGarbagePanels, panel)
            -- garbage ends here
            if color == "[" or color == "{" then
              -- calculate dimensions of the garbage and add it to the relevant width/height properties
              local height = connectedGarbagePanels[#connectedGarbagePanels].y_offset + 1
              -- this is disregarding the possible existence of irregularly shaped garbage
              local width = garbageStartColumn - column + 1
              local shake_time = garbage_to_shake_time[width * height]
              for i = 1, #connectedGarbagePanels do
                connectedGarbagePanels[i].x_offset = connectedGarbagePanels[i].x_offset - column
                connectedGarbagePanels[i].height = height
                connectedGarbagePanels[i].width = width
                connectedGarbagePanels[i].shake_time = shake_time
                -- panels are already in the main table and they should already be updated by reference
              end
              garbageStartRow = nil
              garbageStartColumn = nil
              connectedGarbagePanels = nil
              isMetal = false
            end
          end
      end
  end

  -- add row 0 because it crashes if there is no row 0 for whatever reason
  panels[0] = {}
  for column = 6, 1, -1 do
    local panel = Panel()
    panel.color = 0
    panels[0][column] = panel
  end

  return panels
end

function Stack.toPuzzleInfo(self)
  local puzzleInfo = {}
  puzzleInfo["Player"] = self.match.battleRoom.playerNames[self.which]
  puzzleInfo["Stop"] = self.stop_time
  puzzleInfo["Shake"] = self.shake_time
  puzzleInfo["Pre-Stop"] = self.pre_stop_time
  puzzleInfo["Stack"] = Puzzle.toPuzzleString(self.panels)

  return puzzleInfo
end

function Stack.puzzle_done(self)
  if not self.do_countdown then
    -- For now don't require active panels to be 0, we will still animate in game over,
    -- and we need to win immediately to avoid the failure below in the chain case.
    --if P1.n_active_panels == 0 then
    --if self.puzzle.puzzleType == "chain" or P1.n_prev_active_panels == 0 then
    if self.puzzle.puzzleType == "clear" then
      return not self:hasGarbage()
    else
      local panels = self.panels
      for row = 1, self.height do
        for col = 1, self.width do
          local color = panels[row][col].color
          if color ~= 0 and color ~= 9 then
            return false
          end
        end
      end
    end

    return true
  --end
  --end
  end

  return false
end

function Stack.hasGarbage(self)
  -- garbage is more likely to be found at the top of the stack
  for row = #self.panels, 1, -1 do
    for column = 1, #self.panels[row] do
      if self.panels[row][column].garbage and self.panels[row][column].state ~= "matched" then
        return true
      end
    end
  end

  return false
end

function Stack.puzzle_failed(self)
  if not self.do_countdown and not self:hasPendingAction() then
    if self.puzzle.puzzleType == "moves" then
        return self.puzzle.remaining_moves == 0
    elseif self.puzzle.puzzleType == "chain" then
      if #self.analytic.data.reached_chains == 0 and self.analytic.data.destroyed_panels > 0 then
        -- We finished matching but never made a chain -> fail
        return true
      end
      if #self.analytic.data.reached_chains > 0 and self.n_chain_panels == 0 then
        -- We achieved a chain, finished chaining, but haven't won yet -> fail
        return true
      end
    elseif self.puzzle.puzzleType == "clear" then
      if self:hasGarbage() then
        return (self.puzzle.moves > 0 and self.puzzle.remaining_moves <= 0) or self.health <= 0
      end
    end
  end

  return false
end

function Stack.hasPendingAction(self)
  return self.n_active_panels > 0 or self.n_prev_active_panels > 0
end

function Stack.has_falling_garbage(self)
  for i = 1, self.height + 3 do --we shouldn't have to check quite 3 rows above height, but just to make sure...
    local prow = self.panels[i]
    for j = 1, self.width do
      if prow and prow[j].garbage and prow[j].state == "falling" then
        return true
      end
    end
  end
  return false
end

-- Setup the stack at a new starting state
function Stack.starting_state(self, n)
  if self.do_first_row then
    self.do_first_row = nil
    for i = 1, (n or 8) do
      self:new_row()
      self.cur_row = self.cur_row - 1
    end
  end
end

function Stack.prep_first_row(self)
  if self.do_first_row then
    self.do_first_row = nil
    self:new_row()
    self.cur_row = self.cur_row - 1
  end
end

-- Takes the control input from input_state and sets up the engine to start using it.
function Stack.controls(self)
  local new_dir = nil
  local sdata = self.input_state
  local raise, swap, up, down, left, right = unpack(base64decode[sdata])
  if (raise) and (not self.prevent_manual_raise) then
    self.manual_raise = true
    self.manual_raise_yet = false
  end

  self.swap_1 = swap
  self.swap_2 = swap

  if up then
    new_dir = "up"
  elseif down then
    new_dir = "down"
  elseif left then
    new_dir = "left"
  elseif right then
    new_dir = "right"
  end

  if new_dir == self.cur_dir then
    if self.cur_timer ~= self.cur_wait_time then
      self.cur_timer = self.cur_timer + 1
    end
  else
    self.cur_dir = new_dir
    self.cur_timer = 0
  end
end

function Stack.shouldRun(self, runsSoFar) 

  -- We want to run after game over to show game over effects.
  if self:game_ended() then
    return runsSoFar == 0
  end

  -- Decide how many frames of input we should run.
  local buffer_len = string.len(self.input_buffer)

  -- If we are local we always want to catch up and run the new input which is already appended
  if self.is_local then
    return buffer_len > 0
  end

  if self:behindRollback() then
    return true
  end

  -- In debug mode allow forcing a certain number of frames behind
  if config.debug_mode and config.debug_vsFramesBehind and config.debug_vsFramesBehind ~= 0 then
    if (config.debug_vsFramesBehind > 0) == (self.which == 2) then
      -- Don't fall behind if the game is over for the other player
      if self.garbage_target and self.garbage_target:game_ended() == false then
        -- If we are at the end of the replay we want to catch up
        if network_connected() or string.len(self.garbage_target.input_buffer) > 0 then
          local framesBehind = math.abs(config.debug_vsFramesBehind)
          if self.CLOCK >= self.garbage_target.CLOCK - framesBehind then
            return false
          end
        end
      end
    end
  end
    
  -- If we are not local, we want to run faster to catch up.
  if buffer_len >= 15 - runsSoFar then
    -- way behind, run at max speed.
    return runsSoFar < self.max_runs_per_frame
  elseif buffer_len >= 10 - runsSoFar then
    -- When we're closer, run fewer times per frame, so things are less choppy.
    -- This might have a side effect of taking a little longer to catch up
    -- since we don't always run at top speed.
    local maxRuns = math.min(2, self.max_runs_per_frame)
    return runsSoFar < maxRuns
  elseif buffer_len >= 1 then
    return runsSoFar == 0
  end

  return false
end

-- Runs one step of the stack.
function Stack.run(self)
  if GAME.gameIsPaused then
    return
  end

  if self.is_local == false then
    if self.play_to_end then
      GAME.preventSounds = true
      if string.len(self.input_buffer) < 4 then
        self.play_to_end = nil
        GAME.preventSounds = false
      end
    end
  end

  self:setupInput()
  self:simulate()
end

-- Grabs input from the buffer of inputs or from the controller and sends out to the network if needed.
function Stack.setupInput(self) 
  self.input_state = nil

  if self:game_ended() == false then 
    if self.input_buffer and string.len(self.input_buffer) > 0 then
      self.input_state = string.sub(self.input_buffer, 1, 1)
      self.input_buffer = string.sub(self.input_buffer, 2)
    end
  else
    self.input_state = self:idleInput()
  end

  self:controls()
end

function Stack.receiveConfirmedInput(self, input)
  if string.len(input) == 1 then
    self.confirmedInput[#self.confirmedInput+1] = input
  else
    local inputs = string.toCharTable(input)
    table.appendToList(self.confirmedInput, inputs)
  end
  self.input_buffer = self.input_buffer .. input
  --logger.debug("Player " .. self.which .. " got new input. Total length: " .. #self.confirmedInput)
end

-- Enqueue a card animation
function Stack.enqueue_card(self, chain, x, y, n)
  if self.canvas == nil then
    return
  end

  card_burstAtlas = nil
  card_burstParticle = nil
  if config.popfx == true then
    card_burstAtlas = characters[self.character].images["burst"]
    card_burstFrameDimension = card_burstAtlas:getWidth() / 9
    card_burstParticle = love.graphics.newQuad(card_burstFrameDimension, 0, card_burstFrameDimension, card_burstFrameDimension, card_burstAtlas:getDimensions())
  end
  self.card_q:push({frame = 1, chain = chain, x = x, y = y, n = n, burstAtlas = card_burstAtlas, burstParticle = card_burstParticle})
end

-- Enqueue a pop animation
function Stack.enqueue_popfx(self, x, y, popsize)
  if self.canvas == nil then
    return
  end

  if characters[self.character].images["burst"] then
    burstAtlas = characters[self.character].images["burst"]
    burstFrameDimension = burstAtlas:getWidth() / 9
    burstParticle = love.graphics.newQuad(burstFrameDimension, 0, burstFrameDimension, burstFrameDimension, burstAtlas:getDimensions())
    bigParticle = love.graphics.newQuad(0, 0, burstFrameDimension, burstFrameDimension, burstAtlas:getDimensions())
  end
  if characters[self.character].images["fade"] then
    fadeAtlas = characters[self.character].images["fade"]
    fadeFrameDimension = fadeAtlas:getWidth() / 9
    fadeParticle = love.graphics.newQuad(fadeFrameDimension, 0, fadeFrameDimension, fadeFrameDimension, fadeAtlas:getDimensions())
  end
  poptype = "small"
  self.pop_q:push(
    {
      frame = 1,
      burstAtlas = burstAtlas,
      burstFrameDimension = burstFrameDimension,
      burstParticle = burstParticle,
      fadeAtlas = fadeAtlas,
      fadeFrameDimension = fadeFrameDimension,
      fadeParticle = fadeParticle,
      bigParticle = bigParticle,
      bigTimer = 0,
      popsize = popsize,
      x = x,
      y = y
    }
  )
end

local d_col = {up = 0, down = 0, left = -1, right = 1}
local d_row = {up = 1, down = -1, left = 0, right = 0}

-- One run of the engine routine.
function Stack.simulate(self)
  -- Don't run the main logic if the player has simulated past one of the game overs or the time attack time
  if self:game_ended() == false then
    self:prep_first_row()
    local panels = self.panels
    local width = self.width
    local height = self.height
    local prow = nil
    local panel = nil
    local swapped_this_frame = nil
    if self.do_countdown then
      self.game_stopwatch_running = false
      self.rise_lock = true
      if not self.countdown_cursor_state then
        self.countdown_CLOCK = self.CLOCK
        self.starting_cur_row = self.cur_row
        self.starting_cur_col = self.cur_col
        self.cur_row = self.height
        self.cur_col = self.width - 1
        self.countdown_cursor_state = "ready_falling"
        self.countdown_cur_speed = 4 --one move every this many frames
        self.cursor_lock = true
      end
      if self.countdown_CLOCK == 8 then
        self.countdown_cursor_state = "moving_down"
        self.countdown_timer = 180 --3 seconds at 60 fps
      elseif self.countdown_cursor_state == "moving_down" then
        --move down
        if self.cur_row == self.starting_cur_row then
          self.countdown_cursor_state = "moving_left"
        elseif self.CLOCK % self.countdown_cur_speed == 0 then
          self.cur_row = self.cur_row - 1
        end
      elseif self.countdown_cursor_state == "moving_left" then
        --move left
        if self.cur_col == self.starting_cur_col then
          self.countdown_cursor_state = "ready"
          self.cursor_lock = nil
        elseif self.CLOCK % self.countdown_cur_speed == 0 then
          self.cur_col = self.cur_col - 1
        end
      end
      if self.countdown_timer then
        if self.countdown_timer == 0 then
          --we are done counting down
          self.do_countdown = nil
          self.countdown_timer = nil
          self.starting_cur_row = nil
          self.starting_cur_col = nil
          self.countdown_CLOCK = nil
          self.game_stopwatch_running = true
          if self.which == 1 and self:shouldChangeSoundEffects() then
            SFX_Go_Play = 1
          end
        elseif self.countdown_timer and self.countdown_timer % 60 == 0 and self.which == 1 then
          --play beep for timer dropping to next second in 3-2-1 countdown
          if self.which == 1 and self:shouldChangeSoundEffects() then
            SFX_Countdown_Play = 1
          end
        end
        if self.countdown_timer then
          self.countdown_timer = self.countdown_timer - 1
        end
      end
      if self.countdown_CLOCK then
        self.countdown_CLOCK = self.countdown_CLOCK + 1
      end
    else 
      self.game_stopwatch_running = true
    end

    if self.pre_stop_time ~= 0 then
      self.pre_stop_time = self.pre_stop_time - 1
    elseif self.stop_time ~= 0 then
      self.stop_time = self.stop_time - 1
    end

    self.panels_in_top_row = false
    local top_row = self.height
    --self.displacement%16==0 and self.height or self.height-1
    prow = panels[top_row]
    for idx = 1, width do
      if prow[idx]:dangerous() then
        self.panels_in_top_row = true
      end
    end

    -- calculate which columns should bounce
    self.danger = false
    prow = panels[self.height - 1]
    for idx = 1, width do
      if prow[idx]:dangerous() then
        self.danger = true
        self.danger_col[idx] = true
      else
        self.danger_col[idx] = false
      end
    end
    if self.danger then
      if self.panels_in_top_row and self.speed ~= 0 and self.match.mode ~= "puzzle" then
        -- Player has topped out, panels hold the "flattened" frame
        self.danger_timer = 15
      elseif self.stop_time == 0 then
        self.danger_timer = self.danger_timer - 1
      end
      if self.danger_timer < 0 then
        self.danger_timer = 17
      end
    end

    -- determine whether to play danger music
    -- Changed this to play danger when something in top 3 rows
    -- and to play casual when nothing in top 3 or 4 rows
    if not self.danger_music then
      -- currently playing casual
      for _, prow in pairs({panels[self.height], panels[self.height - 1], panels[self.height - 2]}) do
        for idx = 1, width do
          if prow[idx].color ~= 0 and prow[idx].state ~= "falling" or prow[idx]:dangerous() then
            self.danger_music = true
            break
          end
        end
      end
      if self.shake_time > 0 then
        self.danger_music = false
      end
    else
      --currently playing danger
      local toggle_back = true
      -- Normally, change back if nothing is in the top 3 rows
      local changeback_rows = {panels[self.height], panels[self.height - 1], panels[self.height - 2]}
      -- But optionally, wait until nothing is in the fourth row
      if (config.danger_music_changeback_delay) then
        table.insert(changeback_rows, panels[self.height - 3])
      end
      for _, prow in pairs(changeback_rows) do
        if prow ~= nil and type(prow) == "table" then
          for idx = 1, width do
            if prow[idx].color ~= 0 then
              toggle_back = false
              break
            end
          end
        elseif self.warningsTriggered["Panels Invalid"] == nil then
          logger.warn("Panels have invalid data in them, please tell your local developer." .. dump(panels, true))
          self.warningsTriggered["Panels Invalid"] = true
        end
      end
      self.danger_music = not toggle_back
    end

    if self.displacement == 0 and self.has_risen then
      self.top_cur_row = self.height
      self:new_row()
    end
    self.prev_rise_lock = self.rise_lock
    self.rise_lock = self.n_active_panels ~= 0 or self.n_prev_active_panels ~= 0 or self.shake_time ~= 0 or self.do_countdown or self.do_swap
    if self.prev_rise_lock and not self.rise_lock then
      self.prevent_manual_raise = false
    end

    -- Increase the speed if applicable
    if self.speed_times then
      local time = self.speed_times[self.speed_times.idx]
      if self.CLOCK == time then
        self.speed = min(self.speed + 1, 99)
        self.FRAMECOUNT_RISE = speed_to_rise_time[self.speed]
        if self.speed_times.idx ~= #self.speed_times then
          self.speed_times.idx = self.speed_times.idx + 1
        else
          self.speed_times[self.speed_times.idx] = time + self.speed_times.delta
        end
      end
    elseif self.panels_to_speedup <= 0 then
      self.speed = min(self.speed + 1, 99)
      self.panels_to_speedup = self.panels_to_speedup + panels_to_next_speed[self.speed]
      self.FRAMECOUNT_RISE = speed_to_rise_time[self.speed]
    end

    -- Phase 0 //////////////////////////////////////////////////////////////
    -- Stack automatic rising
    if self.speed ~= 0 and not self.manual_raise and self.stop_time == 0 and not self.rise_lock then
      if self.match.mode == "puzzle" then
        -- only reduce health after the first swap to give the player a chance to strategize
        if self.puzzle.puzzleType == "clear" and self.puzzle.remaining_moves - self.puzzle.moves < 0 and self.shake_time < 1 then
          self.health = self.health - 1
          -- no gameover because it can't return otherwise, exit is taken care of by puzzle_failed
        end
      else
        if self.panels_in_top_row then
          self.health = self.health - 1
          if self.health < 1 and self.shake_time < 1 then
            self:set_game_over()
          end
        else
          if self.match.mode ~= "puzzle" then
            self.rise_timer = self.rise_timer - 1
            if self.rise_timer <= 0 then -- try to rise
              self.displacement = self.displacement - 1
              if self.displacement == 0 then
                self.prevent_manual_raise = false
                self.top_cur_row = self.height
                self:new_row()
              end
              self.rise_timer = self.rise_timer + self.FRAMECOUNT_RISE
            end
          end
        end
      end
    end

    if not self.panels_in_top_row and self.match.mode ~= "puzzle" and not self:has_falling_garbage() then
      self.health = self.max_health
    end

    if self.displacement % 16 ~= 0 then
      self.top_cur_row = self.height - 1
    end

    -- Begin the swap we input last frame.
    if self.do_swap then
      self:swap()
      swapped_this_frame = true
      self.do_swap = nil
    end

    -- Look for matches.
    self:check_matches()
    -- Clean up the value we're using to match newly hovering panels
    -- This is pretty dirty :(
    for row = 1, #panels do
      for col = 1, width do
        panels[row][col].match_anyway = nil
      end
    end

    -- Phase 2. /////////////////////////////////////////////////////////////
    -- Timer-expiring actions + falling
    local propogate_fall = {false, false, false, false, false, false}
    local skip_col = 0
    local fallen_garbage = 0
    local shake_time = 0
    popsize = "small"
    for row = 1, #panels do
      for col = 1, width do
        local cntinue = false
        if skip_col > 0 then
          skip_col = skip_col - 1
          cntinue = true
        end
        panel = panels[row][col]
        if cntinue then
        elseif panel.garbage then
          if panel.state == "matched" then
            -- try to fall
            panel.timer = panel.timer - 1
            if panel.timer == panel.pop_time then
              if config.popfx == true then
                self:enqueue_popfx(col, row, popsize)
              end
              if self:shouldChangeSoundEffects() then
                SFX_Garbage_Pop_Play = panel.pop_index
              end
            end
            if panel.timer == 0 then
              if panel.y_offset == -1 then
                local color, chaining = panel.color, panel.chaining
                panel:clear()
                panel.color, panel.chaining = color, chaining
                self:set_hoverers(row, col, self.FRAMECOUNT_GPHOVER, true, true)
                panel.fell_from_garbage = 12
              else
                panel.state = "normal"
              end
            end
          elseif (panel.state == "normal" or panel.state == "falling") then
            if panel.x_offset == 0 then
              local prow = panels[row - 1]
              local supported = false
              if panel.y_offset == 0 then
                for i = col, col + panel.width - 1 do
                  supported = supported or prow[i]:support_garbage()
                end
              else
                supported = not propogate_fall[col]
              end
              if supported then
                for x = col, col - 1 + panel.width do
                  panels[row][x].state = "normal"
                  propogate_fall[x] = false
                end
              else
                skip_col = panel.width - 1
                for x = col, col - 1 + panel.width do
                  panels[row - 1][x]:clear()
                  propogate_fall[x] = true
                  panels[row][x].state = "falling"
                  panels[row - 1][x], panels[row][x] = panels[row][x], panels[row - 1][x]
                end
              end
            end
            if panel.shake_time and panel.state == "normal" then
              if row <= self.height then
                if self:shouldChangeSoundEffects() then
                  if panel.height > 3 then
                    self.sfx_garbage_thud = 3
                  else
                    self.sfx_garbage_thud = panel.height
                  end
                end
                shake_time = max(shake_time, panel.shake_time, self.peak_shake_time or 0)
                --a smaller garbage block landing should renew the largest of the previous blocks' shake times since our shake time was last zero.
                self.peak_shake_time = max(shake_time, self.peak_shake_time or 0)
                panel.shake_time = nil
              end
            end
          end
          cntinue = true
        end
        if propogate_fall[col] and not cntinue then
          if panel:block_garbage_fall() then
            propogate_fall[col] = false
          else
            panel.state = "falling"
            panel.timer = 0
          end
        end
        if cntinue then
        elseif panel.state == "falling" then
          -- if it's on the bottom row, it should surely land
          if row == 1 then
            -- if there's a panel below, this panel's gonna land
            -- unless the panel below is falling.
            panel.state = "landing"
            panel.timer = 12
            if self:shouldChangeSoundEffects() then
              self.sfx_land = true
            end
          elseif panels[row - 1][col].color ~= 0 and panels[row - 1][col].state ~= "falling" then
            -- if it lands on a hovering panel, it inherits
            -- that panel's hover time.
            if panels[row - 1][col].state == "hovering" then
              panel.state = "normal"
              self:set_hoverers(row, col, panels[row - 1][col].timer, false, false)
            else
              panel.state = "landing"
              panel.timer = 12
            end
            if self:shouldChangeSoundEffects() then
              self.sfx_land = true
            end
          else
            panels[row - 1][col], panels[row][col] = panels[row][col], panels[row - 1][col]
            panels[row][col]:clear()
          end
        elseif panel:has_flags() and panel.timer ~= 0 then
          panel.timer = panel.timer - 1
          if panel.timer == 0 then
            if panel.state == "swapping" then
              -- a swap has completed here.
              panel.state = "normal"
              panel.dont_swap = nil
              local from_left = panel.is_swapping_from_left
              panel.is_swapping_from_left = nil
              -- Now there are a few cases where some hovering must
              -- be done.
              if panel.color ~= 0 then
                if row ~= 1 then
                  if panels[row - 1][col].color == 0 then
                    self:set_hoverers(row, col, self.FRAMECOUNT_HOVER, false, true, false)
                    -- if there is no panel beneath this panel
                    -- it will begin to hover.
                    -- CRAZY BUG EMULATION:
                    -- the space it was swapping from hovers too
                    if from_left then
                      if panels[row][col - 1].state == "falling" then
                        self:set_hoverers(row, col - 1, self.FRAMECOUNT_HOVER, false, true)
                      end
                    else
                      if panels[row][col + 1].state == "falling" then
                        self:set_hoverers(row, col + 1, self.FRAMECOUNT_HOVER + 1, false, false)
                      end
                    end
                  elseif panels[row - 1][col].state == "hovering" then
                    -- swap may have landed on a hover
                    self:set_hoverers(row, col, self.FRAMECOUNT_HOVER, false, true, panels[row - 1][col].match_anyway, "inherited")
                  end
                end
              else
                -- an empty space finished swapping...
                -- panels above it hover
                self:set_hoverers(row + 1, col, self.FRAMECOUNT_HOVER + 1, false, false, false, "empty")
              end
            elseif panel.state == "hovering" then
              if panels[row - 1][col].state == "hovering" then
                -- This panel is no longer hovering.
                -- it will now fall without sitting around
                -- for any longer!
                panel.timer = panels[row - 1][col].timer
              elseif panels[row - 1][col].color ~= 0 then
                panel.state = "landing"
                panel.timer = 12
              else
                panel.state = "falling"
                panels[row][col], panels[row - 1][col] = panels[row - 1][col], panels[row][col]
                panel.timer = 0
                -- Not sure if needed:
                panels[row][col]:clear_flags()
              end
            elseif panel.state == "landing" then
              panel.state = "normal"
            elseif panel.state == "matched" then
              -- This panel's match just finished the whole
              -- flashing and looking distressed thing.
              -- It is given a pop time based on its place
              -- in the match.
              panel.state = "popping"
              panel.timer = panel.combo_index * self.FRAMECOUNT_POP
            elseif panel.state == "popping" then
              --logger.debug("POP")
              if (panel.combo_size > 6) or self.chain_counter > 1 then
                popsize = "normal"
              end
              if self.chain_counter > 2 then
                popsize = "big"
              end
              if self.chain_counter > 3 then
                popsize = "giant"
              end
              if config.popfx == true then
                self:enqueue_popfx(col, row, popsize)
              end
              self.score = self.score + 10
              -- self.score_render=1;
              -- TODO: What is self.score_render?
              -- this panel just popped
              -- Now it's invisible, but sits and waits
              -- for the last panel in the combo to pop
              -- before actually being removed.

              -- If it is the last panel to pop,
              -- it should be removed immediately!
              if panel.combo_size == panel.combo_index then
                self.panels_cleared = self.panels_cleared + 1
                if self.match.mode == "vs" and self.panels_cleared % level_to_metal_panel_frequency[self.level] == 0 then
                  self.metal_panels_queued = min(self.metal_panels_queued + 1, level_to_metal_panel_cap[self.level])
                end
                if self:shouldChangeSoundEffects() then
                  SFX_Pop_Play = 1
                end
                self.poppedPanelIndex = panel.combo_index
                panel.color = 0
		if self.panels_to_speedup then
	          self.panels_to_speedup = self.panels_to_speedup - 1
	        end
                if panel.chaining then
                  self.n_chain_panels = self.n_chain_panels - 1
                end
                panel:clear_flags()
                self:set_hoverers(row + 1, col, self.FRAMECOUNT_HOVER + 1, true, false, true, "combo")
              else
                panel.state = "popped"
                panel.timer = (panel.combo_size - panel.combo_index) * self.FRAMECOUNT_POP
                self.panels_cleared = self.panels_cleared + 1
                if self.match.mode == "vs" and self.panels_cleared % level_to_metal_panel_frequency[self.level] == 0 then
                  self.metal_panels_queued = min(self.metal_panels_queued + 1, level_to_metal_panel_cap[self.level])
                end
                if self:shouldChangeSoundEffects() then
                  SFX_Pop_Play = 1
                end
                self.poppedPanelIndex = panel.combo_index
              end
            elseif panel.state == "popped" then
              -- It's time for this panel
              -- to be gone forever :'(
              if self.panels_to_speedup then
                self.panels_to_speedup = self.panels_to_speedup - 1
              end
              if panel.chaining then
                self.n_chain_panels = self.n_chain_panels - 1
              end
              panel.color = 0
              panel:clear_flags()
              -- Any panels sitting on top of it
              -- hover and are flagged as CHAINING
              self:set_hoverers(row + 1, col, self.FRAMECOUNT_HOVER + 1, true, false, true, "popped")
            elseif panel.state == "dead" then
              -- Nothing to do here, the player lost.
            else
              -- what the heck.
              -- if a timer runs out and the routine can't
              -- figure out what flag it is, tell brandon.
              -- No seriously, email him or something.
              error("something terrible happened\n" .. "panel.state was " .. tostring(panel.state) .. " when a timer expired?!\n" .. "panel.is_swapping_from_left = " .. tostring(panel.is_swapping_from_left) .. "\n" .. "panel.dont_swap = " .. tostring(panel.dont_swap) .. "\n" .. "panel.chaining = " .. tostring(panel.chaining))
            end
          -- the timer-expiring action has completed
          end
        end
        -- Advance the fell-from-garbage bounce timer, or clear it and stop animating if the panel isn't hovering or falling.
        if cntinue then
        elseif panel.fell_from_garbage then
          if panel.state ~= "hovering" and panel.state ~= "falling" then
            panel.fell_from_garbage = nil
          else
            panel.fell_from_garbage = panel.fell_from_garbage - 1
          end
        end
      end
    end

    local prev_shake_time = self.shake_time
    self.shake_time = self.shake_time - 1
    self.shake_time = max(self.shake_time, shake_time)
    if self.shake_time == 0 then
      self.peak_shake_time = 0
    end

    -- Phase 3. /////////////////////////////////////////////////////////////
    -- Actions performed according to player input

    -- CURSOR MOVEMENT
    local playMoveSounds = true -- set this to false to disable move sounds for debugging
    if self.cur_dir and (self.cur_timer == 0 or self.cur_timer == self.cur_wait_time) and not self.cursor_lock then
      local prev_row = self.cur_row
      local prev_col = self.cur_col
      self.cur_row = bound(1, self.cur_row + d_row[self.cur_dir], self.top_cur_row)
      self.cur_col = bound(1, self.cur_col + d_col[self.cur_dir], width - 1)
      if (playMoveSounds and (self.cur_timer == 0 or self.cur_timer == self.cur_wait_time) and (self.cur_row ~= prev_row or self.cur_col ~= prev_col)) then
        if self:shouldChangeSoundEffects() then
          SFX_Cur_Move_Play = 1
        end
        if self.cur_timer ~= self.cur_wait_time then
          self.analytic:register_move()
        end
      end
    else
      self.cur_row = bound(1, self.cur_row, self.top_cur_row)
    end

    if self.cur_timer ~= self.cur_wait_time then
      self.cur_timer = self.cur_timer + 1
    end
    -- TAUNTING
    if self:shouldChangeSoundEffects() then
      if self.taunt_up ~= nil then
        for _, t in ipairs(characters[self.character].sounds.taunt_ups) do
          t:stop()
        end
        characters[self.character].sounds.taunt_ups[self.taunt_up]:play()
        self:taunt("taunt_up")
        self.taunt_up = nil
      elseif self.taunt_down ~= nil then
        for _, t in ipairs(characters[self.character].sounds.taunt_downs) do
          t:stop()
        end
        characters[self.character].sounds.taunt_downs[self.taunt_down]:play()
        self:taunt("taunt_down")
        self.taunt_down = nil
      end
    end

    -- SWAPPING
    if (self.swap_1 or self.swap_2) and not swapped_this_frame then
      local do_swap = self:canSwap(self.cur_row, self.cur_col)

      if do_swap then
        self.do_swap = true
        self.analytic:register_swap()
      end
      self.swap_1 = false
      self.swap_2 = false
    end

    -- MANUAL STACK RAISING
    if self.manual_raise and self.match.mode ~= "puzzle" then
      if not self.rise_lock then
        if self.panels_in_top_row then
          self:set_game_over()
        end
        self.has_risen = true
        self.displacement = self.displacement - 1
        if self.displacement == 1 then
          self.manual_raise = false
          self.rise_timer = 1
          if not self.prevent_manual_raise then
            self.score = self.score + 1
          end
          self.prevent_manual_raise = true
        end
        self.manual_raise_yet = true --ehhhh
        self.stop_time = 0
      elseif not self.manual_raise_yet then
        self.manual_raise = false
      end
    -- if the stack is rise locked when you press the raise button,
    -- the raising is cancelled
    end

    -- if at the end of the routine there are no chain panels, the chain ends.
    if self.chain_counter ~= 0 and self.n_chain_panels == 0 then
      self.chains[self.chains.current].finish = self.CLOCK
      self.chains[self.chains.current].size = self.chain_counter
      self.chains.last_complete = self.current
      self.chains.current = nil
      if self:shouldChangeSoundEffects() then
        SFX_Fanfare_Play = self.chain_counter
      end
      self.analytic:register_chain(self.chain_counter)
      self.chain_counter = 0

      if self.garbage_target and self.garbage_target.telegraph then
        self.telegraph:chainingEnded(self.CLOCK)
      end
    end

    if (self.score > 99999) then
      self.score = 99999
    -- lol owned
    end

    self.n_prev_active_panels = self.n_active_panels
    self.n_active_panels = 0
    self.active_panels = {}
    for row = 1, self.height do
      for col = 1, self.width do
        local panel = panels[row][col]
        if (panel.garbage and panel.state ~= "normal") or (panel.color ~= 0 and panel.state ~= "landing" and (panel:exclude_hover() or panel.state == "swapping") and not panel.garbage) or panel.state == "swapping" then
          self.n_active_panels = self.n_active_panels + 1
        end
      end
    end

    if self.telegraph then
      local to_send = self.telegraph:pop_all_ready_garbage(self.CLOCK)
      if to_send and to_send[1] then
        -- Right now the training attacks are put on the players telegraph, 
        -- but they really should be a seperate telegraph since the telegraph on the player's stack is for sending outgoing attacks.
        local receiver = self.garbage_target or self 
        receiver:receiveGarbage(self.CLOCK + GARBAGE_DELAY_LAND_TIME, to_send)
      end
    end
    
    if self.later_garbage[self.CLOCK] then
      self.garbage_q:push(self.later_garbage[self.CLOCK])
      self.later_garbage[self.CLOCK] = nil
    end

    self:remove_extra_rows()
    
    --double-check panels_in_top_row

    self.panels_in_top_row = false
    -- If any dangerous panels are in the top row, garbage should not fall.
    for col_idx = 1, width do
      if panels[top_row][col_idx]:dangerous() then
        self.panels_in_top_row = true
      end
    end

    -- local garbage_fits_in_populated_top_row 
    -- if self.garbage_q:len() > 0 then
    --   --even if there are some panels in the top row,
    --   --check if the next block in the garbage_q would fit anyway
    --   --ie. 3-wide garbage might fit if there are three empty spaces where it would spawn
    --   garbage_fits_in_populated_top_row = true
    --   local next_garbage_block_width, next_garbage_block_height, _metal, from_chain = unpack(self.garbage_q:peek())
    --   local cols = self.garbage_cols[next_garbage_block_width]
    --   local spawn_col = cols[cols.idx]
    --   local spawn_row = #self.panels
    --   for idx=spawn_col, spawn_col+next_garbage_block_width-1 do
    --     if prow[idx]:dangerous() then 
    --       garbage_fits_in_populated_top_row = nil
    --     end
    --   end
    -- end
    
    -- If any panels (dangerous or not) are in rows above the top row, garbage should not fall.
    for row_idx = top_row + 1, #self.panels do
      for col_idx = 1, width do
        if panels[row_idx][col_idx].color ~= 0 then
          self.panels_in_top_row = true
        end
      end
    end

    if self.garbage_q:len() > 0 then
      local next_garbage_block_width, next_garbage_block_height, _metal, from_chain = unpack(self.garbage_q:peek())
      local drop_it = not self.panels_in_top_row and not self:has_falling_garbage() and ((from_chain and next_garbage_block_height > 1) or (self.n_active_panels == 0 and self.n_prev_active_panels == 0))
      if drop_it and self.garbage_q:len() > 0 then
        if self:drop_garbage(unpack(self.garbage_q:peek())) then
          self.garbage_q:pop()
        end
      end
    end

    -- Update Music
    if self:shouldChangeMusic() then
      if self.do_countdown then
        if SFX_Go_Play == 1 then
          themes[config.theme].sounds.go:stop()
          themes[config.theme].sounds.go:play()
          SFX_Go_Play = 0
        elseif SFX_Countdown_Play == 1 then
          themes[config.theme].sounds.countdown:stop()
          themes[config.theme].sounds.countdown:play()
          SFX_Go_Play = 0
        end
      else
        local winningPlayer = self
        if GAME.battleRoom then
          winningPlayer = GAME.battleRoom:winningPlayer(P1, P2)
        end

        local musics_to_use = nil
        local dynamicMusic = false
        local stageHasMusic = current_stage and stages[current_stage].musics and stages[current_stage].musics["normal_music"]
        local characterHasMusic = winningPlayer.character and characters[winningPlayer.character].musics and characters[winningPlayer.character].musics["normal_music"]
        if ((current_use_music_from == "stage") and stageHasMusic) or not characterHasMusic then
          if stages[current_stage].music_style == "dynamic" then
            dynamicMusic = true
          end
          musics_to_use = stages[current_stage].musics
        elseif characterHasMusic then
          if characters[winningPlayer.character].music_style == "dynamic" then
            dynamicMusic = true
          end
          musics_to_use = characters[winningPlayer.character].musics
        else
          -- no music loaded
        end

        local wantsDangerMusic = self.danger_music
        if self.garbage_target and self.garbage_target.danger_music then
          wantsDangerMusic = true
        end

        if dynamicMusic then
          local fadeLength = 60
          if not self.fade_music_clock then
            self.fade_music_clock = fadeLength -- start fully faded in
            self.match.current_music_is_casual = true
          end

          local normalMusic = {musics_to_use["normal_music"], musics_to_use["normal_music_start"]}
          local dangerMusic = {musics_to_use["danger_music"], musics_to_use["danger_music_start"]}

          if #currently_playing_tracks == 0 then
            find_and_add_music(musics_to_use, "normal_music")
            find_and_add_music(musics_to_use, "danger_music")
          end

          -- Do we need to switch music?
          if self.match.current_music_is_casual ~= wantsDangerMusic then
            self.match.current_music_is_casual = not self.match.current_music_is_casual

            if self.fade_music_clock >= fadeLength then
              self.fade_music_clock = 0 -- Do a full fade
            else
              -- switched music before we fully faded, so start part way through
              self.fade_music_clock = fadeLength - self.fade_music_clock
            end
          end

          if self.fade_music_clock < fadeLength then
            self.fade_music_clock = self.fade_music_clock + 1
          end

          local fadePercentage = self.fade_music_clock / fadeLength
          if wantsDangerMusic then
            setFadePercentageForGivenTracks(1 - fadePercentage, normalMusic)
            setFadePercentageForGivenTracks(fadePercentage, dangerMusic)
          else
            setFadePercentageForGivenTracks(fadePercentage, normalMusic)
            setFadePercentageForGivenTracks(1 - fadePercentage, dangerMusic)
          end
        else -- classic music
          if wantsDangerMusic then --may have to rethink this bit if we do more than 2 players
            if (self.match.current_music_is_casual or #currently_playing_tracks == 0) and musics_to_use["danger_music"] then -- disabled when danger_music is unspecified
              stop_the_music()
              find_and_add_music(musics_to_use, "danger_music")
              self.match.current_music_is_casual = false
            elseif #currently_playing_tracks == 0 and musics_to_use["normal_music"] then
              stop_the_music()
              find_and_add_music(musics_to_use, "normal_music")
              self.match.current_music_is_casual = true
            end
          else --we should be playing normal_music or normal_music_start
            if (not self.match.current_music_is_casual or #currently_playing_tracks == 0) and musics_to_use["normal_music"] then
              stop_the_music()
              find_and_add_music(musics_to_use, "normal_music")
              self.match.current_music_is_casual = true
            end
          end
        end
      end
    end

    -- Update Sound FX
    if self:shouldChangeSoundEffects() then
      if SFX_Swap_Play == 1 then
        themes[config.theme].sounds.swap:stop()
        themes[config.theme].sounds.swap:play()
        SFX_Swap_Play = 0
      end
      if SFX_Cur_Move_Play == 1 then
        if not (self.match.mode == "vs" and themes[config.theme].sounds.swap:isPlaying()) and not self.do_countdown then
          themes[config.theme].sounds.cur_move:stop()
          themes[config.theme].sounds.cur_move:play()
        end
        SFX_Cur_Move_Play = 0
      end
      if self.sfx_land then
        themes[config.theme].sounds.land:stop()
        themes[config.theme].sounds.land:play()
        self.sfx_land = false
      end
      if SFX_Countdown_Play == 1 then
        if self.which == 1 then
          themes[config.theme].sounds.countdown:stop()
          themes[config.theme].sounds.countdown:play()
        end
        SFX_Countdown_Play = 0
      end
      if SFX_Go_Play == 1 then
        if self.which == 1 then
          themes[config.theme].sounds.go:stop()
          themes[config.theme].sounds.go:play()
        end
        SFX_Go_Play = 0
      end
      if self.combo_chain_play then
        themes[config.theme].sounds.land:stop()
        themes[config.theme].sounds.pops[self.lastPopLevelPlayed][self.lastPopIndexPlayed]:stop()
        characters[self.character]:play_combo_chain_sfx(self.combo_chain_play)
        self.combo_chain_play = nil
      end
      if SFX_garbage_match_play then
        for _, v in pairs(characters[self.character].sounds.garbage_matches) do
          v:stop()
        end
        if #characters[self.character].sounds.garbage_matches ~= 0 then
          characters[self.character].sounds.garbage_matches[math.random(#characters[self.character].sounds.garbage_matches)]:play()
        end
        SFX_garbage_match_play = nil
      end
      if SFX_Fanfare_Play == 0 then
        --do nothing
      elseif SFX_Fanfare_Play >= 6 then
        themes[config.theme].sounds.fanfare3:play()
      elseif SFX_Fanfare_Play >= 5 then
        themes[config.theme].sounds.fanfare2:play()
      elseif SFX_Fanfare_Play >= 4 then
        themes[config.theme].sounds.fanfare1:play()
      end
      SFX_Fanfare_Play = 0
      if self.sfx_garbage_thud >= 1 and self.sfx_garbage_thud <= 3 then
        local interrupted_thud = nil
        for i = 1, 3 do
          if themes[config.theme].sounds.garbage_thud[i]:isPlaying() and self.shake_time > prev_shake_time then
            themes[config.theme].sounds.garbage_thud[i]:stop()
            interrupted_thud = i
          end
        end
        if interrupted_thud and interrupted_thud > self.sfx_garbage_thud then
          themes[config.theme].sounds.garbage_thud[interrupted_thud]:play()
        else
          themes[config.theme].sounds.garbage_thud[self.sfx_garbage_thud]:play()
        end
        if #characters[self.character].sounds.garbage_lands ~= 0 and interrupted_thud == nil then
          for _, v in pairs(characters[self.character].sounds.garbage_lands) do
            v:stop()
          end
          characters[self.character].sounds.garbage_lands[math.random(#characters[self.character].sounds.garbage_lands)]:play()
        end
        self.sfx_garbage_thud = 0
      end
      if SFX_Pop_Play or SFX_Garbage_Pop_Play then
        local popLevel = min(max(self.chain_counter, 1), 4)
        local popIndex = 1
        if SFX_Garbage_Pop_Play then
          popIndex = min(SFX_Garbage_Pop_Play + self.poppedPanelIndex, 10)
        else
          popIndex = min(self.poppedPanelIndex, 10)
        end
        --stop the previous pop sound
        themes[config.theme].sounds.pops[self.lastPopLevelPlayed][self.lastPopIndexPlayed]:stop()
        --play the appropriate pop sound
        themes[config.theme].sounds.pops[popLevel][popIndex]:play()
        self.lastPopLevelPlayed = popLevel
        self.lastPopIndexPlayed = popIndex
        SFX_Pop_Play = nil
        SFX_Garbage_Pop_Play = nil
      end
      if self.game_over or (self.garbage_target and self.garbage_target.game_over) then
        if self:shouldChangeSoundEffects() then
          SFX_GameOver_Play = 1
        end
      end
    end

    self.CLOCK = self.CLOCK + 1

    if self.garbage_target and self.CLOCK > self.garbage_target.CLOCK + MAX_LAG then
      self.garbage_target.tooFarBehindError = true
    end

    local gameEndedClockTime = self.match:gameEndedClockTime()
    if self.game_stopwatch_running and (gameEndedClockTime == 0 or self.CLOCK <= gameEndedClockTime) then
      self.game_stopwatch = (self.game_stopwatch or -1) + 1
    end
  end

  self:update_popfxs()
  self:update_cards()
end

function Stack:receiveGarbage(frameToReceive, garbageList)

  -- If we are past the frame the attack would be processed we need to rollback
  if self.CLOCK > frameToReceive then
    self:rollbackToFrame(frameToReceive)
  end

  local garbage = self.later_garbage[frameToReceive] or {}
  for i = 1, #garbageList do
    garbage[#garbage + 1] = garbageList[i]
  end
  self.later_garbage[frameToReceive] = garbage
end

function Stack:updateFramesBehind()
  if self.garbage_target and self.garbage_target ~= self then
    if not self.framesBehindArray[self.CLOCK] then
      local framesBehind = math.max(0, self.garbage_target.CLOCK - self.CLOCK)
      self.framesBehindArray[self.CLOCK] = framesBehind
      self.totalFramesBehind = self.totalFramesBehind + framesBehind
    end
  end
end

function Stack.behindRollback(self)
  if self.lastRollbackFrame > self.CLOCK then
    return true
  end

  return false
end

function Stack.shouldChangeMusic(self)
  local result = not GAME.gameIsPaused and not GAME.preventSounds

  if result then
    if self:game_ended() or self.canvas == nil then
      result = false
    end

    -- If we are still catching up from rollback don't play sounds again
    if self:behindRollback() then
      result = false
    end

    if self.play_to_end then
      result = false
    end

    if self.garbage_target and self.garbage_target.play_to_end then
      result = false
    end
  end

  return result
end


function Stack.shouldChangeSoundEffects(self)
  local result = self:shouldChangeMusic() and not GAME.muteSoundEffects

  return result
end

function Stack:averageFramesBehind()
  local average = tonumber(string.format("%1.1f", round(self.totalFramesBehind / math.max(self.CLOCK, 1)), 1))
  return average
end

-- Returns true if the stack is simulated past the end of the match.
function Stack.game_ended(self)

  local gameEndedClockTime = self.match:gameEndedClockTime()

  if self.match.mode == "vs" then
    -- Note we use "greater" and not "greater than or equal" because our stack may be currently processing this clock frame.
    -- At the end of the clock frame it will be incremented and we know we have process the game over clock frame.
    if gameEndedClockTime > 0 and self.CLOCK > gameEndedClockTime then
      return true
    end
  elseif self.match.mode == "time" then
    if gameEndedClockTime > 0 and self.CLOCK > gameEndedClockTime then
      return true
    elseif self.game_stopwatch then
      if self.game_stopwatch > time_attack_time * 60 then
        return true
      end
    end
  elseif self.match.mode == "endless" then
    if gameEndedClockTime > 0 and self.CLOCK > gameEndedClockTime then
      return true
    end
  elseif self.match.mode == "puzzle" then
    if self:puzzle_done() or self:puzzle_failed() then
      return true
    end
  end

  return false
end

-- Returns 1 if this player won, 0 for draw, and -1 for loss, nil if no result yet
function Stack.gameResult(self)
  if self:game_ended() == false then
    return nil
  end

  local gameEndedClockTime = self.match:gameEndedClockTime()

  if self.match.mode == "vs" then
    local otherPlayer = self.garbage_target
    if otherPlayer == self or otherPlayer == nil then
      return -1
    -- We can't call it until someone has lost and everyone has played up to that point in time.
    elseif otherPlayer:game_ended() then
      if self.game_over_clock == gameEndedClockTime and otherPlayer.game_over_clock == gameEndedClockTime then
        return 0
      elseif self.game_over_clock == gameEndedClockTime then
        return -1
      elseif otherPlayer.game_over_clock == gameEndedClockTime then
        return 1
      end
    end
  elseif self.match.mode == "time" then
    if gameEndedClockTime > 0 and self.CLOCK > gameEndedClockTime then
      return -1
    elseif self.game_stopwatch then
      if self.game_stopwatch > time_attack_time * 60 then
        return 1
      end
    end
  elseif self.match.mode == "endless" then
    if gameEndedClockTime > 0 and self.CLOCK > gameEndedClockTime then
      return -1
    end
  elseif self.match.mode == "puzzle" then
    if self:puzzle_done() then
      return 1
    elseif self:puzzle_failed() then
      return -1
    end
  end

  return nil
end

-- Sets the current stack as "lost"
-- Also begins drawing game over effects
function Stack.set_game_over(self)

  if self.game_over_clock ~= 0 then
    error("should not set gameover when it is already set")
  end
  
  self.game_over = true
  self.game_over_clock = self.CLOCK

  if self.canvas then
    local popsize = "small"
    local panels = self.panels
    local width = self.width
    for row = 1, #panels do
      for col = 1, width do
        local panel = panels[row][col]
        panel.state = "dead"
        if row == #panels then
          self:enqueue_popfx(col, row, popsize)
        end
      end
    end
  end
end

-- Randomly returns a win sound if the character has one
function Stack.pick_win_sfx(self)
  if #characters[self.character].sounds.wins ~= 0 then
    return characters[self.character].sounds.wins[math.random(#characters[self.character].sounds.wins)]
  else
    return themes[config.theme].sounds.fanfare1 -- TODO add a default win sound
  end
end

function Stack.canSwap(self, row, column)
  local panels = self.panels
  local width = self.width
  local height = self.height
  -- in order for a swap to occur, one of the two panels in
  -- the cursor must not be a non-panel.
  local do_swap =
    (panels[row][column].color ~= 0 or panels[row][column + 1].color ~= 0) and -- also, both spaces must be swappable.
    (not panels[row][column]:exclude_swap()) and
    (not panels[row][column + 1]:exclude_swap()) and -- also, neither space above us can be hovering.
    (row == #panels or (panels[row + 1][column].state ~= "hovering" and panels[row + 1][column + 1].state ~= "hovering")) and --also, we can't swap if the game countdown isn't finished
    not self.do_countdown and --also, don't swap on the first frame
    not (self.CLOCK and self.CLOCK <= 1)
  -- If you have two pieces stacked vertically, you can't move
  -- both of them to the right or left by swapping with empty space.
  -- TODO: This might be wrong if something lands on a swapping panel?
  if panels[row][column].color == 0 or panels[row][column + 1].color == 0 then
    do_swap = do_swap and not (row ~= self.height and (panels[row + 1][column].state == "swapping" and panels[row + 1][column + 1].state == "swapping") and (panels[row + 1][column].color == 0 or panels[row + 1][column + 1].color == 0) and (panels[row + 1][column].color ~= 0 or panels[row + 1][column + 1].color ~= 0))
    do_swap = do_swap and not (row ~= 1 and (panels[row - 1][column].state == "swapping" and panels[row - 1][column + 1].state == "swapping") and (panels[row - 1][column].color == 0 or panels[row - 1][column + 1].color == 0) and (panels[row - 1][column].color ~= 0 or panels[row - 1][column + 1].color ~= 0))
  end

  do_swap = do_swap and (not self.puzzle or self.puzzle.moves == 0 or self.puzzle.remaining_moves > 0)

  return do_swap
end

-- Swaps panels at the current cursor location
function Stack.swap(self)
  local panels = self.panels
  local row = self.cur_row
  local col = self.cur_col
  self:processPuzzleSwap()
  panels[row][col], panels[row][col + 1] = panels[row][col + 1], panels[row][col]
  local tmp_chaining = panels[row][col].chaining
  panels[row][col]:clear_flags()
  panels[row][col].state = "swapping"
  panels[row][col].chaining = tmp_chaining
  tmp_chaining = panels[row][col + 1].chaining
  panels[row][col + 1]:clear_flags()
  panels[row][col + 1].state = "swapping"
  panels[row][col + 1].is_swapping_from_left = true
  panels[row][col + 1].chaining = tmp_chaining

  panels[row][col].timer = 4
  panels[row][col + 1].timer = 4

  if self:shouldChangeSoundEffects() then
    SFX_Swap_Play = 1
  end

  -- If you're swapping a panel into a position
  -- above an empty space or above a falling piece
  -- then you can't take it back since it will start falling.
  if self.cur_row ~= 1 then
    if (panels[row][col].color ~= 0) and (panels[row - 1][col].color == 0 or panels[row - 1][col].state == "falling") then
      panels[row][col].dont_swap = true
    end
    if (panels[row][col + 1].color ~= 0) and (panels[row - 1][col + 1].color == 0 or panels[row - 1][col + 1].state == "falling") then
      panels[row][col + 1].dont_swap = true
    end
  end

  -- If you're swapping a blank space under a panel,
  -- then you can't swap it back since the panel should
  -- start falling.
  if self.cur_row ~= self.height then
    if panels[row][col].color == 0 and panels[row + 1][col].color ~= 0 then
      panels[row][col].dont_swap = true
    end
    if panels[row][col + 1].color == 0 and panels[row + 1][col + 1].color ~= 0 then
      panels[row][col + 1].dont_swap = true
    end
  end
end

function Stack.processPuzzleSwap(self)
  if self.puzzle then
    if self.puzzle.remaining_moves == self.puzzle.moves and self.puzzle.puzzleType == "clear" then
      -- start depleting stop / shake time
      self.stop_time = self.puzzle.stop_time
      self.shake_time = self.puzzle.shake_time
    end
    self.puzzle.remaining_moves = self.puzzle.remaining_moves - 1
  end
end

-- Removes unneeded rows
function Stack.remove_extra_rows(self)
  local panels = self.panels
  local width = self.width
  for row = #panels, self.height + 1, -1 do
    local nonempty = false
    local prow = panels[row]
    for col = 1, width do
      nonempty = nonempty or (prow[col].color ~= 0)
    end
    if nonempty then
      break
    else
      panels[row] = nil
    end
  end
end

-- drops a width x height garbage.
function Stack.drop_garbage(self, width, height, metal)

  logger.debug("dropping garbage at frame "..self.CLOCK)
  local spawn_row = self.height + 1

  -- Do one last check for panels in the way.
  for i = spawn_row, #self.panels do
    if self.panels[i] then
      for j = 1, self.width do
        if self.panels[i][j] then
          if self.panels[i][j].color ~= 0 then
            logger.trace("Aborting garbage drop: panel found at row " .. tostring(i) .. " column " .. tostring(j))
            return false
          end
        end
      end
    end
  end

  if self.canvas ~= nil then
    logger.trace(string.format("Dropping garbage on player %d - height %d  width %d  %s", self.player_number, height, width, metal and "Metal" or ""))
  end

  for i = self.height + 1, spawn_row + height - 1 do
    if not self.panels[i] then
      self.panels[i] = {}
      for j = 1, self.width do
        self.panels[i][j] = Panel()
      end
    end
  end

  local cols = self.garbage_cols[width]
  local spawn_col = cols[cols.idx]
  cols.idx = wrap(1, cols.idx + 1, #cols)
  local shake_time = garbage_to_shake_time[width * height]
  for y = spawn_row, spawn_row + height - 1 do
    for x = spawn_col, spawn_col + width - 1 do
      local panel = self.panels[y][x]
      panel.garbage = true
      panel.color = 9
      panel.width = width
      panel.height = height
      panel.y_offset = y - spawn_row
      panel.x_offset = x - spawn_col
      panel.shake_time = shake_time
      panel.state = "falling"
      if metal then
        panel.metal = metal
      end
    end
  end

  return true
end

-- Goes through whole stack checking for matches and updating chains etc based on matches.
function Stack.check_matches(self)
  if self.do_countdown then
    return
  end

  local panels = self.panels

  for col = 1, self.width do
    for row = 1, self.height do
      panels[row][col].matching = nil
    end
  end

  -- Record whether each panel excludes matching once to prevent duplicated work.
  local excludeMatchTable = {}
  for row = 1, self.height do
    excludeMatchTable[row] = {}
    for col = 1, self.width do
      excludeMatchTable[row][col] = panels[row][col]:exclude_match()
    end
  end

  local is_chain = false
  local combo_size = 0
  local floodQueue = Queue()
  for row = 1, self.height do
    for col = 1, self.width do
      if
        row ~= 1 and row ~= self.height and --check vertical match centered here.
          (not (excludeMatchTable[row - 1][col] or excludeMatchTable[row][col] or excludeMatchTable[row + 1][col])) and
          panels[row][col].color == panels[row - 1][col].color and
          panels[row][col].color == panels[row + 1][col].color
       then
        for m_row = row - 1, row + 1 do
          local panel = panels[m_row][col]
          if not panel.matching then
            combo_size = combo_size + 1
            panel.matching = true
          end
          if panel.match_anyway and panel.chaining then
            panel.chaining = nil
            self.n_chain_panels = self.n_chain_panels - 1
          end
          is_chain = is_chain or panel.chaining
        end
        floodQueue:push({row, col, true, true})
      end
      if
        col ~= 1 and col ~= self.width and --check horiz match centered here.
          (not (excludeMatchTable[row][col - 1] or excludeMatchTable[row][col] or excludeMatchTable[row][col + 1])) and
          panels[row][col].color == panels[row][col - 1].color and
          panels[row][col].color == panels[row][col + 1].color
       then
        for m_col = col - 1, col + 1 do
          local panel = panels[row][m_col]
          if not panel.matching then
            combo_size = combo_size + 1
            panel.matching = true
          end
          if panel.match_anyway and panel.chaining then
            panel.chaining = nil
            self.n_chain_panels = self.n_chain_panels - 1
          end
          is_chain = is_chain or panel.chaining
        end
        floodQueue:push({row, col, true, true})
      end
    end
  end

  -- This is basically two flood fills at the same time.
  -- One for clearing normal garbage, one for metal.
  local garbage = {}
  local seen, seenm = {}, {}
  local garbage_size = 0
  while floodQueue:len() ~= 0 do
    local y, x, normal, metal = unpack(floodQueue:pop())
    local panel = panels[y][x]

    -- We found a new panel we haven't handled yet that we should
    if ((panel.garbage and panel.state == "normal") or panel.matching) and ((normal and not seen[panel]) or (metal and not seenm[panel])) then
      -- We matched a new garbage
      if ((metal and panel.metal) or (normal and not panel.metal)) and panel.garbage and not garbage[panel] then
        garbage[panel] = true
        if self:shouldChangeSoundEffects() then
          SFX_garbage_match_play = true
        end
        if y <= self.height then
          garbage_size = garbage_size + 1
        end
      end
      seen[panel] = seen[panel] or normal
      seenm[panel] = seenm[panel] or metal
      if panel.garbage then
        normal = normal and not panel.metal
        metal = metal and panel.metal
      end
      if normal or metal then
        if y ~= 1 then
          floodQueue:push({y - 1, x, normal, metal})
        end
        if y ~= #panels then
          floodQueue:push({y + 1, x, normal, metal})
        end
        if x ~= 1 then
          floodQueue:push({y, x - 1, normal, metal})
        end
        if x ~= self.width then
          floodQueue:push({y, x + 1, normal, metal})
        end
      end
    end
  end

  if is_chain then
    if self.chain_counter ~= 0 then
      self.chain_counter = self.chain_counter + 1
    else
      self.chain_counter = 2
    end
  end

  local first_panel_row = 0
  local first_panel_col = 0
  local metal_count = 0
  local pre_stop_time = self.FRAMECOUNT_MATCH + self.FRAMECOUNT_POP * (combo_size + garbage_size)
  local garbage_match_time = self.FRAMECOUNT_MATCH + self.FRAMECOUNT_POP * (combo_size + garbage_size)
  local garbage_index = garbage_size - 1
  local combo_index = combo_size
  for row = 1, #panels do
    local gpan_row = nil
    for col = self.width, 1, -1 do
      local panel = panels[row][col]
      if garbage[panel] then
        panel.state = "matched"
        panel.timer = garbage_match_time + 1
        panel.initial_time = garbage_match_time
        panel.pop_time = self.FRAMECOUNT_POP * garbage_index
        panel.pop_index = min(max(garbage_size - garbage_index, 1), 10)
        panel.y_offset = panel.y_offset - 1
        panel.height = panel.height - 1
        if panel.y_offset == -1 then
          if gpan_row == nil then
            if string.len(self.gpanel_buffer) <= 10 * self.width then
              local garbagePanels = PanelGenerator.makeGarbagePanels(self.match.seed + self.garbageGenCount, self.NCOLORS, self.gpanel_buffer, self.match.mode, self.level)
              self.gpanel_buffer = self.gpanel_buffer .. garbagePanels
              logger.info("Generating garbage with seed: " .. self.match.seed + self.garbageGenCount .. " buffer: " .. self.gpanel_buffer)
              self.garbageGenCount = self.garbageGenCount + 1
            end
            gpan_row = string.sub(self.gpanel_buffer, 1, 6)
            self.gpanel_buffer = string.sub(self.gpanel_buffer, 7)
          end
          panel.color = string.sub(gpan_row, col, col) + 0
          if is_chain then
            panel.chaining = true
            self.n_chain_panels = self.n_chain_panels + 1
          end
        end
        garbage_index = garbage_index - 1
      elseif row <= self.height then
        if panel.matching then
          if panel.color == 8 then
            metal_count = metal_count + 1
          end
          panel.state = "matched"
          panel.timer = self.FRAMECOUNT_MATCH + 1
          if is_chain and not panel.chaining then
            panel.chaining = true
            self.n_chain_panels = self.n_chain_panels + 1
          end
          panel.combo_index = combo_index
          panel.combo_size = combo_size
          panel.chain_index = self.chain_counter
          combo_index = combo_index - 1
          if combo_index == 0 then
            first_panel_col = col
            first_panel_row = row
          end
        else
          -- if a panel wasn't matched but was eligible,
          -- we might have to remove its chain flag...!
          -- It can't actually chain the first frame it hovers,
          -- so it can keep its chaining flag in that case.
          if not (panel.match_anyway or panel:exclude_match()) then
            if row ~= 1 then
              -- a panel landed on the bottom row, so it surely
              -- loses its chain flag.
              -- no swapping panel below
              -- so this panel loses its chain flag
              if panels[row - 1][col].state ~= "swapping" and panel.chaining then
                --if panel.chaining then
                panel.chaining = nil
                self.n_chain_panels = self.n_chain_panels - 1
              end
            elseif (panel.chaining) then
              panel.chaining = nil
              self.n_chain_panels = self.n_chain_panels - 1
            end
          end
        end
      end
    end
  end

  if (combo_size ~= 0) then
    if self.garbage_target and self.telegraph then
      if metal_count >= 3 then
        -- Give a shock garbage for every shock block after 2
        for i = 3, metal_count do
          self.telegraph:push({6, 1, true, false}, first_panel_col, first_panel_row, self.CLOCK)
          self:recordComboHistory(self.CLOCK, 6, 1, true)
        end
      end
    end
    self.analytic:register_destroyed_panels(combo_size)
    if (combo_size > 3) then
      if (score_mode == SCOREMODE_TA) then
        if (combo_size > 30) then
          combo_size = 30
        end
        self.score = self.score + score_combo_TA[combo_size]
      elseif (score_mode == SCOREMODE_PDP64) then
        if (combo_size < 41) then
          self.score = self.score + score_combo_PdP64[combo_size]
        else
          self.score = self.score + 20400 + ((combo_size - 40) * 800)
        end
      end

      self:enqueue_card(false, first_panel_col, first_panel_row, combo_size)
      if self.garbage_target and self.telegraph then
        local combo_pieces = combo_garbage[combo_size]
        for i=1,#combo_pieces do
          -- Give out combo garbage based on the lookup table, even if we already made shock garbage,
          -- OP! Too bad its hard to get shock panels in vs. :)
          self.telegraph:push({combo_pieces[i], 1, false, false}, first_panel_col, first_panel_row, self.CLOCK)
          self:recordComboHistory(self.CLOCK, combo_pieces[i], 1, false)
        end
      end
      --EnqueueConfetti(first_panel_col<<4+P1StackPosX+4,
      --          first_panel_row<<4+P1StackPosY+self.displacement-9);
      --TODO: this stuff ^
      first_panel_row = first_panel_row + 1 -- offset chain cards
    end
    if (is_chain) then
      if self.chain_counter == 2 then
        self.chains.current = self.CLOCK
        self.chains[self.chains.current] = {starts = {}}
      end
      local currentChainData = self.chains[self.chains.current]
      currentChainData.size = self.chain_counter
      currentChainData.starts[#currentChainData.starts+1] = self.CLOCK
      self:enqueue_card(true, first_panel_col, first_panel_row, self.chain_counter)
    --EnqueueConfetti(first_panel_col<<4+P1StackPosX+4,
    --          first_panel_row<<4+P1StackPosY+self.displacement-9);
      if self.garbage_target and self.telegraph then
        self.telegraph:push({6, self.chain_counter - 1, false, true}, first_panel_col, first_panel_row, self.CLOCK)
      end
    end
    local chain_bonus = self.chain_counter
    if (score_mode == SCOREMODE_TA) then
      if (self.chain_counter > 13) then
        chain_bonus = 0
      end
      self.score = self.score + score_chain_TA[chain_bonus]
    end
    if ((combo_size > 3) or is_chain) then
      local stop_time
      if self.panels_in_top_row and is_chain then
        if self.level then
          local length = (self.chain_counter > 4) and 6 or self.chain_counter
          stop_time = -8 * self.level + 168 + (length - 1) * (-2 * self.level + 22)
        else
          stop_time = stop_time_danger[self.difficulty]
        end
      elseif self.panels_in_top_row then
        if self.level then
          local length = (combo_size < 9) and 2 or 3
          stop_time = self.chain_coefficient * length + self.chain_constant
        else
          stop_time = stop_time_danger[self.difficulty]
        end
      elseif is_chain then
        if self.level then
          local length = min(self.chain_counter, 13)
          stop_time = self.chain_coefficient * length + self.chain_constant
        else
          stop_time = stop_time_chain[self.difficulty]
        end
      else
        if self.level then
          stop_time = self.combo_coefficient * combo_size + self.combo_constant
        else
          stop_time = stop_time_combo[self.difficulty]
        end
      end
      self.stop_time = max(self.stop_time, stop_time)
      self.pre_stop_time = max(self.pre_stop_time, pre_stop_time)
      --MrStopState=1;
      --MrStopTimer=MrStopAni[self.stop_time];
      --TODO: Mr Stop ^
      -- @CardsOfTheHeart says there are 4 chain sfx: --x2/x3, --x4, --x5 is x2/x3 with an echo effect, --x6+ is x4 with an echo effect
      if self:shouldChangeSoundEffects() then
        if is_chain then
          self.combo_chain_play = {e_chain_or_combo.chain, self.chain_counter}
        elseif combo_size > 3 then
          self.combo_chain_play = {e_chain_or_combo.combo, "combos"}
        end
      end
      self.sfx_land = false
    end
    --if garbage_size > 0 then
    self.pre_stop_time = max(self.pre_stop_time, pre_stop_time)
    --end

    self.manual_raise = false
    --self.score_render=1;
    --Nope.
    if metal_count > 5 then
      self.combo_chain_play = {e_chain_or_combo.combo, "combo_echos"}
    elseif metal_count > 2 then
      self.combo_chain_play = {e_chain_or_combo.combo, "combos"}
    end
  end
end

-- Sets the hovering state on the appropriate panels
function Stack.set_hoverers(self, row, col, hover_time, add_chaining, extra_tick, match_anyway, debug_tag)
  assert(type(match_anyway) ~= "string")
  -- the extra_tick flag is for use during Phase 1&2,
  -- when panels above the first should be given an extra tick of hover time.
  -- This is because their timers will be decremented once on the same tick
  -- they are set, as Phase 1&2 iterates backward through the stack.
  local not_first = 0 -- if 1, the current panel isn't the first one
  local hovers_time = hover_time
  local brk = row > #self.panels
  local panels = self.panels
  while not brk do
    local panel = panels[row][col]
    if panel.color == 0 or panel:exclude_hover() or panel.state == "hovering" and panel.timer <= hover_time then
      brk = true
    else
      if panel.state == "swapping" then
        hovers_time = hovers_time + panels[row][col].timer - 1
      else
        local chaining = panel.chaining
        panel:clear_flags()
        panel.state = "hovering"
        panel.match_anyway = match_anyway
        panel.debug_tag = debug_tag
        local adding_chaining = (not chaining) and panel.color ~= 9 and add_chaining
        if chaining or adding_chaining then
          panel.chaining = true
        end
        panel.timer = hovers_time
        if extra_tick then
          panel.timer = panel.timer + not_first
        end
        if adding_chaining then
          self.n_chain_panels = self.n_chain_panels + 1
        end
      end
      not_first = 1
    end
    row = row + 1
    brk = brk or row > #self.panels
  end
end

function Stack:recordComboHistory(time, width, height, metal)

  if self.combos[time] == nil then 
    self.combos[time] = {} 
  end
  
  self.combos[time][#self.combos[time]+1] = {width = width, height = height, metal = metal}
end

-- Adds a new row to the play field
function Stack.new_row(self)
  local panels = self.panels
  -- move cursor up
  self.cur_row = bound(1, self.cur_row + 1, self.top_cur_row)
  -- move panels up
  for row = #panels + 1, 1, -1 do
    panels[row] = panels[row - 1]
  end
  panels[0] = {}
  -- put bottom row into play
  for col = 1, self.width do
    panels[1][col].state = "normal"
  end

  if string.len(self.panel_buffer) <= 10 * self.width then
    local opponentLevel = nil
    if self.garbage_target then
      opponentLevel = self.garbage_target.level
    end
    self.panel_buffer = PanelGenerator.makePanels(self.match.seed + self.panelGenCount, self.NCOLORS, self.panel_buffer, self.match.mode, self.level, opponentLevel)
    logger.info("generating panels with seed: " .. self.match.seed + self.panelGenCount .. " buffer: " .. self.panel_buffer)
    self.panelGenCount = self.panelGenCount + 1
  end

  -- generate a new row
  local metal_panels_this_row = 0
  if self.metal_panels_queued > 3 then
    self.metal_panels_queued = self.metal_panels_queued - 2
    metal_panels_this_row = 2
  elseif self.metal_panels_queued > 0 then
    self.metal_panels_queued = self.metal_panels_queued - 1
    metal_panels_this_row = 1
  end
  for col = 1, self.width do
    local panel = Panel()
    panels[0][col] = panel
    local this_panel_color = string.sub(self.panel_buffer, col, col)
    --a capital letter for the place where the first shock block should spawn (if earned), and a lower case letter is where a second should spawn (if earned).  (color 8 is metal)
    if tonumber(this_panel_color) then
      --do nothing special
    elseif this_panel_color >= "A" and this_panel_color <= "Z" then
      if metal_panels_this_row > 0 then
        this_panel_color = 8
      else
        this_panel_color = panel_color_to_number[this_panel_color]
      end
    elseif this_panel_color >= "a" and this_panel_color <= "z" then
      if metal_panels_this_row > 1 then
        this_panel_color = 8
      else
        this_panel_color = panel_color_to_number[this_panel_color]
      end
    end
    panel.color = this_panel_color + 0
    panel.state = "dimmed"
  end
  self.panel_buffer = string.sub(self.panel_buffer, 7)
  self.displacement = 16
end

function Stack:getAttackPatternData() 

  local data = {}
  data.name = "Player " .. self.which
  data.mergeComboMetalQueue = false
  data.delayBeforeStart = 0
  data.delayBeforeRepeat = 91
  self.chains.current = nil
  local defaultEndTime = 70
  local sortedAttackPatterns = {}

  -- Add in all the chains by time
  for time, currentChain in pairsSortedByKeys(self.chains) do
    local endTime = currentChain.finish or currentChain.starts[#currentChain.starts] + defaultEndTime
    sortedAttackPatterns[time] = {chain = currentChain.starts, chainEndTime = endTime}
  end

  -- Add in all the combos by time
  for time, combos in pairsSortedByKeys(self.combos) do
    for index, garbage in ipairs(combos) do
      sortedAttackPatterns[time] = {width = garbage.width, height = garbage.height, startTime = time, chain = false, metal = garbage.metal}
    end
  end

  -- Save the final attack patterns in sorted order without the times since the file format doesn't want that (duplicate data)
  data.attackPatterns = {}
  for _, attackPattern in pairsSortedByKeys(sortedAttackPatterns) do
    data.attackPatterns[#data.attackPatterns+1] = attackPattern
  end

  return data
end
