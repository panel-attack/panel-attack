local utf8 = require("utf8Additions")
local logger = require("logger")

-- A replay is a particular recording of a play of the game. Temporarily this is just helper methods.
Replay =
class(
    function(self)
    end
  )

function Replay.createNewReplay(match)
  local mode = match.mode
  local result = {}
  result.engineVersion = VERSION

  result[mode] = {}
  local modeReplay = result[mode]

  modeReplay.seed = match.seed

  if mode == "endless" or mode == "time" then
    modeReplay.do_countdown = match.P1.do_countdown or false
    modeReplay.speed = match.P1.speed
    modeReplay.difficulty = match.P1.difficulty
    modeReplay.cur_wait_time = match.P1.cur_wait_time or default_input_repeat_delay
    modeReplay.in_buf = ""
    modeReplay.inputMethod = match.P1.inputMethod
  elseif mode == "vs" then
    modeReplay.P = ""
    modeReplay.O = ""
    modeReplay.I = ""
    modeReplay.Q = ""
    modeReplay.in_buf = ""
    modeReplay.P1_level = match.P1.level
    modeReplay.P1_inputMethod = match.P1.inputMethod
    modeReplay.P1_name = GAME.battleRoom.playerNames[1]
    modeReplay.P1_char = match.P1.character
    modeReplay.P1_char = match.P1.character
    modeReplay.P1_cur_wait_time = match.P1.cur_wait_time
    modeReplay.do_countdown = true
    if match.P2 then
      modeReplay.P2_level = match.P2.level
      modeReplay.P2_inputMethod = match.P2.inputMethod
      modeReplay.P2_name = GAME.battleRoom.playerNames[2]
      modeReplay.P2_char = match.P2.character
      modeReplay.P2_cur_wait_time = match.P2.cur_wait_time

      modeReplay.P1_win_count = GAME.match.battleRoom.playerWinCounts[match.P1.player_number]
      modeReplay.P2_win_count = GAME.match.battleRoom.playerWinCounts[match.P2.player_number]
    end
  end
  return result
end

function Replay.replayCanBeViewed(replay)
  if replay.engineVersion >= VERSION_MIN_VIEW and replay.engineVersion <= VERSION then
    if not replay.puzzle then
      return true
    end
  end

  return false
end

function Replay.loadFromPath(path)
    local file, error_msg = love.filesystem.read(path)

    if file == nil then
        --print(loc("rp_browser_error_loading", error_msg))
        return false
    end

    replay = {}
    replay = json.decode(file)
    if not replay.engineVersion then
        replay.engineVersion = "046"
    end

    return true
end

function Replay.loadFromFile(replay)
  assert(replay ~= nil)
  local replayDetails
  if replay.vs then
    GAME.battleRoom = BattleRoom()
    GAME.match = Match("vs", GAME.battleRoom)
    replayDetails = replay.vs
  elseif replay.endless or replay.time then
    if replay.time then
      GAME.match = Match("time")
    else
      GAME.match = Match("endless")
    end
    replayDetails = replay.endless or replay.time
  end

  assert(replayDetails.seed, "invalid replay: seed must be set")
  GAME.match.engineVersion = replay.engineVersion
  GAME.match.seed = replayDetails.seed
  GAME.match.isFromReplay = true

  if replay.vs then
    assert(replayDetails.P1_level, "invalid replay: player 1 level missing from vs replay")
    local inputType1 = (replayDetails.P1_inputMethod) or "controller"
    P1 = Stack{which=1, match=GAME.match, is_local=false, level=replayDetails.P1_level, character=replayDetails.P1_char, inputMethod=inputType1}

    if replayDetails.I and utf8.len(replayDetails.I)> 0 then
      assert(replayDetails.P2_level, "invalid replay: player 1 level missing from vs replay")
      local inputType2 = (replayDetails.P2_inputMethod) or "controller"
      P2 = Stack{which=2, match=GAME.match, is_local=false, level=replayDetails.P2_level, character=replayDetails.P2_char, inputMethod=inputType2}
      
      P1:set_garbage_target(P2)
      P2:set_garbage_target(P1)
      P2:moveForPlayerNumber(2)

      if replayDetails.P1_win_count then
        GAME.match.battleRoom.playerWinCounts[1] = replayDetails.P1_win_count
        GAME.match.battleRoom.playerWinCounts[2] = replayDetails.P2_win_count
      end
    else
      P1:set_garbage_target(P1)
    end

    GAME.battleRoom.playerNames[1] = replayDetails.P1_name or loc("player_n", "1")
    if P2 then
      GAME.battleRoom.playerNames[2] = replayDetails.P2_name or loc("player_n", "2")
    end

    if replayDetails.ranked then
      match_type = "Ranked"
    else
      match_type = "Casual"
    end

  elseif replay.endless or replay.time then
    local inputMethod = (replayDetails.inputMethod) or "controller"
    P1 = Stack{which=1, match=GAME.match, is_local=false, speed=replayDetails.speed, difficulty=replayDetails.difficulty, inputMethod=inputMethod}
    GAME.match.P1 = P1
    P1:wait_for_random_character()
  end

  P1:receiveConfirmedInput(uncompress_input_string(replayDetails.in_buf))
  GAME.match.P1 = P1
  P1.do_countdown = replayDetails.do_countdown or false
  P1.max_runs_per_frame = 1
  P1.cur_wait_time = replayDetails.cur_wait_time or default_input_repeat_delay

  refreshBasedOnOwnMods(P1)

  if P2 then
    P2:receiveConfirmedInput(uncompress_input_string(replayDetails.I))

    GAME.match.P2 = P2
    P2.do_countdown = replayDetails.do_countdown or false
    P2.max_runs_per_frame = 1
    P2.cur_wait_time = replayDetails.P2_cur_wait_time or default_input_repeat_delay
    refreshBasedOnOwnMods(P2)
  end
  character_loader_wait()

  P1:starting_state()

  if P2 then
    P2:starting_state()
  end
