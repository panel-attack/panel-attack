local StackReplayTestingUtils = require("common.engine.tests.StackReplayTestingUtils")
local input = require("common.lib.inputManager")

local processEvents = function()
  if love.event then
    love.event.pump()
    for name, a, b, c, d, e, f in love.event.poll() do
      if name == "quit" then
        if not love.quit or not love.quit() then
          return a or 0
        end
      end
      love.handlers[name](a, b, c, d, e, f)
    end
  end
end

-- TODO: rewrite the test with sourcing the pressed keys from match.P1.player.inputConfiguration
local function testSameFrameKeyPressRelease()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  match.P1.player:restrictInputs(GAME.input.inputConfigurations[1])
  -- advance past countdown
  match.P1:receiveConfirmedInput(string.rep(match.P1:idleInput(), 200))
  while match.P1.clock < 200 do
    assert(not match:hasEnded(), "Game isn't expected to end yet")
    assert(#match.P1.input_buffer > 0)
    match:run()
  end
  assert(match.P1.clock == 200)
  -- need local to be true to process input locally
  match.P1.is_local = true
  local raiseKey = GAME.input.inputConfigurations[1]["Raise1"]
  assert(raiseKey ~= nil)
  love.event.push("keypressed", raiseKey, raiseKey, false)
  love.event.push("keyreleased", raiseKey, raiseKey, false)
  processEvents()
  input:update(1/60)
  -- there is no way to directly control how many times match will run
  -- so instead emulate the parts match would run but only once
  match.P1:send_controls()
  match.P1:run()
  assert(match.P1.confirmedInput[201] == "g")
  processEvents()
  input:update(1/60)
  match.P1:send_controls()
  match.P1:run()
  assert(match.P1.confirmedInput[202] == "A")
  match.P1.player:unrestrictInputs()
end

testSameFrameKeyPressRelease()