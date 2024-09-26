if arg[1] == "debug" then
  -- for debugging in visual studio code
  pcall(function() require("lldebugger").start() end)
end

-- We must launch the server from the root directory so all the requires are the right path relatively.
require("server.server_globals")
local util = require("common.lib.util")
util.addToCPath("./common/lib/??")
util.addToCPath("./server/lib/??")
require("server.tests.ConnectionTests")

local database = require("server.PADatabase")
local Server = require("server.server")


local currentServer = Server(database)
while true do
  currentServer:update()
end