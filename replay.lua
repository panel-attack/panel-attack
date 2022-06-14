

-- A replay is a particular recording of a play of the game. Temporarily this is just helper methods.
Replay =
class(
    function(self)
    end
  )
  

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

    -- Old versions saved replays with extra data, prefer vs and endless in that case
    if replay.vs and replay.endless then
        replay.endless = nil
    end
    if replay.vs and replay.puzzle then
        replay.puzzle = nil
    end
    if replay.endless and replay.puzzle then
        replay.puzzle = nil
    end

    -- Fix old replays that were a table instead of a string
    if type(replay.in_buf) == "table" then
        replay.in_buf = table.concat(replay.in_buf)
    end
    return true
end

function Replay.loadFromFile(replay)
    if replay.vs then
        replay = replay.vs

        GAME.battleRoom = BattleRoom()
        GAME.match = Match("vs", GAME.battleRoom)
        GAME.match.seed = replay.seed or 0
        GAME.match.isFromReplay = true
        P1 = Stack{which=1, match=GAME.match, is_local=false, level=replay.P1_level or 5, character=replay.P1_char}

        if replay.I and string.len(replay.I) > 0 then
        P2 = Stack{which=2, match=GAME.match, is_local=false, level=replay.P2_level or 5, character=replay.P2_char}
        
        P1:set_garbage_target(P2)
        P2:set_garbage_target(P1)
        P2:moveForPlayerNumber(2)

        if replay.P1_win_count then
            GAME.match.battleRoom.playerWinCounts[1] = replay.P1_win_count
            GAME.match.battleRoom.playerWinCounts[2] = replay.P2_win_count
        end

        else
        P1:set_garbage_target(P1)
        end

        GAME.battleRoom.playerNames[1] = replay.P1_name or loc("player_n", "1")
        if P2 then
        GAME.battleRoom.playerNames[2] = replay.P2_name or loc("player_n", "2")
        end

        if replay.ranked then
        match_type = "Ranked"
        else
        match_type = "Casual"
        end

    elseif replay.endless or replay.time then
        if replay.time then
        GAME.match = Match("time")
        else
        GAME.match = Match("endless")
        end
        
        replay = replay.endless or replay.time

        GAME.match.seed = replay.seed or 0
        
        if replay.pan_buf then
        replay.P = replay.pan_buf -- support old versions
        end

        P1 = Stack{which=1, match=GAME.match, is_local=false, speed=replay.speed, difficulty=replay.difficulty}
        GAME.match.P1 = P1
        P1:wait_for_random_character()
    end

    P1:receiveConfirmedInput(uncompress_input_string(replay.in_buf))
    GAME.match.P1 = P1
    P1.do_countdown = replay.do_countdown or false
    P1.max_runs_per_frame = 1
    P1.cur_wait_time = replay.cur_wait_time or default_input_repeat_delay

    refresh_based_on_own_mods(P1)
    character_loader_load(P1.character)

    if P2 then
        P2:receiveConfirmedInput(uncompress_input_string(replay.I))

        GAME.match.P2 = P2
        P2.do_countdown = replay.do_countdown or false
        P2.max_runs_per_frame = 1
        P2.cur_wait_time = replay.P2_cur_wait_time or default_input_repeat_delay
        refresh_based_on_own_mods(P2, true)
        character_loader_load(P2.character)
    end
    character_loader_wait()

    P1:starting_state()

    if P2 then
        P2:starting_state()
    end
end