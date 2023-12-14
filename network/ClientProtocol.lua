local Request = require("network.Request")
local NetworkProtocol = require("network.NetworkProtocol")
local msgTypes = NetworkProtocol.clientMessageTypes

local ClientRequests = {}

-------------------------
-- login related requests
-------------------------

function ClientRequests.requestLogin(userId)
  local loginMessage = {login_request = true, user_id = userId}

  local request = Request(msgTypes.jsonMessage, loginMessage, {"login_successful", "login_denied"})
  return request:send()
end

function ClientRequests.logout()
  local logoutMessage = {logout = true}

  return Request(msgTypes.jsonMessage, logoutMessage):send()
end

function ClientRequests.tryReserveUsername(config)
  local userNameMessage =
  {
    name = config.name,
    level = config.level,
    inputMethod = config.inputMethod or "controller",
    panels_dir = config.panels,
    character = config.character,
    character_is_random = ((config.character == random_character_special_value or characters[config.character]:is_bundle()) and config.character or nil),
    stage = config.stage,
    ranked = config.ranked,
    stage_is_random = ((config.stage == random_stage_special_value or stages[config.stage]:is_bundle()) and config.stage or nil),
    save_replays_publicly = config.save_replays_publicly
  }

  -- despite all these other props, the actual point of this message is to validate the name and register the connection with it

  -- this is a poorly defined client-server interaction
  -- the server only responds if there is a problem but it does not respond if there is none, meaning we basically have to wait for timeout
  local request = Request(msgTypes.jsonMessage, userNameMessage, {"choose_another_name"})
  return request:send()
end

function ClientRequests.requestVersionCompatibilityCheck()

  local request = Request(msgTypes.versionCheck, nil, {"versionCompatible"})
  return request:send()
end

-------------------------
-- Lobby related requests
-------------------------

-- players are challenged by their current name on the server
function ClientRequests.challengePlayer(name)
  local playerChallengeMessage =
  {
    game_request =
    {
      sender = config.name,
      receiver = name
    }
  }

  local request = Request(msgTypes.jsonMessage, playerChallengeMessage)
  return request:send()
end

function ClientRequests.requestSpectate(roomNumber)
  local spectateRequestMessage =
  {
    spectate_request =
    {
      sender = config.name,
      roomNumber = roomNumber
    }
  }

  local request = Request(msgTypes.jsonMessage, spectateRequestMessage, {"spectate_request_granted"})
  return request:send()
end

function ClientRequests.requestLeaderboard()
  local leaderboardRequestMessage = {leaderboard_request = true}

  local request = Request(msgTypes.jsonMessage, leaderboardRequestMessage, {"leaderboard_report"})
  return request:send()
end

------------------------------
-- BattleRoom related requests
------------------------------
function ClientRequests.leaveRoom()
  local leaveRoomMessage = {leave_room = true}
  local request = Request(msgTypes.jsonMessage, leaveRoomMessage)
  return request:send()
end

function ClientRequests.reportLocalGameResult(outcome)
  local gameResultMessage = {game_over = true, outcome = outcome}
  local request = Request(msgTypes.jsonMessage, gameResultMessage)
  return request:send()
end

function ClientRequests.sendMenuState(menuState)
  local menuStateMessage = {menu_state = menuState}
  local request = Request(msgTypes.jsonMessage, menuStateMessage)
  return request:send()
end

function ClientRequests.sendTaunt(direction, index)
  local type = "taunt_" .. string.lower(direction) .. "s"
  local tauntMessage = {taunt = true, type = type, index = index}
  local request = Request(msgTypes.jsonMessage, tauntMessage)
  return request:send()
end

-------------------------
-- miscellaneous requests
-------------------------

function ClientRequests.sendErrorReport(errorData)
  local errorReportMessage = {error_report = errorData}
  local request = Request(msgTypes.jsonMessage, errorReportMessage)
  return request:send()
end

return ClientRequests
