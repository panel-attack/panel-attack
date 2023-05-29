--local logger = require("logger")
local database = require("server.PADatabase")
Player =
  class(
  function(self, privatePlayerID)
    self.publicPlayerID = database:getPublicPlayerID(privatePlayerID)
  end
)

return Player
