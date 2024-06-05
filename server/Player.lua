--local logger = require("common.lib.logger")
local database = require("server.PADatabase")
local class = require("common.lib.class")
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
