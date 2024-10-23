-- TODO: move asset loading related and client only required components into client
local ModController = require("client.src.mods.ModController")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local StageLoader = require("client.src.mods.StageLoader")
local SoundController = require("client.src.music.SoundController")
-- Match should at most need the MatchParticipant properties rather than these;
-- TODO: move the related createFromReplay func
local Player = require("client.src.Player")
local ChallengeModePlayer = require("client.src.ChallengeModePlayer")

local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local GameModes = require("common.engine.GameModes")
local Replay = require("common.engine.Replay")
local Signal = require("common.lib.signal")
local SimulatedStack = require("common.engine.SimulatedStack")
local Stack = require("common.engine.Stack")
local consts = require("common.engine.consts")
local prof = require("common.lib.jprof.jprof")

-- A match is a particular instance of the game, for example 1 time attack round, or 1 vs match
Match =
  class(
  function(self, players, doCountdown, stackInteraction, winConditions, gameOverConditions, supportsPause, optionalArgs)
    self.spectators = {}
    self.spectatorString = ""
    self.players = {}
    self.stacks = {}
    self.engineVersion = consts.ENGINE_VERSION

    assert(doCountdown ~= nil)
    assert(stackInteraction)
    assert(winConditions)
    assert(gameOverConditions)
    assert(supportsPause ~= nil)
    self.doCountdown = doCountdown
    self.stackInteraction = stackInteraction
    self.winConditions = winConditions
    self.gameOverConditions = gameOverConditions
    if tableUtils.contains(gameOverConditions, GameModes.GameOverConditions.TIME_OUT) then
      assert(optionalArgs.timeLimit)
      self.timeLimit = optionalArgs.timeLimit
    end
    self.supportsPause = supportsPause
    if optionalArgs then
      -- debatable if these couldn't be player settings instead
      self.puzzle = optionalArgs.puzzle
      self.ranked = optionalArgs.ranked
    end

    -- match needs its own table so it can sort players with impunity
    for i = 1, #players do
      self:addPlayer(players[i])
    end

    GAME.droppedFrames = 0
    self.timeSpentRunning = 0
    self.maxTimeSpentRunning = 0
    self.createTime = love.timer.getTime()
    self.currentMusicIsDanger = false
    self.seed = math.random(1,9999999)
    self.isFromReplay = false
    self.startTimestamp = os.time(os.date("*t"))
    self.isPaused = false
    self.renderDuringPause = false
    self.clock = 0

    Signal.turnIntoEmitter(self)
    self:createSignal("matchEnded")
    self:createSignal("dangerMusicChanged")
    self:createSignal("countdownEnded")
  end
)

-- Should be called prior to clearing the match.
-- Consider recycling any memory that might leave around a lot of garbage.
-- Note: You can just leave the variables to clear / garbage collect on their own if they aren't large.
function Match:deinit()
  for i = 1, #self.stacks do
    self.stacks[i]:deinit()
  end
end

