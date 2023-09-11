local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local class = require("class")
local Replay = require("Replay")
local logger = require("logger")

--@module puzzleGame
-- Scene for a puzzle mode instance of the game
local OnlineVsGame = class(
  function (self, sceneParams)    
    self:load(sceneParams)
  end,
  GameBase
)

OnlineVsGame.name = "OnlineVsGame"
sceneManager:addScene(OnlineVsGame)

-- Use the seed the server gives us if it makes one, else generate a basic one off data both clients have.
function OnlineVsGame:getSeed(msg)
  local seed
  if msg.seed or (replay_of_match_so_far and replay_of_match_so_far.vs and replay_of_match_so_far.vs.seed) then
    seed = msg.seed or (replay_of_match_so_far and replay_of_match_so_far.vs and replay_of_match_so_far.vs.seed)
  else
    seed = 17
    seed = seed * 37 + self.currentRoomRatings[1].new;
    seed = seed * 37 + self.currentRoomRatings[2].new;
    seed = seed * 37 + GAME.battleRoom.playerWinCounts[1];
    seed = seed * 37 + GAME.battleRoom.playerWinCounts[2];
  end

  return seed
end

function OnlineVsGame:customLoad(sceneParams)
  logger.debug("spectating: " .. tostring(GAME.battleRoom.spectating))
  --refreshBasedOnOwnMods(msg.opponent_settings)
  --refreshBasedOnOwnMods(msg.player_settings)
  --refreshBasedOnOwnMods(msg) -- for stage only, other data are meaningless to us
  -- mainly for spectator mode, those characters have already been loaded otherwise
  --current_stage = msg.stage
  --character_loader_wait()
  --stage_loader_wait()
  GAME.match = Match("vs", GAME.battleRoom)
  GAME.match.supportsPause = false
  local msg = sceneParams.msg
  GAME.match.seed = self:getSeed(msg)
  if match_type == "Ranked" then
    GAME.match.room_ratings = self.currentRoomRatings
    GAME.match.my_player_number = self.my_player_number
    GAME.match.op_player_number = self.op_player_number
  end

  local is_local = true
  --if GAME.battleRoom.spectating then
  --  is_local = false
  --end
  GAME.match.P1 = Stack{which = 1, match = GAME.match, is_local = is_local, panels_dir = msg.player_settings.panels_dir, level = msg.player_settings.level, inputMethod = msg.player_settings.inputMethod or "controller", character = msg.player_settings.character, player_number = msg.player_settings.player_number}
  local P1 = GAME.match.P1
  P1.cur_wait_time = default_input_repeat_delay -- this enforces default cur_wait_time for online games.  It is yet to be decided if we want to allow this to be custom online.
  GAME.match.P2 = Stack{which = 2, match = GAME.match, is_local = false, panels_dir = msg.opponent_settings.panels_dir, level = msg.opponent_settings.level, inputMethod = msg.opponent_settings.inputMethod or "controller", character = msg.opponent_settings.character, player_number = msg.opponent_settings.player_number}
  local P2 = GAME.match.P2
  P2.cur_wait_time = default_input_repeat_delay -- this enforces default cur_wait_time for online games.  It is yet to be decided if we want to allow this to be custom online.
  P1:setOpponent(P2)
  P1:setGarbageTarget(P2)
  P2:setOpponent(P1)
  P2:setGarbageTarget(P1)
  P2:moveForPlayerNumber(2)
  -- replay = Replay.createNewReplay(GAME.match)

  --[[
  if GAME.battleRoom.spectating and replay_of_match_so_far then --we joined a match in progress
    for k, v in pairs(replay_of_match_so_far.vs) do
      replay.vs[k] = v
    end
    P1:receiveConfirmedInput(uncompress_input_string(replay_of_match_so_far.vs.in_buf))
    P2:receiveConfirmedInput(uncompress_input_string(replay_of_match_so_far.vs.I))
    
    replay_of_match_so_far = nil
    --this makes non local stacks run until caught up
    P1.play_to_end = true
    P2.play_to_end = true
  end
  --]]

  GAME.input:requestSingleInputConfigurationForPlayerCount(1)

  -- Proceed to the game screen and start the game
  P1:starting_state()
  P2:starting_state()

  --[[
  local to_print = loc("pl_game_start") .. "\n" .. loc("level") .. ": " .. P1.level .. "\n" .. loc("opponent_level") .. ": " .. P2.level
  if P1.play_to_end or P2.play_to_end then
    to_print = loc("pl_spectate_join")
  end
  --]]
end

