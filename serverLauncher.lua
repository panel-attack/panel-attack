-- We must launch the server from the root directory so all the requires are the right path relatively.
local database = require("server.PADatabase")
local Server = require("server.server")

local currentServer = Server(database)
while true do
  currentServer:update()
end