function Match:addPlayer(player)
  self.players[#self.players+1] = player
end

-- returns the players that won the match in a table
-- returns a single winner if there was a clear winner
-- returns multiple winners if there was a tie (or the game mode had no win conditions)
-- returns an empty table if there was no winner due to the game not finishing / getting aborted
-- the function caches the result of the first call so it should only be called when the match has ended
function Match:getWinners()
  -- return a cached result if the function was already called before
  if self.winners then
    return self.winners
  end

  -- game over is handled on the stack level and results in stack:game_ended() = true
  -- win conditions are in ORDER, meaning if player A met win condition 1 and player B met win condition 2, player A wins
  -- while if both players meet win condition 1 and player B meets win condition 2, player B wins

  local winners = {}
  if #self.players == 1 then
    -- with only a single player, they always win I guess
    winners[1] = self.players[1]
  else
    -- the winner is determined through process of elimination
    -- for each win condition in sequence, all players not meeting that win condition are purged from potentialWinners
    -- this happens until there is only 1 winner left or until there are no win conditions left to check which may result in a tie
    local potentialWinners = shallowcpy(self.players)
    for i = 1, #self.winConditions do
      local metCondition = {}
      local winCon = self.winConditions[i]
      for j = 1, #potentialWinners do
        local potentialWinner = potentialWinners[j]

        -- now we check for this player whether they meet the current winCondition
        if winCon == GameModes.WinConditions.LAST_ALIVE then
          if potentialWinner.stack.game_over_clock <= 0 then
            table.insert(metCondition, potentialWinner)
          end
        elseif winCon == GameModes.WinConditions.SCORE then
          local hasHighestScore = true
          for k = 1, #potentialWinners do
            if k ~= j then
              -- only if someone else has a higher score than me do I lose
              -- makes sure to cover score ties
              if potentialWinner.stack.score < potentialWinners[k].stack.score then
                hasHighestScore = false
                break
              end
            end
          end
          if hasHighestScore then
            table.insert(metCondition, potentialWinner)
          end
        elseif winCon == GameModes.WinConditions.TIME then
          -- this currently assumes less time is better which would be correct for endless max score or challenge
          -- probably need an alternative for a survival vs against an attack engine where more time wins
          local hasLowestTime = true
          for k = 1, #potentialWinners do
            if k ~= j then
              if #potentialWinner.stack.confirmedInput < #potentialWinners[k].stack.confirmedInput then
                hasLowestTime = false
                break
              end
            end
          end
          if hasLowestTime then
            table.insert(metCondition, potentialWinner)
          end
        elseif winCon == GameModes.WinConditions.NO_MATCHABLE_PANELS then
        elseif winCon == GameModes.WinConditions.NO_MATCHABLE_GARBAGE then
          -- both of these are positive game-ending conditions on the stack level
          -- should rethink these when looking at puzzle vs (if ever)
        end
      end
      if #metCondition == 1 then
        potentialWinners = metCondition
        -- only one winner, we're done
        break
      elseif #metCondition > 1 then
        -- there is a tie in a condition, move on to the next one with only the ones still eligible
        potentialWinners = metCondition
      elseif #metCondition == 0 then
        -- none met the condition, keep going with the current set of potential winners
      end
    end
    winners = potentialWinners
  end

  self.winners = winners

  return winners
end

function Match:debugRollbackAndCaptureState(clockGoal)
  local P1 = self.stacks[1]
  local P2 = self.stacks[2]

  if P1.clock <= clockGoal then
    return
  end

  self.savedStackP1 = P1.rollbackCopies[P1.clock]
  if P2 then
    self.savedStackP2 = P2.rollbackCopies[P2.clock]
  end

  local rollbackResult = P1:rollbackToFrame(clockGoal)
  assert(rollbackResult)
  if P2 and P2.clock > clockGoal then
    rollbackResult = P2:rollbackToFrame(clockGoal)
    assert(rollbackResult)
  end
end

function Match:debugAssertDivergence(stack, savedStack)

  for k,v in pairs(savedStack) do
    if type(v) ~= "table" then
      local v2 = stack[k]
      if v ~= v2 then
        error("Stacks have diverged")
      end
    end
  end

  local savedStackString = Stack.divergenceString(savedStack)
  local localStackString = Stack.divergenceString(stack)

  if savedStackString ~= localStackString then
    error("Stacks have diverged")
  end
end

function Match:debugCheckDivergence()
  if not self.savedStackP1 or self.savedStackP1.clock ~= self.stacks[1].clock then
    return
  end
  self:debugAssertDivergence(self.stacks[1], self.savedStackP1)
  self.savedStackP1 = nil

  if not self.savedStackP2 or self.savedStackP2.clock ~= self.stacks[2].clock then
    return
  end

  self:debugAssertDivergence(self.stacks[2], self.savedStackP2)
  self.savedStackP2 = nil
end

function Match:run()
  if self.isPaused or self:hasEnded() then
    self:runGameOver()
    return
  end

  local startTime = love.timer.getTime()

  local checkRun = {}

  for i, stack in ipairs(self.stacks) do
    checkRun[i] = true

    -- if player.cpu then
    --   player.cpu:run(stack)
    -- end

    if stack and stack.is_local and stack.send_controls and not stack:game_ended() --[[and not self.players[i].cpu]] then
      stack:send_controls()
    end
  end

  local runsSoFar = 0
  while tableUtils.contains(checkRun, true) do
    for i, stack in ipairs(self.stacks) do
      if stack and self:shouldRun(stack, runsSoFar) then
        self:pushGarbageTo(stack)
        stack:run()

        checkRun[i] = true
      else
        checkRun[i] = false
      end
    end

    self:updateClock()

    -- Since the stacks can affect each other, don't save rollback until after all have run
    for i, stack in ipairs(self.stacks) do
      if checkRun[i] then
        self:updateFramesBehind(stack)
        if self:shouldSaveRollback(stack) then
          stack:saveForRollback()
        end
      end
    end

    self:debugCheckDivergence()

    runsSoFar = runsSoFar + 1
  end

  -- for i = 1, #self.players do
  --   local stack = self.players[i].stack
  --   if stack and stack.is_local not stack:game_ended() then
  --     assert(#stack.input_buffer == 0, "Local games should always simulate all inputs")
  --   end
  -- end
  if self:hasEnded() then
    prof.push("Match:handleMatchEnd")
    self:handleMatchEnd()
    prof.pop("Match:handleMatchEnd")
  end

  self:playCountdownSfx()
  self:playTimeLimitDepletingSfx()
  local endTime = love.timer.getTime()
  local timeDifference = endTime - startTime
  self.timeSpentRunning = self.timeSpentRunning + timeDifference
  self.maxTimeSpentRunning = math.max(self.maxTimeSpentRunning, timeDifference)
end

function Match:pushGarbageTo(stack)
  -- check if anyone wants to push garbage into the stack's queue
  for _, st in ipairs(self.stacks) do
    if st.garbageTarget == stack then
      local oldestTransitTime = st.outgoingGarbage:getOldestFinishedTransitTime()
      if oldestTransitTime then
        if stack.clock > oldestTransitTime then
          -- recipient went past the frame it was supposed to receive the garbage -> rollback to that frame
          -- hypothetically, IF the receiving stack's garbage target was different than the sender forcing the rollback here
          --  it may be necessary to perform extra steps to ensure the recipient of the stack getting rolled back is getting correct garbage
          --  which may even include another rollback
          if not self:rollbackToFrame(stack, oldestTransitTime) then
            -- if we can't rollback, it's a desync
            st.tooFarBehindError = true
            self:abort()
          end
        end
        local garbageDelivery = st.outgoingGarbage:popFinishedTransitsAt(stack.clock)
        if garbageDelivery then
          logger.debug("Pushing garbage delivery to incoming garbage queue: " .. table_to_string(garbageDelivery))
          stack.incomingGarbage:pushTable(garbageDelivery)
        end
      end
    end
  end
end

function Match:runGameOver()
  for _, stack in ipairs(self.stacks) do
    stack:runGameOver()
  end
end

function Match:updateFramesBehind(stack)
  local framesBehind = self.clock - stack.clock
  stack.framesBehindArray[self.clock] = framesBehind
  stack.framesBehind = framesBehind
end

function Match:shouldSaveRollback(stack)
  if self.isFromReplay then
    return true
  end

  -- rollback needs to happen if any sender is more than the garbage delay behind is
  for i = 1, #self.stacks do
    if self.stacks[i] ~= stack then
      if self.stacks[i].garbageTarget == stack then
        if self.stacks[i].clock + GARBAGE_DELAY_LAND_TIME <= stack.clock then
          return true
        end
      end
    end
  end

  return false
end

-- attempt to rollback the specified stack to the specified frame
-- return true if successful
-- return false if not
function Match:rollbackToFrame(stack, frame)
  if stack.rollbackCopies[frame] then
    if stack:rollbackToFrame(frame) then
      if self.isFromReplay then
        stack.lastRollbackFrame = -1
      end
      return true
    end
  end

  return false
end

-- rewind is ONLY to be used for replay playback as it relies on all stacks being at the same clock time
-- and also uses slightly different data required only in a both-sides rollback scenario that would never occur for online rollback
function Match:rewindToFrame(frame)
  local failed = false
  for i, stack in ipairs(self.stacks) do
    if not stack:rewindToFrame(frame) then
      failed = true
      break
    end
  end
  if not failed then
    self.clock = frame
    self.ended = false
  end
end

local countdownEnd = consts.COUNTDOWN_START + consts.COUNTDOWN_LENGTH
-- updates the match clock to the clock time of the player furthest into the game
-- also triggers the danger music from time running out if a timeLimit was set
function Match:updateClock()
  for i = 1, #self.players do
    if self.players[i].stack.clock > self.clock then
      self.clock = self.players[i].stack.clock
    end
  end

  if self.panicTickStartTime and self.panicTickStartTime == self.clock then
    self:updateDangerMusic()
  end

  if self.doCountdown and self.clock == countdownEnd then
    self:emitSignal("countdownEnded")
  elseif not self.doCountdown and self.clock == consts.COUNTDOWN_START then
    self:emitSignal("countdownEnded")
  end
end

function Match:getWinningPlayerCharacter()
  local character = consts.RANDOM_CHARACTER_SPECIAL_VALUE
  local maxWins = -1
  for i = 1, #self.players do
    if self.players[i].wins > maxWins then
      character = self.players[i].stack.character
      maxWins = self.players[i].wins
    end
  end

  return characters[character]
end

function Match:playCountdownSfx()
  if self.doCountdown then
    if self.clock < 200 then
      if (self.clock - consts.COUNTDOWN_START) % 60 == 0 then
        if self.clock == countdownEnd then
          SoundController:playSfx(themes[config.theme].sounds.go)
        else
          SoundController:playSfx(themes[config.theme].sounds.countdown)
        end
      end
    end
  end
end

function Match:playTimeLimitDepletingSfx()
  if self.timeLimit then
    -- have to account for countdown
    if self.clock >= self.panicTickStartTime then
      local tickIndex = math.ceil((self.clock - self.panicTickStartTime) / 60)
      if self.panicTicksPlayed[tickIndex] == false then
        SoundController:playSfx(themes[config.theme].sounds.countdown)
        self.panicTicksPlayed[tickIndex] = true
      end
    end
  end
end

function Match:getInfo()
  local info = {}
  info.stackInteraction = self.stackInteraction
  info.timeLimit = self.timeLimit or "none"
  info.doCountdown = tostring(self.doCountdown)
  info.stage = self.stageId or "no stage"
  info.ended = self.ended
  info.stacks = {}
  for i, stack in ipairs(self.stacks) do
    info.stacks[i] = stack:getInfo()
  end

  return info
end

function Match:start()
  -- battle room may add the players in any order
  -- match has to make sure the local player ends up as P1 (left side)
  -- if both are local or both are not, order by playerNumber
  table.sort(self.players, function(a, b)
    if a.isLocal == b.isLocal then
      return a.playerNumber < b.playerNumber
    else
      return a.isLocal
    end
  end)

  for i, player in ipairs(self.players) do
    local stack = player:createStackFromSettings(self, i)
    stack:connectSignal("dangerMusicChanged", self, self.updateDangerMusic)
    self.stacks[#self.stacks + 1] = stack
    stack.do_countdown = self.doCountdown

    if self.replay then
      if self.isFromReplay then
        -- watching a finished replay
        if player.human then
          stack:receiveConfirmedInput(self.replay.players[i].settings.inputs)
        end
        stack.max_runs_per_frame = 1
      elseif not self:hasLocalPlayer() and self.replay.players[i].settings.inputs then
        -- catching up to a match in progress
        stack:receiveConfirmedInput(self.replay.players[i].settings.inputs)
        stack.play_to_end = true
      end
    end

    if self.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
      local attackEngineHost = SimulatedStack({which = #self.stacks + 1, is_local = true, character = CharacterLoader.fullyResolveCharacterSelection()})
      attackEngineHost:addAttackEngine(player.settings.attackEngineSettings)
      attackEngineHost:setGarbageTarget(stack)
      self.stacks[#self.stacks+1] = attackEngineHost
    end
  end

  if self.stackInteraction == GameModes.StackInteractions.SELF then
    for i = 1, #self.players do
      self.players[i].stack:setGarbageTarget(self.players[i].stack)
    end
  elseif self.stackInteraction == GameModes.StackInteractions.VERSUS then
    for i = 1, #self.players do
      for j = 1, #self.players do
        if i ~= j then
          -- once we have more than 2P in a single mode, setGarbageTarget needs to put these into an array
          -- or we rework it anyway for team play
          self.players[i].stack:setGarbageTarget(self.players[j].stack)
        end
      end
    end
  end

  for i, player in ipairs(self.players) do
    if player.settings.puzzleSet then
      -- puzzles are currently set directly on the player's stack
    else
      player.stack:starting_state()
      -- always need clock 0 as a base for rollback
      player.stack:saveForRollback()
    end
  end

  if self.timeLimit then
    self.panicTicksPlayed = {}
    for i = 1, 15 do
      self.panicTicksPlayed[i] = false
    end

    self.panicTickStartTime = (self.timeLimit - 15) * 60
    if self.doCountdown then
      self.panicTickStartTime = self.panicTickStartTime + consts.COUNTDOWN_START + consts.COUNTDOWN_LENGTH
    end
  end

  self.replay = Replay.createNewReplay(self)
end

function Match:setStage(stageId)
  logger.debug("Setting match stage id to " .. (stageId or ""))
  if stageId then
    -- we got one from the server
    self.stageId = StageLoader.fullyResolveStageSelection(stageId)
  elseif #self.players == 1 then
    self.stageId = StageLoader.resolveBundle(self.players[1].settings.selectedStageId)
  else
    self.stageId = StageLoader.fullyResolveStageSelection()
  end
  ModController:loadModFor(stages[self.stageId], self)
end

function Match:generateSeed()
  local seed = 17
  seed = seed * 37 + self.players[1].rating.new
  seed = seed * 37 + self.players[2].rating.new
  seed = seed * 37 + self.players[1].wins
  seed = seed * 37 + self.players[2].wins

  return seed
end

function Match:setSeed(seed)
  if seed then
    self.seed = seed
  elseif self.online and #self.players > 1 then
    self.seed = self:generateSeed()
  else
    -- Use the default random seed set up on match creation
  end
end

-- if there is no local player that means the client is either spectating (or watching a replay)
function Match:hasLocalPlayer()
  for _, player in ipairs(self.players) do
    if player.isLocal then
      return true
    end
  end

  return false
end

function Match.createFromReplay(replay, supportsPause)
  local optionalArgs = {
    timeLimit = replay.gameMode.timeLimit,
    puzzle = replay.gameMode.puzzle,
  }

  local players = {}

  for i = 1, #replay.players do
    if replay.players[i].human then
      players[i] = Player.createFromReplayPlayer(replay.players[i], i)
    else
      players[i] = ChallengeModePlayer.createFromReplayPlayer(replay.players[i], i)
    end
  end

  local match = Match(
    players,
    replay.gameMode.doCountdown,
    replay.gameMode.stackInteraction,
    replay.gameMode.winConditions,
    replay.gameMode.gameOverConditions,
    supportsPause,
    optionalArgs
  )

  -- match.isFromReplay mostly treats the match as if it runs an already finished replay
  -- this is slightly incorrect cause the replay could also be from the server for spectating
  -- as a result it could mess with rollback during spectating
  -- on the other hand, if you experience rollback as the spectator it's almost certain the game will desync for the players
  -- so it probably doesn't matter
  match.isFromReplay = replay.loadedFromFile
  match:setSeed(replay.seed)
  match:setStage(replay.stageId)
  match.engineVersion = replay.engineVersion
  match.replay = replay

  return match
end

function Match:abort()
  self.ended = true
  self.aborted = true
  self:handleMatchEnd()
end

function Match:hasEnded()
  if self.ended then
    return true
  end

  if self.aborted then
    self.ended = true
    return true
  end

  local aliveCount = 0
  local deadCount = 0
  for i = 1, #self.stacks do
    if self.stacks[i]:game_ended() then
      deadCount = deadCount + 1
    else
      aliveCount = aliveCount + 1
    end
  end

  if tableUtils.contains(self.winConditions, GameModes.WinConditions.LAST_ALIVE) then
    if aliveCount == 1 then
      local gameOverClock = 0
      for i = 1, #self.stacks do
        if self.stacks[i].game_over_clock > gameOverClock then
          gameOverClock = self.stacks[i].game_over_clock
        end
      end
      self.gameOverClock = gameOverClock
      -- make sure everyone has run to the currently known game over clock
      -- because if they haven't they might still go gameover before that time
      if tableUtils.trueForAll(self.stacks, function(stack) return stack.clock and stack.clock >= gameOverClock end) then
        self.ended = true
        return true
      end
    end
  end

  if deadCount == #self.stacks then
    -- everyone died, match is over!
    self.ended = true
    return true
  end

  if self.timeLimit then
    if tableUtils.trueForAll(self.stacks, function(stack) return stack.game_stopwatch and stack.game_stopwatch >= self.timeLimit * 60 end) then
      self.ended = true
      return true
    end
  end

  if self:isIrrecoverablyDesynced() then
    self.ended = true
    self.aborted = true
    self.desyncError = true
    return true
  end

  return false
end

function Match:handleMatchEnd()
  self:checkAborted()

  if self.aborted then
    self.winners = {}
  else
    local winners = self:getWinners()
    -- determine result
    -- play win sfx
    for i = 1, #winners do
      characters[winners[i].stack.character]:playWinSfx()
    end
  end

  -- this prepares everything about the replay except the save location
  Replay.finalizeReplay(self, self.replay)

  -- execute callbacks
  self:emitSignal("matchEnded", self)
end

function Match:isIrrecoverablyDesynced()
  for _, stack in ipairs(self.stacks) do
    if stack.garbageTarget and stack.clock + MAX_LAG < stack.garbageTarget.clock then
      stack.tooFarBehindError = true
      return true
    end
  end

  return false
end

-- a local function to avoid creating a closure every frame
local checkGameEnded = function(stack)
  return stack:game_ended()
end

function Match:checkAborted()
  -- the aborted flag may get set if the game is aborted through outside causes (usually network)
  -- this function checks if the match got aborted through inside causes (local player abort or local desync)
  if not self.aborted then
    if self:isIrrecoverablyDesynced() then
      -- someone got a desync error, this definitely died
      self.aborted = true
      self.winners = {}
    elseif tableUtils.contains(self.winConditions, GameModes.WinConditions.LAST_ALIVE) then
      local alive = 0
      for i = 1, #self.players do
        if not self.players[i].stack:game_ended() then
          alive = alive + 1
        end
        -- if there is more than 1 alive with a last alive win condition, this must have been aborted
        if alive > 1 then
          self.aborted = true
          self.winners = {}
          break
        end
      end
    else
      -- if this is not last alive and no desync that means we expect EVERY stack to be game over
      if not tableUtils.trueForAll(self.stacks, checkGameEnded) then
        -- someone didn't lose so this got aborted (e.g. through a pause -> leave)
        self.aborted = true
        self.winners = {}
      end
    end
  end

  return self.aborted
end

function Match:togglePause()
  self.isPaused = not self.isPaused
end

-- returns true if the stack should run once more during the current match:run
-- returns false otherwise
function Match:shouldRun(stack, runsSoFar)
  -- check the match specific conditions in match
  if not stack:game_ended() then
    if self.timeLimit then
      if stack.game_stopwatch and stack.game_stopwatch >= self.timeLimit * 60 then
        -- the stack should only run 1 frame beyond the time limit (excluding countdown)
        return false
      end
    else
      -- gameOverClock is set in Match:hasEnded when there is only 1 alive in LAST_ALIVE modes
      if self.gameOverClock and self.gameOverClock < stack.clock then
        return false
      end
    end
  end

  -- In debug mode allow non-local player 2 to fall a certain number of frames behind
  if config.debug_mode and not stack.is_local and config.debug_vsFramesBehind and config.debug_vsFramesBehind > 0 and stack.which == 2 then
    -- Only stay behind if the game isn't over for the local player (=garbageTarget) yet
    if stack.garbageTarget and stack.garbageTarget.game_ended and stack.garbageTarget:game_ended() == false then
      if stack.clock + config.debug_vsFramesBehind >= stack.garbageTarget.clock then
        return false
      end
    end
  end

  -- and then the stack specific conditions in stack
  return stack:shouldRun(runsSoFar)
end

function Match:updateDangerMusic()
  local dangerMusic
  if self.panicTickStartTime == nil or self.clock < self.panicTickStartTime then
    dangerMusic = tableUtils.trueForAny(self.stacks, function(s) return s.danger_music end)
  else
    dangerMusic = true
  end

  if dangerMusic ~= self.currentMusicIsDanger then
    self:emitSignal("dangerMusicChanged", dangerMusic)
    self.currentMusicIsDanger = dangerMusic
  end
end

function Match:setCountdown(doCountdown)
  self.doCountdown = doCountdown
end

return Match