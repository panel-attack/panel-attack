local Request = require("network.Request")
local NetworkProtocol = require("network.NetworkProtocol")
local msgTypes = NetworkProtocol.clientMessageTypes

local ClientRequests = {}

-- players are challenged by their current name on the server
function ClientRequests.challengePlayer(name)
  local playerChallengeRequest =
  {
    game_request =
    {
      sender = config.name,
      receiver = name
    }
  }

  local request = Request(msgTypes.jsonMessage, playerChallengeRequest)
  return request:send()
end

function ClientRequests.requestSpectate(roomNumber)
  local spectateRequest =
  {
    spectate_request =
    {
      sender = config.name,
      roomNumber = roomNumber
    }
  }

  local request = Request(msgTypes.jsonMessage, spectateRequest, {"spectate_request_granted"})
  return request:send()
end

function ClientRequests.requestLeaderboard()
  local leaderboardRequest = {leaderboard_request = true}

  local request = Request(msgTypes.jsonMessage, leaderboardRequest, {"leaderboard_report"})
  return request:send()
end

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

return ClientRequests
