-- TODO: move render focused components to client
local analytics = require("client.src.analytics")
local GraphicsUtil = require("client.src.graphics.graphics_util")

require("common.lib.stringExtensions")
local TouchDataEncoding = require("common.engine.TouchDataEncoding")
local TouchInputController = require("common.engine.TouchInputController")
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local util = require("common.lib.util")
local utf8 = require("common.lib.utf8Additions")
local GameModes = require("common.engine.GameModes")
local PanelGenerator = require("common.engine.PanelGenerator")
local StackBase = require("common.engine.StackBase")
local class = require("common.lib.class")
local Panel = require("common.engine.Panel")
local GarbageQueue = require("common.engine.GarbageQueue")
local prof = require("common.lib.jprof.jprof")

-- Stuff defined in this file:
--  . the data structures that store the configuration of
--    the stack of panels
--  . the main game routine
--    (rising, timers, falling, cursor movement, swapping, landing)
--  . the matches-checking routine
local min, pairs, deepcpy = math.min, pairs, deepcpy
local max = math.max

local GARBAGE_SIZE_TO_SHAKE_FRAMES = {
  18, 18, 18, 18, 24, 42,
  42, 42, 42, 42, 42, 66,
  66, 66, 66, 66, 66, 66,
  66, 66, 66, 66, 66, 76
}

local DT_SPEED_INCREASE = 15 * 60 -- frames it takes to increase the speed level by 1

-- endless and 1P time attack use a speed system in which
-- speed increases based on the number of panels you clear.
-- For example, to get from speed 1 to speed 2, you must
-- clear 9 panels.
local PANELS_TO_NEXT_SPEED =
  {9, 12, 12, 12, 12, 12, 15, 15, 18, 18,
  24, 24, 24, 24, 24, 24, 21, 18, 18, 18,
  36, 36, 36, 36, 36, 36, 36, 36, 36, 36,
  39, 39, 39, 39, 39, 39, 39, 39, 39, 39,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, math.huge}

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
    assert(arguments.levelData ~= nil)
    local levelData = arguments.levelData
    -- level and difficulty only for icon display and score saving, all actual data is in levelData
    local level = arguments.level
    local difficulty = arguments.difficulty

    s.gameOverConditions = arguments.gameOverConditions or {GameModes.GameOverConditions.NEGATIVE_HEALTH}
    s.gameWinConditions = arguments.gameWinConditions or {}

    local inputMethod = arguments.inputMethod or "controller" --"touch" or "controller"
    local player_number = arguments.player_number or which
  
    local character = arguments.character or config.character
    local theme = arguments.theme or themes[config.theme]
    s.allowAdjacentColors = arguments.allowAdjacentColors

    -- the behaviour table contains a bunch of flags to modify the stack behaviour for custom game modes in broader chunks of functionality
    s.behaviours = {}
    s.behaviours.passiveRaise = true
    s.behaviours.allowManualRaise = true

    s.match = match
    s.character = character
    s.theme = theme
    s.panels_dir = panels_dir
    s.is_local = is_local

    s.drawsAnalytics = true

    if not panels[panels_dir] then
      s.panels_dir = config.panels
    end

    if s.puzzle then
      s.drawsAnalytics = false
    else
      s.do_first_row = true
    end

    s.difficulty = difficulty
    s.level = level
    s.levelData = levelData
    s.speed = s.levelData.startingSpeed
    if s.levelData.speedIncreaseMode == 1 then
      -- mode 1: increase speed based on fixed intervals
      s.nextSpeedIncreaseClock = DT_SPEED_INCREASE
    else
      s.panels_to_speedup = PANELS_TO_NEXT_SPEED[s.speed]
    end

    s.health = s.levelData.maxHealth

    -- Which columns each size garbage is allowed to fall in.
    -- This is typically constant but maybe some day we would allow different ones 
    -- for different game modes or need to change it based on board width.
    s.garbageSizeDropColumnMaps = {
      {1, 2, 3, 4, 5, 6},
      {1, 3, 5,},
      {1, 4},
      {1, 2, 3},
      {1, 2},
      {1}
    }
    -- The current index of the above table we are currently using for the drop column.
    -- This increases by 1 wrapping every time garbage drops.
    s.currentGarbageDropColumnIndexes = {1, 1, 1, 1, 1, 1}

    -- the stack pushes the garbage it produces into this queue
    s.outgoingGarbage = GarbageQueue()
    -- after completing the inTransit delay garbage sits in this queue ready to be popped as soon as the stack allows it
    s.incomingGarbage = GarbageQueue()
    
    s.inputMethod = inputMethod
    if s.inputMethod == "touch" then
      s.touchInputController = TouchInputController(s)
    end

    s.panel_buffer = ""
    s.gpanel_buffer = ""
    s.input_buffer = {} -- Inputs that haven't been processed yet
    s.confirmedInput = {} -- All inputs the player has input ever
    -- The number of individual garbage blocks created on this stack
    -- used for giving a unique identifier to each new garbage block
    s.garbageCreatedCount = 0
    s.garbageLandedThisFrame = {}
    -- The number of individual panels created on this stack
    -- used for giving new panels their own unique identifier
    s.panelsCreatedCount = 0
    -- 2 dimensional table for containing all panels
    -- panel[i] gets the row where i is the index of the row with 1 being the most bottom row that is in play (not dimmed)
    -- panel[i][j] gets the panel at row i where j is the column index counting from left to right starting from 1
    -- the update order for panels is bottom to top and left to right as well
    s.panels = {}
    s.width = 6
    s.height = 12
    for i = 0, s.height do
      s.panels[i] = {}
      for j = 1, s.width do
        s:createPanelAt(i, j)
      end
    end
    s:moveForRenderIndex(s.which)

    s.game_stopwatch_running = true -- set to false if countdown starts
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

    s.rise_timer = 1 -- When this value reaches 0, the stack will rise a pixel
    s.rise_lock = false -- If the stack is rise locked, it won't rise until it is
    -- unlocked.
    s.has_risen = false -- set once the stack rises once during the game

    s.stop_time = 0
    s.pre_stop_time = 0

    s.score = 0 -- der skore
    s.chain_counter = 0 -- how high is the current chain (starts at 2)

    s.panels_in_top_row = false -- boolean, for losing the game
    s.danger = s.danger or false -- boolean, panels in the top row (danger)
    s.danger_music = s.danger_music or false -- changes music state

    s.n_active_panels = 0
    s.n_prev_active_panels = 0

    s.rise_timer = consts.SPEED_TO_RISE_TIME[s.speed]

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

    -- number of ticks a movement key has to be held before the cursor begins to move at 1 movement per frame
    s.cur_wait_time = consts.DEFAULT_INPUT_REPEAT_DELAY
    s.cur_timer = 0 -- number of ticks for which a new direction's been pressed
    s.cur_dir = nil -- the direction pressed
    s.cur_row = 7 -- the row the cursor's on
    s.cur_col = 3 -- the column the left half of the cursor's on
    s.queuedSwapColumn = 0 -- the left column of the two columns to swap or 0 if no swap queued
    s.queuedSwapRow = 0 -- the row of the queued swap or 0 if no swap queued
    s.top_cur_row = s.height + (s.puzzle and 0 or -1)

    s.poppedPanelIndex = s.poppedPanelIndex or 1
    s.panels_cleared = s.panels_cleared or 0
    s.metal_panels_queued = s.metal_panels_queued or 0
    s.lastPopLevelPlayed = s.lastPopLevelPlayed or 1
    s.lastPopIndexPlayed = s.lastPopIndexPlayed or 1
    s.combo_chain_play = nil
    s.sfx_land = false
    s.sfx_garbage_thud = 0

    s.card_q = Queue()

    s.pop_q = Queue()

    s.which = which
    s.player_number = player_number --player number according to the multiplayer server, for game outcome reporting

    s.prev_shake_time = 0
    s.shake_time = 0
    s.shake_time_on_frame = 0
    s.peak_shake_time = 0

    s.analytic = AnalyticsInstance(s.is_local)
    -- the target you are sending attacks to
    -- implicitly also the stack that sends attacks to you
    -- TODO: remove this coupling
    s.garbageTarget = nil

    s.panelGenCount = 0
    s.garbageGenCount = 0

    s.warningsTriggered = {}

    s.multi_prestopQuad = GraphicsUtil:newRecycledQuad(0, 0, s.theme.images.IMG_multibar_prestop_bar:getWidth(), s.theme.images.IMG_multibar_prestop_bar:getHeight(), s.theme.images.IMG_multibar_prestop_bar:getWidth(), s.theme.images.IMG_multibar_prestop_bar:getHeight())
    s.multi_stopQuad = GraphicsUtil:newRecycledQuad(0, 0, s.theme.images.IMG_multibar_stop_bar:getWidth(), s.theme.images.IMG_multibar_stop_bar:getHeight(), s.theme.images.IMG_multibar_stop_bar:getWidth(), s.theme.images.IMG_multibar_stop_bar:getHeight())
    s.multi_shakeQuad = GraphicsUtil:newRecycledQuad(0, 0, s.theme.images.IMG_multibar_shake_bar:getWidth(), s.theme.images.IMG_multibar_shake_bar:getHeight(), s.theme.images.IMG_multibar_shake_bar:getWidth(), s.theme.images.IMG_multibar_shake_bar:getHeight())
    s.multiBarFrameCount = s:calculateMultibarFrameCount()
  end,
  StackBase
)

