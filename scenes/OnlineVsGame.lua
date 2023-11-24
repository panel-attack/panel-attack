local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local class = require("class")
local Replay = require("replay")
local logger = require("logger")
local GameModes = require("GameModes")

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
      Replay.finalizeAndWriteVsReplay(GAME.battleRoom, 0, true, GAME.match, replay)

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
    Replay.finalizeAndWriteVsReplay(GAME.battleRoom, 0, true, GAME.match, replay)
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
  json_send({game_over = true, outcome = GAME.match:getOutcome()["outcome_claim"]})
  self.maxDisplayTime = 8
  self.nextScene = "CharacterSelectOnline"
end

function OnlineVsGame:processGameResults()
  local matchOutcome = GAME.match:getOutcome()
  if matchOutcome then
    local end_text = matchOutcome["end_text"]
    local winSFX = matchOutcome["winSFX"]
    local outcome_claim = matchOutcome["outcome_claim"]
    if outcome_claim ~= 0 then
      GAME.battleRoom.playerWinCounts[outcome_claim] = GAME.battleRoom.playerWinCounts[outcome_claim] + 1
    end
    
    Replay.finalizeAndWriteVsReplay(GAME.battleRoom, outcome_claim, false, GAME.match, replay)
  
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