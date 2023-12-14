local class = require("class")
local Response = require("network.Response")

local Request = class(function(self, message, responseTypes)
  self.responseTypes = responseTypes
  self.message = message
end)

-- sends the request, updates awaitingResponse status field
function Request:send()
  json_send(self.message)

  if #self.responseTypes > 0 then
    return Response(self.responseTypes)
  else
    return nil
  end
end

return Request