end


local function addReplayStatisticsToReplay(match, replay)
  local r = replay[match.mode]
  r.duration = match:gameEndedClockTime()
  if match.mode == "vs" and match.P2 then
    r.match_type = match_type
    local p1GameResult = match.P1:gameResult()
    if p1GameResult == 1 then
      r.winner = match.P1.which
    elseif p1GameResult == -1 then
      r.winner = match.P2.which
    elseif p1GameResult == 0 then
      r.winner = 0
    end
  end
  r.playerStats = {}
  
  if match.P1 then
    r.playerStats[match.P1.which] = {}
    r.playerStats[match.P1.which].number = match.P1.which
    r.playerStats[match.P1.which] = match.P1.analytic.data
    r.playerStats[match.P1.which].score = match.P1.score
    if match.mode == "vs" and match.room_ratings then
      r.playerStats[match.P1.which].rating = match.room_ratings[match.P1.which]
    end
  end

  if match.P2 then
    r.playerStats[P2.which] = {}
    r.playerStats[P2.which].number = P2.which
    r.playerStats[P2.which] = P2.analytic.data
    r.playerStats[P2.which].score = P2.score
    if match.mode == "vs" and match.room_ratings then
      r.playerStats[P2.which].rating = match.room_ratings[P2.which]
    end
  end

  return replay
end

function Replay.finalizeAndWriteReplay(extraPath, extraFilename, match, replay)
  Replay.finalizeReplay(match, replay)
  local path, filename = Replay.finalReplayFilename(extraPath, extraFilename)
  local replayJSON = json.encode(replay)
  Replay.write_replay_file(path, filename, replayJSON)
end

function Replay.finalReplayFilename(extraPath, extraFilename)
  local now = os.date("*t", to_UTC(os.time()))
  local sep = "/"
  local path = "replays" .. sep .. "v" .. VERSION .. sep .. string.format("%04d" .. sep .. "%02d" .. sep .. "%02d", now.year, now.month, now.day)
  if extraPath then
    path = path .. sep .. extraPath
  end
  local filename = "v" .. VERSION .. "-" .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)
  if extraFilename then
    filename = filename .. "-" .. extraFilename
  end
  filename = filename .. ".json"
  logger.debug("saving replay as " .. path .. sep .. filename)
  return path, filename
end

function Replay.finalizeReplay(match, replay)
  replay = addReplayStatisticsToReplay(match, replay)
  replay[match.mode].in_buf = table.concat(match.P1.confirmedInput)
  replay[match.mode].stage = current_stage
  if P2 then
    replay[match.mode].I = table.concat(P2.confirmedInput)
  end
  Replay.compressReplay(replay)
end

function Replay.finalizeAndWriteVsReplay(battleRoom, outcome_claim, incompleteGame, match, replay)

  incompleteGame = incompleteGame or false
  
  local extraPath, extraFilename = "", ""

  if match:warningOccurred() then
    extraFilename = extraFilename .. "-WARNING-OCCURRED"
  end

  if P2 then
    local rep_a_name, rep_b_name = battleRoom.playerNames[1], battleRoom.playerNames[2]
    --sort player names alphabetically for folder name so we don't have a folder "a-vs-b" and also "b-vs-a"
    if rep_b_name < rep_a_name then
      extraPath = rep_b_name .. "-vs-" .. rep_a_name
    else
      extraPath = rep_a_name .. "-vs-" .. rep_b_name
    end
    extraFilename = extraFilename .. rep_a_name .. "-L" .. P1.level .. "-vs-" .. rep_b_name .. "-L" .. P2.level
    if match_type and match_type ~= "" then
      extraFilename = extraFilename .. "-" .. match_type
    end
    if incompleteGame then
      extraFilename = extraFilename .. "-INCOMPLETE"
    else
      if outcome_claim == 1 or outcome_claim == 2 then
        extraFilename = extraFilename .. "-P" .. outcome_claim .. "wins"
      elseif outcome_claim == 0 then
        extraFilename = extraFilename .. "-draw"
      end
    end
  else -- vs Self
    extraPath = "Vs Self"
    extraFilename = extraFilename .. "vsSelf-" .. "L" .. P1.level
  end

  Replay.finalizeAndWriteReplay(extraPath, extraFilename, match, replay)
end

function Replay.compressReplay(replay)
  if replay.puzzle then
    replay.puzzle.in_buf = compress_input_string(replay.puzzle.in_buf)
    logger.debug("Compressed puzzle in_buf")
    logger.debug(replay.puzzle.in_buf)
  end
  if replay.endless then
    replay.endless.in_buf = compress_input_string(replay.endless.in_buf)
    logger.debug("Compressed endless in_buf")
    logger.debug(replay.endless.in_buf)
  end
  if replay.vs then
    replay.vs.I = compress_input_string(replay.vs.I)
    replay.vs.in_buf = compress_input_string(replay.vs.in_buf)
    logger.debug("Compressed vs I/in_buf")
  end
end

-- writes a replay file of the given path and filename
function Replay.write_replay_file(path, filename, replayJSON)
  assert(path ~= nil)
  assert(filename ~= nil)
  assert(replayJSON ~= nil)
  pcall(
    function()
      love.filesystem.createDirectory(path)
      local file = love.filesystem.newFile(path .. "/" .. filename)
      set_replay_browser_path(path)
      file:open("w")
      file:write(replayJSON)
      file:close()
    end
  )
end

return Replay