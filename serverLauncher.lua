-- We must launch the server from the root directory so all the requires are the right path relatively.
local server = require("server.server")
while true do
  server:update()
end