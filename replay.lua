

-- A replay is a particular recording of a play of the game. Temporarily this is just helper methods.
Replay =
class(
    function(self)
    end
  )

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
  GAME.match.seed = replayDetails.seed
  GAME.match.isFromReplay = true

  if replay.vs then
    assert(replayDetails.P1_level, "invalid replay: player 1 level missing from vs replay")
    local inputType1 = (replayDetails.P1_inputMethod) or "controller"
    P1 = Stack{which=1, match=GAME.match, is_local=false, level=replayDetails.P1_level, character=replayDetails.P1_char, inputMethod=inputType1}

    if replayDetails.I and string.len(replayDetails.I)> 0 then
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

return Replay