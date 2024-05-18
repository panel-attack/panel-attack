local TcpClient = require("client.src.network.TcpClient")
local consts = require("common.engine.consts")
local ClientMessages = require("common.network.ClientProtocol")
local NetworkProtocol = require("common.network.NetworkProtocol")

-- all of these tests assume that there is a socket listening on the respective port
local testServerIp = consts.SERVER_LOCATION
-- this is also the internal default although it probably should not be
local testServerPort = 49569

local function testConnectDisconnect()
  local tcpClient = TcpClient()
  local success = tcpClient:connectToServer(testServerIp, testServerPort)
  assert(success)
  assert(tcpClient:isConnected())
  tcpClient:resetNetwork()
  assert(not tcpClient:isConnected())
end

testConnectDisconnect()

local function testSendData()
  local tcpClient = TcpClient()
  local success = tcpClient:connectToServer(testServerIp, testServerPort)
  assert(success)
  assert(tcpClient:isConnected())
  local message = NetworkProtocol.clientMessageTypes.versionCheck.prefix .. NetworkProtocol.NETWORK_VERSION
  assert(tcpClient:send(message))
  tcpClient:sendRequest(ClientMessages.logout())
  assert(tcpClient:isConnected())
  tcpClient:resetNetwork()
  assert(not tcpClient:isConnected())
end

testSendData()

-- local function testReceiveData()
--   local tcpClient = TcpClient()
--   local success = tcpClient:connectToServer(testServerIp, testServerPort)
--   assert(success)
--   assert(tcpClient:isConnected())
--   tcpClient:sendRequest(ClientMessages.requestLogin("-"))
--   -- there is a max character limit of 16 for names
--   -- the server should deny the login
--   local startTime = love.timer.getTime()
--   while tcpClient.receivedMessageQueue:size() == 0 and love.timer.getTime() < startTime + 5 do
--     tcpClient:processIncomingMessages()
--   end

--   assert(tcpClient.receivedMessageQueue:size() > 0)
--   tcpClient:sendRequest(ClientMessages.logout())
--   assert(tcpClient:isConnected())
--   tcpClient:resetNetwork()
--   assert(not tcpClient:isConnected())
-- end

-- testReceiveData()

-- not really feasible to test more without also spinning up a server locally with test data