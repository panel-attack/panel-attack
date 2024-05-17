require("server.Connection")
require("server.PlayerBase")
require("server.server_globals")

local testServer = {}
testServer.isPlayerBanned = function (ip)
  return nil
end

testServer.insertBan = function (ip, reason, completionTime)
  return {} -- might need more details later like reason and completiontime
end


testServer.playerbase = Playerbase("Test", nil)
testServer.playerbase:addPlayer(1, "Jerry")
testServer.playerbase:addPlayer(2, "Ben")

function testLoginInvalidName()  
  local connection = Connection(nil, 1, testServer)

  -- blank name
  local denyReason, _ = connection:canLogin(2, nil, "1.1.1.1", ENGINE_VERSION)
  assert(denyReason ~= nil)

  -- anonymous
  denyReason, _ = connection:canLogin(2, "anonymous", "1.1.1.1", ENGINE_VERSION)
  assert(denyReason ~= nil)

  -- Anonymous
  denyReason, _ = connection:canLogin(2, "Anonymous", "1.1.1.1", ENGINE_VERSION)
  assert(denyReason ~= nil)

  -- defaultname
  denyReason, _ = connection:canLogin(2, "defaultnam", "1.1.1.1", ENGINE_VERSION)
  assert(denyReason ~= nil)

  -- only alpha numeric and underscores
  denyReason, _ = connection:canLogin(2, "L$3t", "1.1.1.1", ENGINE_VERSION)
  assert(denyReason ~= nil)

  -- NAME_LENGTH_LIMIT
  denyReason, _ = connection:canLogin(2, "testtesttesttesttesttest", "1.1.1.1", ENGINE_VERSION)
  assert(denyReason ~= nil)
end

testLoginInvalidName()

function testLoginInvalidUserID()  
  local connection = Connection(nil, 1, testServer)

  -- no user ID
  local denyReason, _ = connection:canLogin(nil, "Bob", "1.1.1.1", ENGINE_VERSION)
  assert(denyReason ~= nil)

  -- asking for new user, but name alread taken
  denyReason, _ = connection:canLogin("need a new user id", "Jerry", "1.1.1.1", ENGINE_VERSION)
  assert(denyReason ~= nil)

  -- fake ID
  local _, playerBan = connection:canLogin(42, "Bob", "1.1.1.1", ENGINE_VERSION)
  assert(playerBan ~= nil)

  -- have account, name taken and doesn't match ID
  denyReason, _ = connection:canLogin(2, "Jerry", "1.1.1.1", ENGINE_VERSION)
  assert(denyReason ~= nil)
end

testLoginInvalidUserID()

function testLoginDeniedForInvalidVersion()
  local connection = Connection(nil, 1, testServer)

  local denyReason, playerBan = connection:canLogin(2, "BEN", "1.1.1.1", "XXX")
  assert(denyReason ~= nil)
end

testLoginDeniedForInvalidVersion()

function testLoginAllowed()
  local connection = Connection(nil, 1, testServer)

  -- can login if have account and username case changed
  local denyReason, playerBan = connection:canLogin(2, "BEN", "1.1.1.1", ENGINE_VERSION)
  assert(denyReason == nil and playerBan == nil)

  -- can login if have account and changes name
  denyReason, playerBan = connection:canLogin(2, "Jeremy", "1.1.1.1", ENGINE_VERSION)
  assert(denyReason == nil and playerBan == nil)

  -- can login if have account and name isn't changed
  denyReason, playerBan = connection:canLogin(2, "Ben", "1.1.1.1", ENGINE_VERSION)
  assert(denyReason == nil and playerBan == nil)

  -- can login with new account if name not taken
  denyReason, playerBan = connection:canLogin("need a new user id", "Joseph", "1.1.1.1", ENGINE_VERSION)
  assert(denyReason == nil and playerBan == nil)

end

testLoginAllowed()