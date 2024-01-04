local logger = require("logger")
local tableUtils = require("tableUtils")
local GameModes = require("GameModes")
local sceneManager = require("scenes.sceneManager")
local Player = require("Player")
local Replay = require("replay")
local Signal = require("helpers.signal")
local SimulatedStack = require("SimulatedStack")

-- A match is a particular instance of the game, for example 1 time attack round, or 1 vs match
Match =
  class(
  function(self, players, doCountdown, stackInteraction, winConditions, gameOverConditions, supportsPause, optionalArgs)
    self.players = {}
    self.stacks = {}
    -- holds detached attackEngines, meaning attack engines that only deal; indexed via the player they're targeting
    self.attackEngines = {}
    self.P1 = nil
    self.P2 = nil
    self.engineVersion = VERSION

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
      -- refers to the health portion of a challenge mode stage
      -- maybe this isn't right here and battleRoom should just pass Health in as a Player substitute
      self.health = optionalArgs.health
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

    self.time_quads = {}

    Signal.addSignal(self, "onMatchEnded")
  end
)

require("match_graphics")

-- Should be called prior to clearing the match.
-- Consider recycling any memory that might leave around a lot of garbage.
-- Note: You can just leave the variables to clear / garbage collect on their own if they aren't large.
function Match:deinit()
  if self.P1 then
    self.P1:deinit()
  end
  if self.P2 then
    self.P2:deinit()
  end
  for _, quad in ipairs(self.time_quads) do
    GraphicsUtil:releaseQuad(quad)
  end
  stop_the_music()
end

