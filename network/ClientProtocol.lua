local Request = require("network.Request")

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

  return Request(playerChallengeRequest):send()
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

  local request = Request(spectateRequest, "spectate_request_granted")
  return request:send()
end

function ClientRequests.requestLeaderboard()
  local leaderboardRequest =
  {
    leaderboard_request = true
  }

  local request = Request(leaderboardRequest, "leaderboard_report")
  return request:send()
end

function ClientRequests.requestLogin()
  local loginMessage =
  {
    login_request = true,
    user_id = my_user_id
  }

  local request = Request(loginMessage, "login_successful", "login_denied")
  return request:send()
end

function ClientRequests.logout()
  local logoutMessage =
  {
    logout = true
  }

  return Request(logoutMessage):send()
end



return ClientRequests