local function handleTaunt()
  local function getCharacter(playerNumber)
    local P1 = GAME.match.P1
    local P2 = GAME.match.P2
    if P1.player_number == playerNumber then
      return characters[P1.character]
    elseif P2.player_number == playerNumber then
      return characters[P2.character]
    end
  end

  local messages = server_queue:pop_all_with("taunt")
  for _, msg in ipairs(messages) do
    if msg.taunt then -- receive taunts
      local character = getCharacter(msg.player_number)
      if character ~= nil then
        character:playTaunt(msg.type, msg.index)
      end
   end
  end
end

local function handleLeaveMessage()
  local messages = server_queue:pop_all_with("leave_room")
  for _, msg in ipairs(messages) do
    if msg.leave_room then -- lost room during game, go back to lobby
      Replay.finalizeAndWriteVsReplay(GAME.match.battleRoom, 0, true, GAME.match, replay)

      -- Show a message that the match connection was lost along with the average frames behind.
      local message = loc("ss_room_closed_in_game")

      local P1Behind = GAME.match.P1:averageFramesBehind()
      local P2Behind = GAME.match.P2:averageFramesBehind()
      local maxBehind = math.max(P1Behind, P2Behind)

      if GAME.battleRoom.spectating then
        message = message .. "\n" .. loc("ss_average_frames_behind_player", GAME.battleRoom.playerNames[1], P1Behind)
        message = message .. "\n" .. loc("ss_average_frames_behind_player", GAME.battleRoom.playerNames[2], P2Behind)
      else 
        message = message .. "\n" .. loc("ss_average_frames_behind", maxBehind)
      end

      sceneManager:switchToScene("Lobby")
      return true
    end
  end
end

--[[
local function handleGameEndAsSpectator()
  -- if the game already ended before we caught up, abort trying to catch up to it early in order to get into the next game instead
  if GAME.battleRoom.spectating and (GAME.match.P1.play_to_end or GAME.match.P2.play_to_end) then
    local message = server_queue:pop_next_with("create_room", "character_select")
    if message then
      -- shove the message back in for select_screen to handle
      server_queue:push(message)
      return {main_dumb_transition, {select_screen.main, nil, 0, 0, false, false, {select_screen, "2p_net_vs"}}}
    end
  end
end
--]]

function OnlineVsGame:customRun()
  local transition = nil
  handleTaunt()

  if handleLeaveMessage() then
    return true
  end

  --[[
  transition = handleGameEndAsSpectator()
  if transition then
    return transition
  end
  --]]

  if not do_messages() then
    sceneManager:switchToScene("MainMenu")
    return -- return {main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}}
  end

  process_all_data_messages() -- Receive game play inputs from the network

  -- if not GAME.battleRoom.spectating then
  if GAME.match.P1.tooFarBehindError or GAME.match.P2.tooFarBehindError then
    Replay.finalizeAndWriteVsReplay(GAME.match.battleRoom, 0, true, GAME.match, replay)
    GAME:clearMatch()
    json_send({leave_room = true})
    local ip = GAME.connected_server_ip
    local port = GAME.connected_network_port
    resetNetwork()
    return {main_dumb_transition, {
      main_net_vs_setup, -- next_func
      loc("ss_latency_error"), -- text
      60, -- timemin
      -1, -- timemax
      nil, -- winnerSFX
      false, -- keepMusic
      {ip, port} -- args
    }}
  end
  -- end
end

function OnlineVsGame:customGameOverSetup()
  json_send({game_over = true, outcome = GAME.match.battleRoom:matchOutcome()["outcome_claim"]})
  self.maxDisplayTime = 8
  self.nextScene = "CharacterSelectOnline"
end

function OnlineVsGame:processGameResults()
  local matchOutcome = GAME.match.battleRoom:matchOutcome()
  if matchOutcome then
    local end_text = matchOutcome["end_text"]
    local winSFX = matchOutcome["winSFX"]
    local outcome_claim = matchOutcome["outcome_claim"]
    if outcome_claim ~= 0 then
      GAME.battleRoom.playerWinCounts[outcome_claim] = GAME.battleRoom.playerWinCounts[outcome_claim] + 1
    end
    
    Replay.finalizeAndWriteVsReplay(GAME.match.battleRoom, outcome_claim, false, GAME.match, replay)
  
    --[[if GAME.battleRoom.spectating then
      -- next_func, text, winnerSFX, timemax, keepMusic, args
      return {game_over_transition,
        {select_screen.main, end_text, winSFX, nil, false, {select_screen, "2p_net_vs"}}
      }
    else
      return {game_over_transition, 
        {select_screen.main, end_text, winSFX, 60 * 8, false, {select_screen, "2p_net_vs"}}
      }
    end--]]
  end
end

return OnlineVsGame