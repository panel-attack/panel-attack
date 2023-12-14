require("server_queue")
require("network.network")

-- how many tries (read: frames) it takes for a request to give up waiting for a response
local REQUEST_TIMEOUT = 10 * 60

local function createResponseCoroutine(responseTypes)
  local cr = coroutine.create(
    function ()
      local response
      local frameCount = 0

      while not response and frameCount < REQUEST_TIMEOUT do
        coroutine.yield()
        response = server_queue:pop_next_with(unpack(responseTypes))
        frameCount = frameCount + 1
      end

      return response
    end
  )

  return cr
end

-- A simple wrapper for responses to client requests to the server
local Response = class(function(response, responseTypes)
  response.responseTypes = responseTypes
  response.coroutine = createResponseCoroutine(responseTypes)
  response.awaitingResponse = true
  response.given = false
end)

-- try to get a value from the response object
-- returns expired if the response returned its result before
-- returns timeout if no server response arrived within the timeout limit
-- returns waiting if no response has arrived yet but time is still below timeout limit
-- returns received and the response value if a response arrived
function Response:tryGetValue()
  if coroutine.status(self.coroutine) == "dead" then
    return "expired", nil
  else
    -- assuming coroutine status is normal  
    local success, returnValues = coroutine.resume(self.coroutine)
    if not success then
      GAME.crashTrace = debug.traceback(self.coroutine)
      error(returnValues)
    else
      if coroutine.status(self.coFunc) ~= "dead" then
        return "waiting", nil
      else
        self.awaitingResponse = false
        if returnValues == nil then
          -- this means we timed out
          return "timeout", nil
        else
          self.given = true
          return "received", returnValues
        end
      end
    end
  end
end

return Response