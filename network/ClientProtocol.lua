local Request = require("network.Request")
local NetworkProtocol = require("network.NetworkProtocol")
local msgTypes = NetworkProtocol.clientMessageTypes
local consts = require("consts")

local ClientMessages = {}

-------------------------
-- login related requests
-------------------------

function ClientMessages.requestLogin(userId)
  local loginMessage = {login_request = true, user_id = userId}

  return {
    messageType = msgTypes.jsonMessage,
    messageText = loginMessage,
    responseTypes = {"login_successful", "login_denied"}
  }
end

function ClientMessages.logout()
  local logoutMessage = {logout = true}

  return {
    messageType = msgTypes.jsonMessage,
    messageText = logoutMessage,
  }
end

function ClientMessages.tryReserveUsernameRequest(config)
  local userNameMessage =
  {
    name = config.name,
    level = config.level,
    inputMethod = config.inputMethod or "controller",
    panels_dir = config.panels,
    character = config.character,
    stage = config.stage,
    ranked = config.ranked,
    save_replays_publicly = config.save_replays_publicly
  }

  if config.character then
    if config.character == consts.RANDOM_CHARACTER_SPECIAL_VALUE then
      userNameMessage.character_is_random = consts.RANDOM_CHARACTER_SPECIAL_VALUE
    elseif characters[config.character] and characters[config.character]:is_bundle() then
      userNameMessage.character_is_random = config.character
    end
  end

  if config.stage then
    if config.stage == consts.RANDOM_STAGE_SPECIAL_VALUE then
      userNameMessage.stage_is_random = consts.RANDOM_STAGE_SPECIAL_VALUE
    elseif stages[config.stage] and stages[config.stage]:is_bundle() then
      userNameMessage.stage_is_random = config.stage
    end
  end

  -- despite all these other props, the main point of this message is to validate the name and register the connection with it
  -- this is a poorly defined client-server interaction
  -- the server only responds if there is a problem but it does not respond if there is none, meaning we basically have to wait for timeout
  return {
    messageType = msgTypes.jsonMessage,
    messageText = userNameMessage,
    responseTypes = {"choose_another_name"}
  }
end

function ClientMessages.requestVersionCompatibilityCheck()
  return {
    messageType = msgTypes.versionCheck,
    messageText = nil,
    responseTypes = {"versionCompatible"}
  }
end

-------------------------
-- Lobby related requests
-------------------------

-- players are challenged by their current name on the server
function ClientMessages.challengePlayer(name)
  local playerChallengeMessage =
  {
    game_request =
    {
      sender = config.name,
      receiver = name
    }
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = playerChallengeMessage,
  }
end

function ClientMessages.requestSpectate(roomNumber)
  local spectateRequestMessage =
  {
    spectate_request =
    {
      sender = config.name,
      roomNumber = roomNumber
    }
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = spectateRequestMessage,
    responseTypes = {"spectate_request_granted"}
  }
end

function ClientMessages.requestLeaderboard()
  local leaderboardRequestMessage = {leaderboard_request = true}

  return {
    messageType = msgTypes.jsonMessage,
    messageText = leaderboardRequestMessage,
    responseTypes = {"leaderboard_report"}
  }
end

------------------------------
-- BattleRoom related requests
------------------------------
function ClientMessages.leaveRoom()
  local leaveRoomMessage = {leave_room = true}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = leaveRoomMessage,
  }
end

function ClientMessages.reportLocalGameResult(outcome)
  local gameResultMessage = {game_over = true, outcome = outcome}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = gameResultMessage,
  }
end

function ClientMessages.sendMenuState(menuState)
  local menuStateMessage = {menu_state = menuState}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = menuStateMessage,
  }
end

function ClientMessages.sendTaunt(direction, index)
  local type = "taunt_" .. string.lower(direction) .. "s"
  local tauntMessage = {taunt = true, type = type, index = index}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = tauntMessage,
  }
end

-------------------------
-- miscellaneous requests
-------------------------

function ClientMessages.sendErrorReport(errorData)
  local errorReportMessage = {error_report = errorData}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = errorReportMessage,
  }
end

return ClientMessages
