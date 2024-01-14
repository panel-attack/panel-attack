--local logger = require("logger")
local database = require("server.PADatabase")
Player =
  class(
  function(self, privatePlayerID)
    assert(database ~= nil)
    local playerData = database:getPlayerFromPrivateID(privatePlayerID)
    if playerData then
      self.publicPlayerID = playerData.publicPlayerID
    end
  end
)

return Player
