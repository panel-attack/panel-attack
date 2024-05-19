local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
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

-- TODO: rewrite the test with sourcing the pressed keys from match.stacks[1].player.inputConfiguration
local function testSameFrameKeyPressRelease()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  match.stacks[1].player:restrictInputs(GAME.input.inputConfigurations[1])
  -- advance past countdown
  match.stacks[1]:receiveConfirmedInput(string.rep(match.stacks[1]:idleInput(), 200))
  while match.stacks[1].clock < 200 do
    assert(not match:hasEnded(), "Game isn't expected to end yet")
    assert(#match.stacks[1].input_buffer > 0)
    match:run()
  end
  assert(match.stacks[1].clock == 200)
  -- need local to be true to process input locally
  match.stacks[1].is_local = true
  local raiseKey = GAME.input.inputConfigurations[1]["Raise1"]
  assert(raiseKey ~= nil)
  love.event.push("keypressed", raiseKey, raiseKey, false)
  love.event.push("keyreleased", raiseKey, raiseKey, false)
  processEvents()
  input:update(1/60)
  -- there is no way to directly control how many times match will run
  -- so instead emulate the parts match would run but only once
  match.stacks[1]:send_controls()
  match.stacks[1]:run()
  assert(match.stacks[1].confirmedInput[201] == "g")
  processEvents()
  input:update(1/60)
  match.stacks[1]:send_controls()
  match.stacks[1]:run()
  assert(match.stacks[1].confirmedInput[202] == "A")
  match.stacks[1].player:unrestrictInputs()
end

testSameFrameKeyPressRelease()