-- calculates at how many frames the stack's multibar tops out
function Stack:calculateMultibarFrameCount()
  -- the multibar needs a realistic height that can encompass the sum of health and a realistic maximum stop time
  local maxStop = 0

  -- for a realistic max stop, let's only compare obtainable stop while topped out - while not topped out, stop doesn't matter after all
  -- x5 chain while topped out (bonus stop from extra chain links is capped at x5)
  maxStop = math.max(maxStop, self:calculateStopTime(3, true, true, 5))

  -- while topped out, stop from combos is capped at 10 combo
  maxStop = math.max(maxStop, self:calculateStopTime(10, true, false))

  -- if we wanted to include stop in non-topped out states:
  -- combo stop is linear with combosize but +27 is a reasonable cutoff (garbage cap for combos)
  -- maxStop = math.max(maxStop, self:calculateStopTime(27, false, false))
  -- ...but this would produce insanely high values on low levels

  -- bonus stop from extra chain links caps out at x13
  -- maxStop = math.max(maxStop, self:calculateStopTime(3, false, true, 13))
  -- this too produces insanely high values on low levels

  -- prestop does not need to be represented fully as there is visual representation via popping panels
  -- we want a fair but not overly large buffer relative to human time perception to represent prestop in maxstop scenarios
  -- this is a first idea going from 2s prestop on 10 to nearly 4s prestop on 1
  --local preStopFrameCount = 30 + (10 - self.level) * 5

  local minFrameCount = maxStop + self.levelData.maxHealth --+ preStopFrameCount

  --return minFrameCount + preStopFrameCount
  return math.max(240, minFrameCount)
end

-- Should be called prior to clearing the stack.
-- Consider recycling any memory that might leave around a lot of garbage.
-- Note: You can just leave the variables to clear / garbage collect on their own if they aren't large.
function Stack:deinit()
  GraphicsUtil:releaseQuad(self.healthQuad)
  GraphicsUtil:releaseQuad(self.multi_prestopQuad)
  GraphicsUtil:releaseQuad(self.multi_stopQuad)
  GraphicsUtil:releaseQuad(self.multi_shakeQuad)
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

  result = result .. "Stop " .. stackToTest.stop_time .. "\n"
  result = result .. "Pre Stop " .. stackToTest.pre_stop_time .. "\n"
  result = result .. "Shake " .. stackToTest.shake_time .. "\n"
  result = result .. "Displacement " .. stackToTest.displacement .. "\n"
  result = result .. "Clock " .. stackToTest.clock .. "\n"
  result = result .. "Panel Buffer " .. stackToTest.panel_buffer .. "\n"

  return result
end