function Match:addPlayer(player)
  self.players[#self.players+1] = player
end

-- returns the players that won the match in a table
-- returns a single winner if there was a clear winner
-- returns multiple winners if there was a tie (or the game mode had no win conditions)
-- returns an empty table if there was no winner due to the game not finishing / getting aborted
function Match:getWinners()
  if self.winners then
    return self.winners
  end

  -- game over is handled on the stack level and results in stack.game_over = true
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
          if not potentialWinner.stack.game_over then
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
  local P1 = self.P1
  local P2 = self.P2

  if P1.clock <= clockGoal then
    return
  end

  self.savedStackP1 = P1.prev_states[P1.clock]
  if P2 then
    self.savedStackP2 = P2.prev_states[P2.clock]
  end

  local rollbackResult = P1:rollbackToFrame(clockGoal)
  assert(rollbackResult)
  if P2 then
    rollbackResult = P2:rollbackToFrame(clockGoal)
    assert(rollbackResult)
  end
end

function Match:warningOccurred()
  local P1 = self.P1
  local P2 = self.P2
  
  if (P1 and tableUtils.length(P1.warningsTriggered) > 0) or (P2 and tableUtils.length(P2.warningsTriggered) > 0) then
    return true
  end
  return false
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

  if not self.savedStackP1 or self.savedStackP1.clock ~= self.P1.clock then
    return
  end
  self:debugAssertDivergence(self.P1, self.savedStackP1)
  self.savedStackP1 = nil

  if not self.savedStackP2 or self.savedStackP2.clock ~= self.P2.clock then
    return
  end

  self:debugAssertDivergence(self.P2, self.savedStackP2)
  self.savedStackP2 = nil
end

function Match:run()
  if self.isPaused or self:hasEnded() then
    return
  end

  local startTime = love.timer.getTime()

  local checkRun = {}

  for i, player in ipairs(self.players) do
    local stack = player.stack
    checkRun[i] = true

    -- if player.cpu then
    --   player.cpu:run(stack)
    -- end

    if stack and stack.is_local and not stack.game_over --[[and not self.players[i].cpu]] then
      stack:send_controls()
    end
  end

  local runsSoFar = 0
  while tableUtils.trueForAny(checkRun, function(b) return b end) do
    for i, player in ipairs(self.players) do
      local stack = player.stack
      if stack and self:shouldRun(stack, runsSoFar) then
        stack:run()
        if self.attackEngines[player] then
          self.attackEngines[player]:run()
        end
        checkRun[i] = true
      else
        checkRun[i] = false
      end
    end

    self:updateClock()

    -- Since the stacks can affect each other, don't save rollback until after all have run
    for i, player in ipairs(self.players) do
      if checkRun[i] then
        local stack = player.stack
        stack:updateFramesBehind()
        stack:saveForRollback()
      end
    end

    --   if self.simulatedOpponent then
    --     self.simulatedOpponent:run()
    --   end

    self:debugCheckDivergence()

    runsSoFar = runsSoFar + 1
  end

  -- for i = 1, #self.players do
  --   local stack = self.players[i].stack
  --   if stack and stack.is_local not stack.game_over then
  --     assert(#stack.input_buffer == 0, "Local games should always simulate all inputs")
  --   end
  -- end

  if self:hasEnded() then
    self:handleMatchEnd()
  end

  self:updateMusic()
  self:playCountdownSfx()
  self:playTimeLimitDepletingSfx()
  local endTime = love.timer.getTime()
  local timeDifference = endTime - startTime
  self.timeSpentRunning = self.timeSpentRunning + timeDifference
  self.maxTimeSpentRunning = math.max(self.maxTimeSpentRunning, timeDifference)
end

-- updates the match clock to the clock time of the player furthest into the game
function Match:updateClock()
  for i = 1, #self.players do
    if self.players[i].stack.clock > self.clock then
      self.clock = self.players[i].stack.clock
    end
  end
end

function Match:getWinningPlayerCharacter()
  local character = random_character_special_value
  local maxWins = -1
  for i = 1, #self.players do
    if self.players[i].wins > maxWins then
      character = self.players[i].stack.character
      maxWins = self.players[i].wins
    end
  end

  return characters[character]
end

function Match:shouldChangeMusic()
  if GAME.muteSoundEffects then
    return false
  end

  if self.isPaused then
    return false
  end

  -- someone is still catching up
  if tableUtils.trueForAny(self.players, function(p) return p.stack.play_to_end end) then
    return false
  end

  -- we don't have to cover the rollback case because music updates are only called once per match:run()
  -- meaning any stack that did a rollback should have caught up again by the time it is called
  -- if tableUtils.trueForAny(self.players, function(p) return p:behindRollback() end) then
  --   return false
  -- end

  -- music waits until countdown is over
  if self.doCountdown and self.clock < 180 then
    return false
  end

  if self.ended then
    return false
  end

  return true
end

function Match:updateMusic()
  -- Update Music
  if self.musicSource and self:shouldChangeMusic() then
    -- danger music is played the moment one player is in danger
    -- but only if we actually have danger music
    local wantsDangerMusic = self.musicSource.musics["danger_music"] and tableUtils.trueForAny(self.players, function(p) return p.stack.danger_music end)

    if self.timeLimit and not wantsDangerMusic then
      -- danger music is played during panic time even if none is in danger
      wantsDangerMusic = self.musicSource.musics["danger_music"] and self.clock >= self.panicTickStartTime
    end

    if self.musicSource.music_style == "dynamic" then
      local fadeLength = 60
      if not self.fade_music_clock then
        self.fade_music_clock = fadeLength -- start fully faded in
        self.currentMusicIsDanger = false
      end

      local normalMusic = {self.musicSource.musics["normal_music"], self.musicSource.musics["normal_music_start"]}
      local dangerMusic = {self.musicSource.musics["danger_music"], self.musicSource.musics["danger_music_start"]}

      if #currently_playing_tracks == 0 then
        find_and_add_music(self.musicSource.musics, "normal_music")
        find_and_add_music(self.musicSource.musics, "danger_music")
      end

      -- Do we need to switch music?
      if self.currentMusicIsDanger ~= wantsDangerMusic then
        self.currentMusicIsDanger = not self.currentMusicIsDanger

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
        if (self.currentMusicIsDanger == false or #currently_playing_tracks == 0) then
          stop_the_music()
          find_and_add_music(self.musicSource.musics, "danger_music")
          self.currentMusicIsDanger = true
        end
      else --we should be playing normal_music or normal_music_start
        if (self.currentMusicIsDanger or #currently_playing_tracks == 0) and self.musicSource.musics["normal_music"] then
          stop_the_music()
          find_and_add_music(self.musicSource.musics, "normal_music")
          self.currentMusicIsDanger = false
        end
      end
    end
  end
end

function Match:playCountdownSfx()
  if not GAME.muteSoundEffects and self.doCountdown then
    if self.clock < 200 then
      local tickIndex = math.floor(self.clock / 60)
      if not self.ticksPlayed[tickIndex] then
        if tickIndex < 3 then
          themes[config.theme].sounds.countdown:stop()
          themes[config.theme].sounds.countdown:play()
        else
          themes[config.theme].sounds.go:stop()
          themes[config.theme].sounds.go:play()
        end
        self.ticksPlayed[tickIndex] = true
      end
    end
  end
end

function Match:playTimeLimitDepletingSfx()
  if not GAME.muteSoundEffects and self.timeLimit then
    -- have to account for countdown
    if self.clock >= self.panicTickStartTime then
      local tickIndex = math.ceil((self.clock - self.panicTickStartTime) / 60)
      if self.panicTicksPlayed[tickIndex] == false then
        themes[config.theme].sounds.countdown:stop()
        themes[config.theme].sounds.countdown:play()
        self.panicTicksPlayed[tickIndex] = true
      end
    end
  end
end

function Match:getInfo()
  local info = {}
  info.stackInteraction = self.stackInteraction
  info.timeLimit = self.timeLimit
  info.doCountdown = self.doCountdown
  info.stage = self.stageId
  info.stacks = {}
  if self.P1 then
    info.stacks[1] = self.P1:getInfo()
  end
  if self.P2 then
    info.stacks[2] = self.P2:getInfo()
  end

  return info
end

function Match:waitForAssets()
  for i = 1, #self.players do
    local playerSettings = self.players[i].settings
    playerSettings.characterId = CharacterLoader.resolveCharacterSelection(playerSettings.characterId)
    CharacterLoader.load(playerSettings.characterId)
    CharacterLoader.wait()
  end

  self.stageId = StageLoader.resolveStageSelection(self.stageId)
  current_stage = self.stageId
  StageLoader.load(self.stageId)
  StageLoader.wait()
end

function Match:start()
  self:waitForAssets()

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
    self.stacks[#self.stacks + 1] = stack
    stack.do_countdown = self.doCountdown

    if self.replay then
      if self.isFromReplay then
        -- watching a finished replay
        stack:receiveConfirmedInput(self.replay.players[i].settings.inputs)
        stack.max_runs_per_frame = 1
      elseif not self:hasLocalPlayer() and self.replay.players[i].settings.inputs then
        -- catching up to a match in progress
        stack:receiveConfirmedInput(self.replay.players[i].settings.inputs)
        stack.play_to_end = true
      end
    end

    if self.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
      local attackEngineHost = SimulatedStack(500, 200, -1)
      local attackEngine = attackEngineHost:addAttackEngine(player.settings.attackEngineSettings.attackSettings)
      attackEngine:setGarbageTarget(stack)
      self.attackEngines[player] = attackEngineHost
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
          -- once we have more than 2P in a single mode, setGarbageTarget/setOpponent needs to put these into an array
          -- or we rework it anyway for team play
          self.players[i].stack:setGarbageTarget(self.players[j].stack)
          self.players[i].stack:setOpponent(self.players[j].stack)
        end
      end
    end
  end

  for i = 1, #self.players do
    local pString = "P" .. tostring(i)
    self[pString] = self.players[i].stack
    if self.puzzle then
      self.players[i].stack:set_puzzle_state(self.puzzle)
    else
      self.players[i].stack:starting_state()
      -- always need clock 0 as a base for rollback
      self.players[i].stack:saveForRollback()
    end
  end

  if self.doCountdown then
    self.ticksPlayed = { [0] = false, false, false, false }
  end

  if self.timeLimit then
    self.panicTicksPlayed = {}
    for i = 1, 15 do
      self.panicTicksPlayed[i] = false
    end

    self.panicTickStartTime = (self.timeLimit - 15) * 60
    if self.doCountdown then
      self.panicTickStartTime = self.panicTickStartTime + 180
    end
  end

  self.musicSource = self:getMusicSource()

  self.replay = Replay.createNewReplay(self)
end

-- gets the stage or character the music is used of
-- returns the character or stage or, in case none of them has music, nil
function Match:getMusicSource()
  local character = self:getWinningPlayerCharacter()
  local stageHasMusic = current_stage and stages[current_stage].musics and stages[current_stage].musics["normal_music"]
  local characterHasMusic = character and character.musics and character.musics["normal_music"]
  if not stageHasMusic and not characterHasMusic then
    -- no music loaded, early return
    return nil
  elseif ((current_use_music_from == "stage") and stageHasMusic) or not characterHasMusic then
    return stages[self.stageId]
  else --if characterHasMusic then
    return character
  end
end

function Match:setStage(stageId)
  if stageId then
    -- we got one from the server
    self.stageId = StageLoader.resolveStageSelection(stageId)
  elseif #self.players == 1 then
    if self.players[1].settings.stageId == random_stage_special_value then
      self.stageId = StageLoader.resolveStageSelection(tableUtils.getRandomElement(stages_ids_for_current_theme))
    else
      self.stageId = self.players[1].settings.stageId
    end
  else
    self.stageId = StageLoader.resolveStageSelection(tableUtils.getRandomElement(stages_ids_for_current_theme))
  end
  StageLoader.load(self.stageId)
  -- TODO check if we can unglobalize that
  current_stage = self.stageId
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

-- list of spectators
-- parked here to get it out of network.network.lua
function spectator_list_string(list)
  local str = ""
  for k, v in ipairs(list) do
    str = str .. v
    if k < #list then
      str = str .. "\n"
    end
  end
  if str ~= "" then
    str = loc("pl_spectators") .. "\n" .. str
  end
  return str
end

-- if there is no local player that means the client is either spectating (or watching a replay)
function Match:hasLocalPlayer()
  return tableUtils.trueForAny(self.players, function(player) return player.isLocal end)
end

function Match.createFromReplay(replay, supportsPause)
  local optionalArgs = {
    timeLimit = replay.gameMode.timeLimit,
    puzzle = replay.gameMode.puzzle,
  }

  local players = {}

  for i = 1, #replay.players do
    players[i] = Player.createFromReplayPlayer(replay.players[i], i)
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
  for i = 1, #self.players do
    if self.players[i].stack.game_over then
      deadCount = deadCount + 1
    else
      aliveCount = aliveCount + 1
    end
  end

  if tableUtils.contains(self.winConditions, GameModes.WinConditions.LAST_ALIVE) then
    if aliveCount == 1 then
      local gameOverClock = 0
      for i = 1, #self.players do
        if self.players[i].stack.game_over_clock > gameOverClock then
          gameOverClock = self.players[i].stack.game_over_clock
        end
      end
      self.gameOverClock = gameOverClock
      -- make sure everyone has run to the currently known game over clock
      -- because if they haven't they might still go gameover before that time
      if tableUtils.trueForAll(self.players, function(p) return p.stack.clock and p.stack.clock >= gameOverClock end) then
        self.ended = true
        return true
      end
    end
  end

  if deadCount == #self.players then
    -- everyone died, match is over!
    self.ended = true
    return true
  end

  if self.timeLimit then
    if tableUtils.trueForAll(self.players, function(p) return p.stack.game_stopwatch and p.stack.game_stopwatch > TIME_ATTACK_TIME * 60 end) then
      self.ended = true
      return true
    end
  end

  if tableUtils.trueForAny(self.players, function(p) return p.stack.tooFarBehindError end) then
    self.ended = true
    self.aborted = true
    self.desyncError = true
    return true
  end

  return false
end

function Match:handleMatchEnd()
  self:checkAborted()
  -- this prepares everything about the replay except the save location
  Replay.finalizeReplay(self, self.replay)

  if not self.aborted then
    local winners = self:getWinners()
    -- determine result
    -- play win sfx
    for i = 1, #winners do
      winners[i].stack:pick_win_sfx():play()
    end
    if #winners == 1 then
      -- ideally this would be public player id
      self.replay.winnerIndex = tableUtils.indexOf(self.players, function(p) return p.name == winners[1].name end)
    end
  end

  -- execute callbacks
  self:onMatchEnded()
end

function Match:checkAborted()
  -- the aborted flag may get set if the game is aborted through outside causes (usually network)
  -- this function checks if the match got aborted through inside causes (local player abort or local desync)
  if not self.aborted then
    if tableUtils.trueForAny(self.players, function(p) return p.stack.tooFarBehindError end) then
      -- someone got a desync error, this definitely died
      self.aborted = true
      self.winners = {}
    elseif tableUtils.contains(self.winConditions, GameModes.WinConditions.LAST_ALIVE) then
      local alive = 0
      for i = 1, #self.players do
        if not self.players[i].stack.game_over then
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
      if tableUtils.trueForAny(self.players, function(p) return not p.stack.game_over end) then
        -- someone didn't game_over so this got aborted (e.g. through a pause -> leave)
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
      if stack.game_stopwatch > self.timeLimit * 60 then
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

  -- and then the stack specific conditions in stack
  return stack:shouldRun(runsSoFar)
end