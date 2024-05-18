-- We must launch the server from the root directory so all the requires are the right path relatively.
require("client.src.developer") -- Require developer here so we can debug if the debug flag is set
local util = require("common.lib.util")
util.addToCPath("./common/lib/sqlite/??")
util.addToCPath("./server/lib/??")
require("server.tests.ConnectionTests")

local database = require("server.PADatabase")
local Server = require("server.server")


local currentServer = Server(database)
while true do
  currentServer:update()
end