-- Backup important variables into the passed in variable to be restored in rollback. Note this doesn't do a full copy.
-- param source the stack to copy from
-- param other the variable to copy to (this may be a full stack object in the case of restore, or just a table in case of backup)
function Stack.rollbackCopy(source, other)
  local restoringStack = getmetatable(other) ~= nil

  if other == nil then
    if #source.rollbackCopyPool == 0 then
      other = {}
    else
      other = source.rollbackCopyPool[#source.rollbackCopyPool]
      source.rollbackCopyPool[#source.rollbackCopyPool] = nil
    end
  end
  other.queuedSwapColumn = source.queuedSwapColumn
  other.queuedSwapRow = source.queuedSwapRow
  other.speed = source.speed
  other.health = source.health

  if other.currentGarbageDropColumnIndexes == nil then
    other.currentGarbageDropColumnIndexes = {}
  end
  for garbageWidth = 1, #source.currentGarbageDropColumnIndexes do
    other.currentGarbageDropColumnIndexes[garbageWidth] = source.currentGarbageDropColumnIndexes[garbageWidth]
  end

  prof.push("rollback copy panels")
  local width = source.width or other.width
  local height_to_cpy = #source.panels
  other.panels = other.panels or {}
  local startRow = 1
  if source.panels[0] then
    startRow = 0
  end
  other.panelsCreatedCount = source.panelsCreatedCount
  for i = startRow, height_to_cpy do
    if other.panels[i] == nil then
      other.panels[i] = {}
      for j = 1, width do
        if restoringStack then
          other:createPanelAt(i, j) -- the panel ID will be overwritten below
        else
          -- We don't need to "create" a panel, since we are just backing up the key values
          -- and when we restore we will usually have a panel to restore into.
          other.panels[i][j] = {}
        end
      end
    end
    for j = 1, width do
      local opanel = other.panels[i][j]
      local spanel = source.panels[i][j]
      -- Clear all variables not in source, then copy all source variables to the backup
      -- Note the functions are kept from the same stack so they will still be valid
      for k, _ in pairs(opanel) do
        if spanel[k] == nil then
          opanel[k] = nil
        end
      end
      for k, v in pairs(spanel) do
        opanel[k] = v
      end
    end
  end
  -- this is too eliminate offscreen rows of chain garbage higher up that the clone might have had
  for i = height_to_cpy + 1, #other.panels do
    other.panels[i] = nil
  end
  prof.pop("rollback copy panels")

  prof.push("rollback copy the rest")
  other.countdown_timer = source.countdown_timer
  other.clock = source.clock
  other.game_stopwatch = source.game_stopwatch
  other.game_stopwatch_running = source.game_stopwatch_running
  other.prev_rise_lock = source.prev_rise_lock
  other.rise_lock = source.rise_lock
  other.top_cur_row = source.top_cur_row
  other.displacement = source.displacement
  other.nextSpeedIncreaseClock = source.nextSpeedIncreaseClock
  other.panels_to_speedup = source.panels_to_speedup
  other.stop_time = source.stop_time
  other.pre_stop_time = source.pre_stop_time
  other.score = source.score
  other.chain_counter = source.chain_counter
  other.n_active_panels = source.n_active_panels
  other.n_prev_active_panels = source.n_prev_active_panels
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
  other.panel_buffer = source.panel_buffer
  other.gpanel_buffer = source.gpanel_buffer
  other.panelGenCount = source.panelGenCount
  other.garbageGenCount = source.garbageGenCount
  other.panels_in_top_row = source.panels_in_top_row
  other.has_risen = source.has_risen
  other.metal_panels_queued = source.metal_panels_queued
  other.panels_cleared = source.panels_cleared
  other.danger_timer = source.danger_timer
  other.game_over_clock = source.game_over_clock
  prof.pop("rollback copy the rest")
  prof.push("rollback copy analytics")
  other.analytic = deepcpy(source.analytic)
  prof.pop("rollback copy analytics")

  return other
end

local function internalRollbackToFrame(stack, frame)
  local currentFrame = stack.clock
  if frame < currentFrame and stack.rollbackCopies[frame] then
    logger.debug("Rolling back " .. stack.which .. " to " .. frame)
    Stack.rollbackCopy(stack.rollbackCopies[frame], stack)
    -- The remaining inputs is the confirmed inputs not processed yet for this clock time
    -- We have processed clock time number of inputs when we are at clock, so we only want to process the clock+1 input on
    stack.input_buffer = {}
    for i = stack.clock + 1, #stack.confirmedInput do
      stack.input_buffer[#stack.input_buffer+1] = stack.confirmedInput[i]
    end
    -- this is for the interpolation of the shake animation only (not a physics relevant field)
    if stack.rollbackCopies[frame - 1] then
      stack.prev_shake_time = stack.rollbackCopies[frame - 1].shake_time
    else
      -- if this is the oldest rollback frame we don't need to interpolate with previous values
      -- because there are no previous values, pretend it just went down smoothly
      -- this can lead to minor differences in display for the same frame when using rewind
      stack.prev_shake_time = stack.shake_time + 1
    end

    for f = frame, currentFrame do
      stack:deleteRollbackCopy(f)
    end

    return true
  end

  return false
end

function Stack.rollbackToFrame(self, frame)
  local currentFrame = self.clock

  if internalRollbackToFrame(self, frame) then
    if self.incomingGarbage then
      self.incomingGarbage:rollbackToFrame(frame)
    end

    if self.outgoingGarbage then
      self.outgoingGarbage:rollbackToFrame(frame)
    end

    self.rollbackCount = self.rollbackCount + 1
    -- match will try to fast forward this stack to that frame
    self.lastRollbackFrame = currentFrame
    return true
  end

  return false
end

function Stack:rewindToFrame(frame)
  if internalRollbackToFrame(self, frame) then
    if self.incomingGarbage then
      self.incomingGarbage:rewindToFrame(frame)
    end

    if self.outgoingGarbage then
      self.outgoingGarbage:rewindToFrame(frame)
    end

    return true
  end

  return false
end

-- Saves state in backups in case its needed for rollback
-- NOTE: the clock time is the save state for simulating right BEFORE that clock time is simulated
function Stack.saveForRollback(self)
  prof.push("Stack:saveForRollback")
  self:remove_extra_rows()
  prof.push("Stack.rollbackCopy")
  self.rollbackCopies[self.clock] = Stack.rollbackCopy(self)
  prof.pop("Stack.rollbackCopy")
  prof.push("incomingGarbage:rollbackCopy")
  self.incomingGarbage:rollbackCopy(self.clock)
  prof.pop("incomingGarbage:rollbackCopy")
  prof.push("outgoingGarbage:rollbackCopy")
  if self.outgoingGarbage then
    self.outgoingGarbage:rollbackCopy(self.clock)
  end
  prof.pop("outgoingGarbage:rollbackCopy")

  prof.push("delete rollback copy")
  local deleteFrame = self.clock - MAX_LAG - 1
  self:deleteRollbackCopy(deleteFrame)
  prof.pop("delete rollback copy")
  prof.pop("Stack:saveForRollback")
end

function Stack.deleteRollbackCopy(self, frame)
  if self.rollbackCopies[frame] then
    self.rollbackCopyPool[#self.rollbackCopyPool + 1] = self.rollbackCopies[frame]
    self.rollbackCopies[frame] = nil
  end
end

-- Target must be able to take calls of
-- receiveGarbage(frameToReceive, garbageList)
-- and provide
-- frameOriginX
-- frameOriginY
-- mirror_x
-- stackCanvasWidth
function Stack.setGarbageTarget(self, newGarbageTarget)
  if newGarbageTarget ~= nil then
    -- the abstract notion of a garbage target
    -- in reality the target will be a stack of course but this is the interface so to speak
    assert(newGarbageTarget.frameOriginX ~= nil)
    assert(newGarbageTarget.frameOriginY ~= nil)
    assert(newGarbageTarget.mirror_x ~= nil)
    assert(newGarbageTarget.stackCanvasWidth ~= nil)
    assert(newGarbageTarget.incomingGarbage ~= nil)
  end
  self.garbageTarget = newGarbageTarget
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

function Stack.set_puzzle_state(self, puzzle)
  puzzle.stack = puzzle:fillMissingPanelsInPuzzleString(self.width, self.height)

  self.puzzle = puzzle
  self:setPanelsForPuzzleString(puzzle.stack)
  self.do_countdown = puzzle.doCountdown or false
  self.puzzle.remaining_moves = puzzle.moves
  self.behaviours.allowManualRaise = false
  self.behaviours.passiveRaise = false

  if puzzle.moves > 0 then
    tableUtils.appendIfNotExists(self.gameOverConditions, GameModes.GameOverConditions.NO_MOVES_LEFT)
  end

  if puzzle.puzzleType == "clear" then
    tableUtils.appendIfNotExists(self.gameOverConditions, GameModes.GameOverConditions.NEGATIVE_HEALTH)
    tableUtils.appendIfNotExists(self.gameWinConditions, GameModes.GameWinConditions.NO_MATCHABLE_GARBAGE)
    -- also fill up the garbage queue so that the stack stays topped out even when downstacking
    local comboStorm = {}
    for i = 1, self.height do
                            --  width        height, metal, from chain
      table.insert(comboStorm, {width = self.width - 1,  height = 1, isChain = false, isMetal = false, frameEarned = 0})
    end
    self.incomingGarbage:pushTable(comboStorm)
  elseif puzzle.puzzleType == "chain" then
    tableUtils.appendIfNotExists(self.gameOverConditions, GameModes.GameOverConditions.CHAIN_DROPPED)
    tableUtils.appendIfNotExists(self.gameWinConditions, GameModes.GameWinConditions.NO_MATCHABLE_PANELS)
  elseif puzzle.puzzleType == "moves" then
    tableUtils.appendIfNotExists(self.gameWinConditions, GameModes.GameWinConditions.NO_MATCHABLE_PANELS)
  end

  -- transform any cleared garbage into colorless garbage panels
  self.gpanel_buffer = "9999999999999999999999999999999999999999999999999999999999999999999999999"
  self.panel_buffer = "9999999999999999999999999999999999999999999999999999999999999999999999999"
end

function Stack.setPanelsForPuzzleString(self, puzzleString)
  local panels = self.panels
  local garbageId = 0
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
            local panel = self:createPanelAt(row, column)
            panel.color = tonumber(color)
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
            local panel = self:createPanelAt(row, column)
            panel.garbageId = garbageId
            garbageId = garbageId + 1
            panel.isGarbage = true
            panel.color = 9
            panel.y_offset = row - garbageStartRow
            -- iterating the row right to left to make sure we catch the start of each garbage block
            -- but the offset is expected left to right, therefore we can't know the x_offset before reaching the end of the garbage
            -- instead save the column index in that field to calculate it later
            panel.x_offset = column
            panel.metal = isMetal
            table.insert(connectedGarbagePanels, panel)
            -- garbage ends here
            if color == "[" or color == "{" then
              -- calculate dimensions of the garbage and add it to the relevant width/height properties
              local height = connectedGarbagePanels[#connectedGarbagePanels].y_offset + 1
              -- this is disregarding the possible existence of irregularly shaped garbage
              local width = garbageStartColumn - column + 1
              local shake_time = self:shakeFramesForGarbageSize(width, height)
              for i = 1, #connectedGarbagePanels do
                connectedGarbagePanels[i].x_offset = connectedGarbagePanels[i].x_offset - column
                connectedGarbagePanels[i].height = height
                connectedGarbagePanels[i].width = width
                connectedGarbagePanels[i].shake_time = shake_time
                connectedGarbagePanels[i].garbageId = garbageId
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
    local panel = self:createPanelAt(0, column)
    panel.color = 9
    panel.state = "dimmed"
  end

  -- We need to mark all panels as state changed in case they need to match for clear puzzles / active puzzles.
  for row = 1, self.height do
    for col = 1, self.width do
      panels[row][col].stateChanged = true
      panels[row][col].shake_time = nil
    end
  end
end

function Stack.toPuzzleInfo(self)
  local puzzleInfo = {}
  puzzleInfo["Stop"] = self.stop_time
  puzzleInfo["Shake"] = self.shake_time
  puzzleInfo["Pre-Stop"] = self.pre_stop_time
  puzzleInfo["Stack"] = Puzzle.toPuzzleString(self.panels)

  return puzzleInfo
end

function Stack.hasGarbage(self)
  -- garbage is more likely to be found at the top of the stack
  for row = #self.panels, 1, -1 do
    for column = 1, #self.panels[row] do
      if self.panels[row][column].isGarbage
        and self.panels[row][column].state ~= "matched" then
        return true
      end
    end
  end

  return false
end

function Stack.hasActivePanels(self)
  return self.n_active_panels > 0 or self.n_prev_active_panels > 0
end

function Stack.has_falling_garbage(self)
  for i = 1, self.height + 3 do --we shouldn't have to check quite 3 rows above height, but just to make sure...
    local panelRow = self.panels[i]
    for j = 1, self.width do
      if panelRow and panelRow[j].isGarbage and panelRow[j].state == "falling" then
        return true
      end
    end
  end
  return false
end

function Stack:swapQueued()
  if self.queuedSwapColumn ~= 0 and self.queuedSwapRow ~= 0 then
    return true
  end
  return false
end

function Stack:setQueuedSwapPosition(column, row)
  self.queuedSwapColumn = column
  self.queuedSwapRow = row
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
  local raise
  if self.inputMethod == "touch" then
    local cursorColumn, cursorRow
    raise, cursorRow, cursorColumn = TouchDataEncoding.latinStringToTouchData(sdata, self.width)
    local canSetCursor = true
    if self.do_countdown then      
      if self.animatingCursorDuringCountdown then
        canSetCursor = false
      end
    end

    if canSetCursor then
      if self.cur_col ~= cursorColumn or self.cur_row ~= cursorRow or (cursorColumn == 0 and cursorRow == 0) then
        -- We moved the cursor from a previous column, try to swap
        if self.cur_col ~= 0 and self.cur_row ~= 0 and cursorColumn ~= self.cur_col and cursorRow ~= 0 then
          local swapColumn = math.min(self.cur_col, cursorColumn)
          if self:canSwap(cursorRow, swapColumn) then
            self:setQueuedSwapPosition(swapColumn, cursorRow)
          end
        end
        self.cur_col = cursorColumn
        self.cur_row = cursorRow
      end
    end

    -- Make sure we don't set the cursor higher than the top allowed row
    if self.cur_row > 0 and self.cur_row > self.top_cur_row then
      self.cur_row = self.top_cur_row
    end
  else --input method is controller
    local swap, up, down, left, right
    raise, swap, up, down, left, right = unpack(base64decode[sdata])

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

  if raise then
    if not self.prevent_manual_raise then
      self.manual_raise = true
      self.manual_raise_yet = false
    end
  end
end

function Stack:shouldRun(runsSoFar)
  if self:game_ended() then
    return false
  end

  if self:behindRollback() then
    return true
  end

  -- Decide how many frames of input we should run.
  local buffer_len = #self.input_buffer

  -- If we are local we always want to catch up and run the new input which is already appended
  if self.is_local then
    return buffer_len > 0
  else
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
  end

  return false
end

-- Runs one step of the stack.
function Stack.run(self)
  if self.match.isPaused then
    return
  end
  prof.push("Stack:run")

  if self.is_local == false then
    if self.play_to_end then
      if #self.input_buffer < 4 then
        self.play_to_end = nil
      end
    end
  end

  prof.push("Stack:setupInput")
  self:setupInput()
  prof.pop("Stack:setupInput")
  prof.push("Stack:simulate")
  self:simulate()
  prof.pop("Stack:simulate")
  prof.pop("Stack:run")
end

-- Grabs input from the buffer of inputs or from the controller and sends out to the network if needed.
function Stack.setupInput(self)
  self.input_state = nil

  if self:game_ended() == false then
    if self.input_buffer and #self.input_buffer > 0 then
      self.input_state = table.remove(self.input_buffer, 1)
    end
  else
    self.input_state = self:idleInput()
  end

  self:controls()
end

function Stack.receiveConfirmedInput(self, input)
  if utf8.len(input) == 1 then
    self.confirmedInput[#self.confirmedInput+1] = input
    self.input_buffer[#self.input_buffer+1] = input
  else
    local inputs = string.toCharTable(input)
    tableUtils.appendToList(self.confirmedInput, inputs)
    tableUtils.appendToList(self.input_buffer, inputs)
  end
  --logger.debug("Player " .. self.which .. " got new input. Total length: " .. #self.confirmedInput)
end

-- Enqueue a card animation
function Stack.enqueue_card(self, chain, x, y, n)
  if self.canvas == nil or self.play_to_end then
    return
  end

  local card_burstAtlas = nil
  local card_burstParticle = nil
  if config.popfx == true then
    if characters[self.character].popfx_style == "burst" or characters[self.character].popfx_style == "fadeburst" then
      card_burstAtlas = characters[self.character].images["burst"]
      local card_burstFrameDimension = card_burstAtlas:getWidth() / 9
      card_burstParticle = GraphicsUtil:newRecycledQuad(card_burstFrameDimension, 0, card_burstFrameDimension, card_burstFrameDimension, card_burstAtlas:getDimensions())
    end
  end
  self.card_q:push({frame = 1, chain = chain, x = x, y = y, n = n, burstAtlas = card_burstAtlas, burstParticle = card_burstParticle})
end

-- Enqueue a pop animation
function Stack.enqueue_popfx(self, x, y, popsize)
  if self.canvas == nil or self.play_to_end then
    return
  end

  local burstAtlas = nil
  local burstFrameDimension = nil
  local burstParticle = nil
  local bigParticle = nil
  local fadeAtlas = nil
  local fadeFrameDimension = nil
  local fadeParticle = nil
  if characters[self.character].images["burst"] then
    burstAtlas = characters[self.character].images["burst"]
    burstFrameDimension = burstAtlas:getWidth() / 9
    burstParticle = GraphicsUtil:newRecycledQuad(burstFrameDimension, 0, burstFrameDimension, burstFrameDimension, burstAtlas:getDimensions())
    bigParticle = GraphicsUtil:newRecycledQuad(0, 0, burstFrameDimension, burstFrameDimension, burstAtlas:getDimensions())
  end
  if characters[self.character].images["fade"] then
    fadeAtlas = characters[self.character].images["fade"]
    fadeFrameDimension = fadeAtlas:getWidth() / 9
    fadeParticle = GraphicsUtil:newRecycledQuad(fadeFrameDimension, 0, fadeFrameDimension, fadeFrameDimension, fadeAtlas:getDimensions())
  end
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
      popsize = popsize,
      x = x,
      y = y
    }
  )
end

local d_col = {up = 0, down = 0, left = -1, right = 1}
local d_row = {up = 1, down = -1, left = 0, right = 0}

function Stack.hasPanelsInTopRow(self)
  local panelRow = self.panels[self.height]
  for idx = 1, self.width do
    if panelRow[idx]:dangerous() then
      return true
    end
  end
  return false
end

function Stack.updateDangerBounce(self)
-- calculate which columns should bounce
  self.danger = false
  local panelRow = self.panels[self.height - 1]
  for idx = 1, self.width do
    if panelRow[idx]:dangerous() then
      self.danger = true
      self.danger_col[idx] = true
    else
      self.danger_col[idx] = false
    end
  end
  if self.danger then
    if self.panels_in_top_row and self.speed ~= 0 and not self.puzzle then
      -- Player has topped out, panels hold the "flattened" frame
      self.danger_timer = 0
    elseif self.stop_time == 0 then
      self.danger_timer = self.danger_timer + 1
    end
  else
    self.danger_timer = 0
  end
end

function Stack:updateDangerMusic()
  local dangerMusic = self:shouldPlayDangerMusic()
  if dangerMusic ~= self.danger_music then
    self.danger_music = dangerMusic
    self:emitSignal("dangerMusicChanged", self)
  end
end

-- determine whether to play danger music
-- Changed this to play danger when something in top 3 rows
-- and to play normal music when nothing in top 3 or 4 rows
function Stack:shouldPlayDangerMusic()
  if not self.danger_music then
    -- currently playing normal music
    for row = self.height - 2, self.height do
      local panelRow = self.panels[row]
      for column = 1, self.width do
        if panelRow[column].color ~= 0 and panelRow[column].state ~= "falling" or panelRow[column]:dangerous() then
          if self.shake_time > 0 then
            return false
          else
            return true
          end
        end
      end
    end
  else
    --currently playing danger
    local minRowForDangerMusic = self.height - 2
    if config.danger_music_changeback_delay then
      minRowForDangerMusic = self.height - 3
    end
    for row = minRowForDangerMusic, self.height do
      local panelRow = self.panels[row]
      if panelRow ~= nil and type(panelRow) == "table" then
        for column = 1, self.width do
          if panelRow[column].color ~= 0 then
            return true
          end
        end
      elseif self.warningsTriggered["Panels Invalid"] == nil then
        logger.warn("Panels have invalid data in them, please tell your local developer." .. dump(panels, true))
        self.warningsTriggered["Panels Invalid"] = true
      end
    end
  end

  return false
end

function Stack.updatePanels(self)
  if self.do_countdown then
    return
  end

  self.shake_time_on_frame = 0
  self.popSizeThisFrame = "small"
  for row = 1, #self.panels do
    for col = 1, self.width do
      local panel = self.panels[row][col]
      panel:update(self.panels)
    end
  end
end

function Stack.shouldDropGarbage(self)
  -- this is legit ugly, these should rather be returned in a parameter table
  -- or even better in a dedicated garbage class table
  local garbage = self.incomingGarbage:peek()

  -- new garbage can't drop if the stack is full
  -- new garbage always drops one by one
  if not self.panels_in_top_row and not self:has_falling_garbage() then
    if not self:hasActivePanels() then
      return true
    elseif garbage.isChain then
      -- drop chain garbage higher than 1 row immediately
      return garbage.height > 1
    else
      -- attackengine garbage higher than 1 (aka chain garbage) is treated as combo garbage
      -- that is to circumvent the garbage queue not allowing to send multiple chains simultaneously
      -- and because of that hack, we need to do another hack here and allow n-height combo garbage
      -- but only if the player is targetted by a detached attackengine
      return garbage.height > 1 and self.match.attackEngines[self.player] ~= nil
    end
  end
end

-- One run of the engine routine.
function Stack.simulate(self)
  prof.push("simulate 1")
  self:prep_first_row()
  local panels = self.panels
  local swapped_this_frame = nil
  table.clear(self.garbageLandedThisFrame)
  self:runCountDownIfNeeded()

  if self.pre_stop_time ~= 0 then
    self.pre_stop_time = self.pre_stop_time - 1
  elseif self.stop_time ~= 0 then
    self.stop_time = self.stop_time - 1
  end
  prof.pop("simulate 1")

  prof.push("simulate danger updates")
  self.panels_in_top_row = self:hasPanelsInTopRow()
  self:updateDangerBounce()
  self:updateDangerMusic()
  prof.pop("simulate danger updates")

  prof.push("new row stuff")
  if self.displacement == 0 and self.has_risen then
    self.top_cur_row = self.height
    self:new_row()
  end

  self:updateRiseLock()
  prof.pop("new row stuff")

  prof.push("speed increase")
  -- Increase the speed if applicable
  if self.levelData.speedIncreaseMode == 1 then
    -- increase per interval
    if self.clock == self.nextSpeedIncreaseClock then
      self.speed = min(self.speed + 1, 99)
      self.nextSpeedIncreaseClock = self.nextSpeedIncreaseClock + DT_SPEED_INCREASE
    end
  elseif self.panels_to_speedup <= 0 then
    -- mode 2: increase speed based on cleared panels
    self.speed = min(self.speed + 1, 99)
    self.panels_to_speedup = self.panels_to_speedup + PANELS_TO_NEXT_SPEED[self.speed]
  end
  prof.pop("speed increase")


  prof.push("passive raise")
  -- Phase 0 //////////////////////////////////////////////////////////////
  -- Stack automatic rising
  if self.behaviours.passiveRaise then
    if not self.manual_raise and self.stop_time == 0 and not self.rise_lock then
      if self.panels_in_top_row then
        self.health = self.health - 1
      else
        self.rise_timer = self.rise_timer - 1
        if self.rise_timer <= 0 then -- try to rise
          self.displacement = self.displacement - 1
          if self.displacement == 0 then
            self.prevent_manual_raise = false
            self.top_cur_row = self.height
            self:new_row()
          end
          self.rise_timer = self.rise_timer + consts.SPEED_TO_RISE_TIME[self.speed]
        end
      end
    end

    if self:checkGameOver() then
      self:setGameOver()
    end
  end

  prof.pop("passive raise")

  prof.push("reset stuff")
  if not self.panels_in_top_row and not self:has_falling_garbage() then
    self.health = self.levelData.maxHealth
  end

  if self.displacement % 16 ~= 0 then
    self.top_cur_row = self.height - 1
  end
  prof.pop("reset stuff")

  prof.push("old swap")
  -- Begin the swap we input last frame.
  if self:swapQueued() then
    self:swap(self.queuedSwapRow, self.queuedSwapColumn)
    swapped_this_frame = true
    self:setQueuedSwapPosition(0, 0)
  end
  prof.pop("old swap")

  prof.push("Stack:checkMatches")
  self:checkMatches()
  prof.pop("Stack:checkMatches")
  prof.push("Stack:updatePanels")
  self:updatePanels()
  prof.pop("Stack:updatePanels")

  prof.push("shake time updates")
  self.prev_shake_time = self.shake_time
  self.shake_time = self.shake_time - 1
  self.shake_time = max(self.shake_time, self.shake_time_on_frame)
  if self.shake_time == 0 then
    self.peak_shake_time = 0
  end

  prof.pop("shake time updates")

  -- Phase 3. /////////////////////////////////////////////////////////////
  -- Actions performed according to player input

  prof.push("cursor movement")
  -- CURSOR MOVEMENT
  local playMoveSounds = true -- set this to false to disable move sounds for debugging
  if self.inputMethod == "touch" then
      --with touch, cursor movement happen at stack:control time
  else
    if self.cur_dir and (self.cur_timer == 0 or self.cur_timer == self.cur_wait_time) and self.cursorLock == nil then
      local prev_row = self.cur_row
      local prev_col = self.cur_col
      self:moveCursorInDirection(self.cur_dir)
      if (playMoveSounds and (self.cur_timer == 0 or self.cur_timer == self.cur_wait_time) and (self.cur_row ~= prev_row or self.cur_col ~= prev_col)) then
        if self:canPlaySfx() then
          SFX_Cur_Move_Play = 1
        end
        if self.cur_timer ~= self.cur_wait_time then
          self.analytic:register_move()
        end
      end
    else
      self.cur_row = util.bound(1, self.cur_row, self.top_cur_row)
    end
  end

  if self.cur_timer ~= self.cur_wait_time then
    self.cur_timer = self.cur_timer + 1
  end
  prof.pop("cursor movement")

  prof.push("taunt")
  -- TAUNTING
  if self:canPlaySfx() then
    if self.taunt_up ~= nil then
      characters[self.character]:playTauntUpSfx(self.taunt_up)
      self:taunt("taunt_up")
      self.taunt_up = nil
    elseif self.taunt_down ~= nil then
      characters[self.character]:playTauntDownSfx(self.taunt_down)
      self:taunt("taunt_down")
      self.taunt_down = nil
    end
  end
  prof.pop("taunt")

  prof.push("new swap")
  -- Queue Swapping
  -- Note: Swapping is queued in Stack.controls for touch mode
  if self.inputMethod == "controller" then
    if (self.swap_1 or self.swap_2) and not swapped_this_frame then
      local canSwap = self:canSwap(self.cur_row, self.cur_col)
      if canSwap then
        self:setQueuedSwapPosition(self.cur_col, self.cur_row)
        self.analytic:register_swap()
      end
      self.swap_1 = false
      self.swap_2 = false
    end
  end
  prof.pop("new swap")

  prof.push("active raise")
  -- MANUAL STACK RAISING
  if self.behaviours.allowManualRaise then
    if self.manual_raise then
      if not self.rise_lock then
        if self.panels_in_top_row then
          if self:checkGameOver() then
            self:setGameOver()
          end
        else
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
        end
      elseif not self.manual_raise_yet then
        self.manual_raise = false
      end
    -- if the stack is rise locked when you press the raise button,
    -- the raising is cancelled
    end
  end
  prof.pop("active raise")

  prof.push("chain update")
  -- if at the end of the routine there are no chain panels, the chain ends.
  if self.chain_counter ~= 0 and not self:hasChainingPanels() then
    if self:canPlaySfx() then
      SFX_Fanfare_Play = self.chain_counter
    end
    self.analytic:register_chain(self.chain_counter)
    self.chain_counter = 0

    if self.outgoingGarbage then
      logger.debug("Player " .. self.which .. " chain ended at " .. self.clock)
      self.outgoingGarbage:finalizeCurrentChain(self.clock)
    end
  end
  prof.pop("chain update")

  if (self.score > 99999) then
    self.score = 99999
  -- lol owned
  end

  prof.push("updateActivePanels")
  self:updateActivePanels()
  prof.pop("updateActivePanels")

  if self.puzzle and self.n_active_panels == 0 and self.n_prev_active_panels == 0 then
    if self:checkGameOver() then
      self:setGameOver()
    end
  end

  prof.push("process staged garbage")
  self.outgoingGarbage:processStagedGarbageForClock(self.clock)
  prof.pop("process staged garbage")

  prof.push("remove_extra_rows")
  self:remove_extra_rows()
  prof.pop("remove_extra_rows")

  prof.push("double-check panels_in_top_row")
  --double-check panels_in_top_row

  self.panels_in_top_row = false
  -- If any dangerous panels are in the top row, garbage should not fall.
  for col_idx = 1, self.width do
    if panels[self.height][col_idx]:dangerous() then
      self.panels_in_top_row = true
    end
  end
  prof.pop("double-check panels_in_top_row")

  prof.push("doublecheck panels above top row")
  -- If any panels (dangerous or not) are in rows above the top row, garbage should not fall.
  for row_idx = self.height + 1, #self.panels do
    for col_idx = 1, self.width do
      if panels[row_idx][col_idx].color ~= 0 then
        self.panels_in_top_row = true
      end
    end
  end
  prof.pop("doublecheck panels above top row")


  prof.push("pop from incoming garbage q")
  if self.incomingGarbage:len() > 0 then
    if self:shouldDropGarbage() then
      self:tryDropGarbage()
    end
  end
  prof.pop("pop from incoming garbage q")

  prof.push("stack sfx")
  -- Update Sound FX
  if self:canPlaySfx() then
    if SFX_Swap_Play == 1 then
      SoundController:playSfx(themes[config.theme].sounds.swap)
      SFX_Swap_Play = 0
    end
    if SFX_Cur_Move_Play == 1 then
      -- I have no idea why this makes a distinction for vs, like what?
      if not (self.match.stackInteraction ~= GameModes.StackInteractions.NONE and themes[config.theme].sounds.swap:isPlaying()) and not self.do_countdown then
        SoundController:playSfx(themes[config.theme].sounds.cur_move)
      end
      SFX_Cur_Move_Play = 0
    end
    if self.sfx_land then
      SoundController:playSfx(themes[config.theme].sounds.land)
      self.sfx_land = false
    end
    if self.combo_chain_play then
      -- stop ongoing landing sound
      SoundController:stopSfx(themes[config.theme].sounds.land)
      -- and cancel it because an attack is performed on the exact same frame (takes priority)
      self.sfx_land = false
      SoundController:stopSfx(themes[config.theme].sounds.pops[self.lastPopLevelPlayed][self.lastPopIndexPlayed])
      characters[self.character]:playAttackSfx(self.combo_chain_play)
      self.combo_chain_play = nil
    end
    if SFX_garbage_match_play then
      characters[self.character]:playGarbageMatchSfx()
      SFX_garbage_match_play = nil
    end
    if SFX_Fanfare_Play == 0 then
      --do nothing
    elseif SFX_Fanfare_Play >= 6 then
      SoundController:playSfx(themes[config.theme].sounds.fanfare3)
    elseif SFX_Fanfare_Play >= 5 then
      SoundController:playSfx(themes[config.theme].sounds.fanfare2)
    elseif SFX_Fanfare_Play >= 4 then
      SoundController:playSfx(themes[config.theme].sounds.fanfare1)
    end
    SFX_Fanfare_Play = 0
    if self.sfx_garbage_thud >= 1 and self.sfx_garbage_thud <= 3 then
      local interrupted_thud = nil
      for i = 1, 3 do
        if themes[config.theme].sounds.garbage_thud[i]:isPlaying() and self.shake_time > self.prev_shake_time then
          SoundController:stopSfx(themes[config.theme].sounds.garbage_thud[i])
          interrupted_thud = i
        end
      end
      if interrupted_thud and interrupted_thud > self.sfx_garbage_thud then
        SoundController:playSfx(themes[config.theme].sounds.garbage_thud[interrupted_thud])
      else
        SoundController:playSfx(themes[config.theme].sounds.garbage_thud[self.sfx_garbage_thud])
      end
      if interrupted_thud == nil then
        characters[self.character]:playGarbageLandSfx()
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
      SoundController:stopSfx(themes[config.theme].sounds.pops[self.lastPopLevelPlayed][self.lastPopIndexPlayed])
      --play the appropriate pop sound
      SoundController:playSfx(themes[config.theme].sounds.pops[popLevel][popIndex])
      self.lastPopLevelPlayed = popLevel
      self.lastPopIndexPlayed = popIndex
      SFX_Pop_Play = nil
      SFX_Garbage_Pop_Play = nil
    end
  end
  prof.pop("stack sfx")

  prof.push("update times")
  self.clock = self.clock + 1

  if self.game_stopwatch_running and (not self.match.gameOverClock or self.clock <= self.match.gameOverClock) then
    self.game_stopwatch = (self.game_stopwatch or -1) + 1
  end
  prof.pop("update times")

  prof.push("update popfx")
  self:update_popfxs()
  prof.pop("update popfx")
  prof.push("update cards")
  self:update_cards()
  prof.pop("update cards")

end

function Stack:runGameOver()
  self:update_popfxs()
  self:update_cards()
end

function Stack:runCountDownIfNeeded()
  if self.do_countdown then
    self.game_stopwatch_running = false
    self.rise_lock = true
    if self.clock == 0 then
      self.animatingCursorDuringCountdown = true
      if self.match.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE then
        self.cursorLock = true
      end
      self.cur_row = self.height
      if self.inputMethod == "touch" then
        self.cur_col = self.width
      elseif self.inputMethod == "controller" then
        self.cur_col = self.width - 1
      end
    elseif self.clock == consts.COUNTDOWN_START then
      self.countdown_timer = consts.COUNTDOWN_LENGTH
    end
    if self.countdown_timer then
      local countDownFrame = consts.COUNTDOWN_LENGTH - self.countdown_timer
      if countDownFrame > 0 and countDownFrame % consts.COUNTDOWN_CURSOR_SPEED == 0 then
        local moveIndex = math.floor(countDownFrame / consts.COUNTDOWN_CURSOR_SPEED)
        if moveIndex <= 4 then
          self:moveCursorInDirection("down")
        elseif moveIndex <= 6 then
          self:moveCursorInDirection("left")

        elseif moveIndex == 10 then
          self.animatingCursorDuringCountdown = nil
          if self.inputMethod == "touch" then
            self.cur_row = 0
            self.cur_col = 0
          end
        end
      elseif countDownFrame == 6 * consts.COUNTDOWN_CURSOR_SPEED + 1 then
        if self.match.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE then
          self.cursorLock = nil
        end
      end
      if self.countdown_timer == 0 then
        --we are done counting down
        self.do_countdown = false
        self.countdown_timer = nil
        self.game_stopwatch_running = true
      end
      if self.countdown_timer then
        self.countdown_timer = self.countdown_timer - 1
      end
    end
  end
end

function Stack:moveCursorInDirection(directionString)
  assert(directionString ~= nil and type(directionString) == "string")
  self.cur_row = util.bound(1, self.cur_row + d_row[directionString], self.top_cur_row)
  self.cur_col = util.bound(1, self.cur_col + d_col[directionString], self.width - 1)
end

function Stack.behindRollback(self)
  if self.lastRollbackFrame > self.clock then
    return true
  end

  return false
end

function Stack:canPlaySfx()
  -- this should be superfluous because there is no code being run that would play sfx
  -- if self:game_ended() then
  --   return false
  -- end

  -- If we are still catching up from rollback don't play sounds again
  if self:behindRollback() then
    return false
  end

  -- this is catchup mode, don't play sfx during this
  if self.play_to_end then
    return false
  end

  return true
end

-- Returns true if the stack is simulated past the end of the match.
function Stack:game_ended()
  if self.game_over_clock > 0 then
    return self.clock >= self.game_over_clock
  else
    return self:checkGameWin()
  end
end

-- Sets the current stack as "lost"
-- Also begins drawing game over effects
function Stack.setGameOver(self)

  if self.game_over_clock > 0 then
    -- it is possible that game over is set twice on the same frame
    -- this happens if someone died to passive raise while holding manual raise
    -- we shouldn't try to set game over again under any other circumstances however
    assert(self.clock == self.game_over_clock, "game over was already set to a different clock time")
    return
  end

  SoundController:playSfx(themes[config.theme].sounds.game_over)

  self.game_over_clock = self.clock

  if self.canvas then
    local popsize = "small"
    local panels = self.panels
    for row = 1, #panels do
      for col = 1, self.width do
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
  if #characters[self.character].sounds.win ~= 0 then
    return characters[self.character].sounds.win[math.random(#characters[self.character].sounds.win)]
  else
    return themes[config.theme].sounds.fanfare1 -- TODO add a default win sound
  end
end

-- returns true if the panel in row/column can be swapped with the panel to its right (column + 1)
function Stack.canSwap(self, row, column)
  local panels = self.panels
  -- in order for a swap to occur, one of the two panels in
  -- the cursor must not be a non-panel.
  local do_swap =
    (panels[row][column].color ~= 0 or panels[row][column + 1].color ~= 0) and -- also, both spaces must be swappable.
    panels[row][column]:canSwap() and
    panels[row][column + 1]:canSwap() and -- also, neither space above us can be hovering.
    (row == #panels or (panels[row + 1][column].state ~= "hovering" and panels[row + 1][column + 1].state ~= "hovering")) and --also, we can't swap if the game countdown isn't finished
    not self.do_countdown and --also, don't swap on the first frame
    not (self.clock and self.clock <= 1)
  -- If you have two pieces stacked vertically, you can't move
  -- both of them to the right or left by swapping with empty space.
  -- TODO: This might be wrong if something lands on a swapping panel?
  if panels[row][column].color == 0 or panels[row][column + 1].color == 0 then -- if either panel inside the cursor is air
    do_swap = do_swap -- failing the condition if we already determined we cant swap 
      and not -- one of the next 4 lines must be false in order to swap
        (row ~= self.height -- true if cursor is not at top of stack
        and (panels[row + 1][column].state == "swapping" and panels[row + 1][column + 1].state == "swapping") -- true if BOTH panels above cursor are swapping
        and (panels[row + 1][column].color == 0 or panels[row + 1][column + 1].color == 0) -- true if either panel above the cursor is air
        and (panels[row + 1][column].color ~= 0 or panels[row + 1][column + 1].color ~= 0)) -- true if either panel above the cursor is not air

    do_swap = do_swap  -- failing the condition if we already determined we cant swap 
      and not -- one of the next 4 lines must be false in order to swap
        (row ~= 1 -- true if the cursor is not at the bottom of the stack
        and (panels[row - 1][column].state == "swapping" and panels[row - 1][column + 1].state == "swapping") -- true if BOTH panels below cursor are swapping
        and (panels[row - 1][column].color == 0 or panels[row - 1][column + 1].color == 0) -- true if either panel below the cursor is air
        and (panels[row - 1][column].color ~= 0 or panels[row - 1][column + 1].color ~= 0)) -- true if either panel below the cursor is not air
  end

  do_swap = do_swap and (not self.puzzle or self.puzzle.moves == 0 or self.puzzle.remaining_moves > 0)

  return do_swap
end

-- Swaps panels at the current cursor location
function Stack:swap(row, col)
  local panels = self.panels
  self:processPuzzleSwap()
  local leftPanel = panels[row][col]
  local rightPanel = panels[row][col + 1]
  leftPanel:startSwap(true)
  rightPanel:startSwap(false)
  Panel.switch(leftPanel, rightPanel, panels)

  if self:canPlaySfx() then
    SFX_Swap_Play = 1
  end

  -- If you're swapping a panel into a position
  -- above an empty space or above a falling piece
  -- then you can't take it back since it will start falling.
  if row ~= 1 then
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
  if row ~= self.height then
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
      self.behaviours.passiveRaise = true
      self.stop_time = self.puzzle.stop_time
      self.shake_time = self.puzzle.shake_time
      self.peak_shake_time = self.shake_time
    end
    self.puzzle.remaining_moves = self.puzzle.remaining_moves - 1
  end
end

-- Removes unneeded rows
function Stack.remove_extra_rows(self)
  local panels = self.panels
  for row = #panels, self.height + 1, -1 do
    local nonempty = false
    local panelRow = panels[row]
    for col = 1, self.width do
      nonempty = nonempty or (panelRow[col].color ~= 0)
    end
    if nonempty then
      break
    else
      panels[row] = nil
    end
  end
end

-- tries to drop a width x height garbage.
-- returns true if garbage was dropped, false otherwise
function Stack:tryDropGarbage()
  logger.debug("trying to drop garbage at frame "..self.clock)

  -- Do one last check for panels in the way.
  for i = self.height + 1, #self.panels do
    if self.panels[i] then
      for j = 1, self.width do
        if self.panels[i][j] then
          if self.panels[i][j].color ~= 0 then
            logger.trace("Aborting garbage drop: panel found at row " .. tostring(i) .. " column " .. tostring(j))
            return
          end
        end
      end
    end
  end

  local garbage = self.incomingGarbage:pop()
  logger.debug(string.format("%d Dropping garbage on player %d - height %d  width %d  %s", self.clock, self.player_number, garbage.height, garbage.width, garbage.isMetal and "Metal" or ""))

  self:dropGarbage(garbage.width, garbage.height, garbage.isMetal)

  return true
end

function Stack.getGarbageSpawnColumn(self, garbageWidth)
  local columns = self.garbageSizeDropColumnMaps[garbageWidth]
  local index = self.currentGarbageDropColumnIndexes[garbageWidth]
  local spawnColumn = columns[index]
  -- the next piece of garbage of that width should fall at a different idx
  self.currentGarbageDropColumnIndexes[garbageWidth] = wrap(1, index + 1, #columns)
  return spawnColumn
end

function Stack.dropGarbage(self, width, height, isMetal)
  -- garbage always drops in row 13
  local originRow = self.height + 1
  -- combo garbage will alternate it's spawn column
  local originCol = self:getGarbageSpawnColumn(width)
  local function isPartOfGarbage(column)
    return column >= originCol and column < (originCol + width)
  end

  self.garbageCreatedCount = self.garbageCreatedCount + 1
  local shakeTime = self:shakeFramesForGarbageSize(width, height)

  for row = originRow, originRow + height - 1 do
    if not self.panels[row] then
      self.panels[row] = {}
      -- every row that will receive garbage needs to be fully filled up
      -- so iterate from 1 to stack width instead of column to column + width - 1
      for col = 1, self.width do
        local panel = self:createPanelAt(row, col)

        if isPartOfGarbage(col) then
          panel.garbageId = self.garbageCreatedCount
          panel.isGarbage = true
          panel.color = 9
          panel.width = width
          panel.height = height
          panel.y_offset = row - originRow
          panel.x_offset = col - originCol
          panel.shake_time = shakeTime
          panel.state = "falling"
          panel.row = row
          panel.column = col
          if isMetal then
            panel.metal = isMetal
          end
        end
      end
    end
  end
end

-- Adds a new row to the play field
function Stack.new_row(self)
  local panels = self.panels
  -- move cursor up
  if self.cur_row ~= 0 then
    self.cur_row = util.bound(1, self.cur_row + 1, self.top_cur_row)
  end
  if self.queuedSwapRow > 0 then
    self.queuedSwapRow = self.queuedSwapRow + 1
  end
  if self.inputMethod == "touch" then
    self.touchInputController:stackIsCreatingNewRow()
  end

  -- create new row at the top
  local stackHeight = #panels + 1
  panels[stackHeight] = {}

  for col = 1, self.width do
    self:createPanelAt(stackHeight, col)
  end

  -- move panels up
  for row = stackHeight, 1, -1 do
    for col = #panels[row], 1, -1 do
      Panel.switch(panels[row][col], panels[row - 1][col], panels)
    end
  end

  -- the new row we created earlier at the top is now at row 0!
  -- while the former row 0 is at row 1 and in play
  -- therefore we need to override dimmed state in row 1
  -- this cannot happen in the regular updatePanels routine as checkMatches is called after
  -- meaning the panels already need to be eligible for matches!
  for col = 1, self.width do
    panels[1][col].state = "normal"
    panels[1][col].stateChanged = true
  end

  if string.len(self.panel_buffer) <= 10 * self.width then
    self.panel_buffer = self:makePanels()
  end

  -- assign colors to the new row 0
  local metal_panels_this_row = 0
  if self.metal_panels_queued > 3 then
    self.metal_panels_queued = self.metal_panels_queued - 2
    metal_panels_this_row = 2
  elseif self.metal_panels_queued > 0 then
    self.metal_panels_queued = self.metal_panels_queued - 1
    metal_panels_this_row = 1
  end

  for col = 1, self.width do
    local panel = panels[0][col]
    local this_panel_color = string.sub(self.panel_buffer, col, col)
    --a capital letter for the place where the first shock block should spawn (if earned), and a lower case letter is where a second should spawn (if earned).  (color 8 is metal)
    if tonumber(this_panel_color) then
      --do nothing special
    elseif this_panel_color >= "A" and this_panel_color <= "Z" then
      if metal_panels_this_row > 0 then
        this_panel_color = 8
      else
        this_panel_color = PanelGenerator.PANEL_COLOR_TO_NUMBER[this_panel_color]
      end
    elseif this_panel_color >= "a" and this_panel_color <= "z" then
      if metal_panels_this_row > 1 then
        this_panel_color = 8
      else
        this_panel_color = PanelGenerator.PANEL_COLOR_TO_NUMBER[this_panel_color]
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
  data.attackPatterns = {}
  data.extraInfo = {}
  data.extraInfo.playerName = self.player.name
  data.extraInfo.gpm = self.analytic:getRoundedGPM(self.clock) or 0
  data.extraInfo.matchLength = " "
  if self.game_stopwatch and tonumber(self.game_stopwatch) then
    data.extraInfo.matchLength = frames_to_time_string(self.game_stopwatch)
  end
  local now = os.date("*t", to_UTC(os.time()))
  data.extraInfo.dateGenerated = string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)

  data.mergeComboMetalQueue = false
  data.delayBeforeStart = 0
  data.delayBeforeRepeat = 91
  data.disableQueueLimit = self.player.human
  local defaultEndTime = 70

  for _, garbage in ipairs(self.outgoingGarbage.history) do
    if garbage.isChain then
      if garbage.finalized then
        data.attackPatterns[#data.attackPatterns+1] = {chain = garbage.linkTimes, chainEndTime = garbage.finalizedClock}
      else
        -- chain garbage may not be finalized yet so fake an end time
        data.attackPatterns[#data.attackPatterns+1] = {chain = garbage.linkTimes, chainEndTime = garbage.linkTimes[#garbage.linkTimes] + defaultEndTime}
      end
    else
      data.attackPatterns[#data.attackPatterns+1] = {width = garbage.width, height = garbage.height, startTime = garbage.frameEarned, chain = false, metal = garbage.isMetal}
    end
  end

  local state = {keyorder = {"extraInfo", "playerName", "gpm", "matchLength", "dateGenerated", "mergeComboMetalQueue", "delayBeforeStart", "delayBeforeRepeat", "attackPatterns"}}

  return data, state
end

-- creates a new panel at the specified row+column and adds it to the Stack's panels table
function Stack.createPanelAt(self, row, column)
  self.panelsCreatedCount = self.panelsCreatedCount + 1
  local panel = Panel(self.panelsCreatedCount, row, column, self.levelData.frameConstants)
  panel:connectSignal("pop", self, self.onPop)
  panel:connectSignal("popped", self, self.onPopped)
  panel:connectSignal("land", self, self.onLand)
  self.panels[row][column] = panel
  return panel
end

function Stack.onPop(self, panel)
  if panel.isGarbage then
    if config.popfx == true then
      self:enqueue_popfx(panel.column, panel.row, self.popSizeThisFrame)
    end
    if self:canPlaySfx() then
      SFX_Garbage_Pop_Play = panel.pop_index
    end
  else
    if config.popfx == true then
      if (panel.combo_size > 6) or self.chain_counter > 1 then
        self.popSizeThisFrame = "normal"
      end
      if self.chain_counter > 2 then
        self.popSizeThisFrame = "big"
      end
      if self.chain_counter > 3 then
        self.popSizeThisFrame = "giant"
      end
      self:enqueue_popfx(panel.column, panel.row, self.popSizeThisFrame)
    end
    self.score = self.score + 10

    self.panels_cleared = self.panels_cleared + 1
    if self.match.stackInteraction ~= GameModes.StackInteractions.NONE
        and self.panels_cleared % self.levelData.shockFrequency == 0 then
          self.metal_panels_queued = min(self.metal_panels_queued + 1, self.levelData.shockCap)
    end
    if self:canPlaySfx() then
      SFX_Pop_Play = 1
    end
    self.poppedPanelIndex = panel.combo_index
  end
end

function Stack.onPopped(self, panel)
  if self.panels_to_speedup then
    self.panels_to_speedup = self.panels_to_speedup - 1
  end
end

function Stack.onLand(self, panel)
  if panel.isGarbage then
    self:onGarbageLand(panel)
  else
    if panel.state == "falling" and self:canPlaySfx() then
      self.sfx_land = true
    end
  end
end

function Stack.onGarbageLand(self, panel)
  if panel.shake_time
    -- only parts of the garbage that are on the visible board can be considered for shake
    and panel.row <= self.height then
    --runtime optimization to not repeatedly update shaketime for the same piece of garbage
    if not tableUtils.contains(self.garbageLandedThisFrame, panel.garbageId) then
      if self:canPlaySfx() then
        if panel.height > 3 then
          self.sfx_garbage_thud = 3
        else
          self.sfx_garbage_thud = panel.height
        end
      end
      self.shake_time_on_frame = max(self.shake_time_on_frame, panel.shake_time, self.peak_shake_time or 0)
      --a smaller garbage block landing should renew the largest of the previous blocks' shake times since our shake time was last zero.
      self.peak_shake_time = max(self.shake_time_on_frame, self.peak_shake_time or 0)

      -- to prevent from running this code dozens of time for the same garbage block
      -- all panels of a garbage block have the same id + shake time
      self.garbageLandedThisFrame[#self.garbageLandedThisFrame+1] = panel.garbageId
    end

    -- whether we ran through it or not, the panel should lose its shake time
    panel.shake_time = nil
    self:emitSignal("hurt", "hurt")
  end
end

function Stack.hasChainingPanels(self)
  -- row 0 panels can never chain cause they're dimmed
  for row = 1, #self.panels do
    for col = 1, self.width do
      local panel = self.panels[row][col]
      if panel.chaining and panel.color ~= 0 then
        return true
      end
    end
  end

  return false
end

function Stack.updateActivePanels(self)
  self.n_prev_active_panels = self.n_active_panels
  self.n_active_panels = self:getActivePanelCount()
end

function Stack.getActivePanelCount(self)
  local count = 0

  for row = 1, self.height do
    for col = 1, self.width do
      local panel = self.panels[row][col]
      if panel.isGarbage then
        if panel.state ~= "normal" then
          count = count + 1
        end
      else
        if panel.color ~= 0
        -- dimmed is implicitly filtered by only checking in row 1 and up
        and panel.state ~= "normal"
        and panel.state ~= "landing" then
          count = count + 1
        end
      end
    end
  end

  return count
end

function Stack.updateRiseLock(self)
  self.prev_rise_lock = self.rise_lock
  if self.do_countdown then
    self.rise_lock = true
  elseif self:swapQueued()then
    self.rise_lock = true
  elseif self.shake_time > 0 then
    self.rise_lock = true
  elseif self:hasActivePanels() then
    self.rise_lock = true
  else
    self.rise_lock = false
  end

  -- prevent manual raise is set true when manually raising
  if self.prev_rise_lock and not self.rise_lock then
    self.prevent_manual_raise = false
  end
end

function Stack:getInfo()
  local info = {}
  info.playerNumber = self.which
  info.character = self.character
  info.inputMethod = self.inputMethod
  info.rollbackCount = self.rollbackCount
  if self.rollbackCopies then
    info.rollbackCopyCount = tableUtils.length(self.rollbackCopies)
  else
    info.rollbackCopyCount = 0
  end

  return info
end

function Stack:makePanels()
  PanelGenerator:setSeed(self.match.seed + self.panelGenCount)
  local ret
  if self.panel_buffer == "" then
    ret = self:makeStartingBoardPanels()
  else
    ret = PanelGenerator.privateGeneratePanels(100, self.width, self.levelData.colors, self.panel_buffer, not self.allowAdjacentColors)
    ret = PanelGenerator.assignMetalLocations(ret, self.width)
  end

  self.panelGenCount = self.panelGenCount + 1

  return ret
end

function Stack:makeStartingBoardPanels()
  local allowAdjacentColors = tableUtils.trueForAll(self.match.players, function(player) return player.stack.allowAdjacentColors end)

  local ret = PanelGenerator.privateGeneratePanels(7, self.width, self.levelData.colors, self.panel_buffer, not allowAdjacentColors)
  -- technically there can never be metal on the starting board but we need to call it to advance the RNG (compatibility)
  ret = PanelGenerator.assignMetalLocations(ret, self.width)

  -- legacy crutch, the arcane magic for the non-uniform starting board assumes this is there and it really doesn't work without it
  ret = string.rep("0", self.width) .. ret
  -- arcane magic to get a non-uniform starting board
  ret = procat(ret)
  local maxStartingHeight = 7
  local height = tableUtils.map(procat(string.rep(maxStartingHeight, self.width)), function(s) return tonumber(s) end)
  local to_remove = 2 * self.width
  while to_remove > 0 do
    local idx = PanelGenerator:random(1, self.width) -- pick a random column
    if height[idx] > 0 then
      ret[idx + self.width * (-height[idx] + 8)] = "0" -- delete the topmost panel in this column
      height[idx] = height[idx] - 1
      to_remove = to_remove - 1
    end
  end

  ret = table.concat(ret)
  ret = string.sub(ret, self.width + 1)

  PanelGenerator.privateCheckPanels(ret, self.width)

  return ret
end

function Stack:checkGameOver()
  if self.game_over_clock <= 0 then
    for _, gameOverCondition in ipairs(self.gameOverConditions) do
      if gameOverCondition == GameModes.GameOverConditions.NEGATIVE_HEALTH then
        if self.health <= 0 and self.shake_time <= 0 then
          return true
        elseif not self.rise_lock and self.behaviours.allowManualRaise and self.panels_in_top_row and self.manual_raise then
          return true
        end
      elseif gameOverCondition == GameModes.GameOverConditions.NO_MOVES_LEFT then
        if self.puzzle.remaining_moves <= 0 and not self:hasActivePanels() then
          return true
        end
      elseif gameOverCondition == GameModes.GameOverConditions.CHAIN_DROPPED then
        if #self.analytic.data.reached_chains == 0 and self.analytic.data.destroyed_panels > 0 then
          -- We finished matching but never made a chain -> fail
          return true
        end
        if #self.analytic.data.reached_chains > 0 and not self:hasChainingPanels() then
          -- We achieved a chain, finished chaining, but haven't won yet -> fail
          return true
        end
      end
    end
  else
    return true
  end
end

function Stack:checkGameWin()
  for _, gameWinCondition in ipairs(self.gameWinConditions) do
    if gameWinCondition == GameModes.GameWinConditions.NO_MATCHABLE_PANELS then
      local panels = self.panels
      local matchablePanelFound = false
      for row = 1, self.height do
        for col = 1, self.width do
          local color = panels[row][col].color
          if color ~= 0 and color ~= 9 then
            matchablePanelFound = true
          end
        end
      end
      if not matchablePanelFound then
        return true
      end
    elseif gameWinCondition == GameModes.GameWinConditions.NO_MATCHABLE_GARBAGE then
      if not self:hasGarbage() then
        return true
      end
    end
  end

  -- match is over and we didn't die so clearly we won
  if self.match.ended and self.game_over_clock <= 0 then
    return true
  end

  return false
end

-- returns the amount of shake frames for a piece of garbage with the given dimensions
function Stack:shakeFramesForGarbageSize(width, height)
  -- shake time directly scales with the number of panels contained in the garbage
  local panelCount = width * height

  -- sanitization for garbage dimensions has to happen elsewhere (garbage queue?), not here

  if panelCount > #GARBAGE_SIZE_TO_SHAKE_FRAMES then
    return GARBAGE_SIZE_TO_SHAKE_FRAMES[#GARBAGE_SIZE_TO_SHAKE_FRAMES]
  elseif panelCount > 0 then
    return GARBAGE_SIZE_TO_SHAKE_FRAMES[panelCount]
  else
    error("Trying to determine shake time of a garbage block with width " .. width .. " and height " .. height)
  end
end

function Stack:isCatchingUp()
  return self.play_to_end
end

function Stack:disablePassiveRaise()
  self.behaviours.passiveRaise = false
end

-- other parts of stack
require("common.engine.checkMatches")
-- TODO: does this stay on client or not?
require("client.src.network.Stack")


return Stack