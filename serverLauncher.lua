-- We must launch the server from the root directory so all the requires are the right path relatively.

require("developer") -- Require developer here so we can debug if the debug flag is set

local database = require("server.PADatabase")
local Server = require("server.server")

require("tests.Tests")

local currentServer = Server(database)
while true do
  currentServer:update()
end