local StackReplayTestingUtils = require("tests.StackReplayTestingUtils")
local CustomRun = require("CustomRun")

local function testSameFrameKeyPressRelease()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  GAME.input:requestSingleInputConfigurationForPlayerCount(1)
  -- we need to lock in the used keyconfig with a single input before inputs can be detected
  local swapKey = GAME.input.availableInputConfigurationsToAssign[1]["swap1"]
  love.event.push("keypressed", swapKey, swapKey, false)
  CustomRun.processEvents()
  love.event.push("keyreleased", swapKey, swapKey, false)
  CustomRun.processEvents()
  -- need to overwrite these to pretend that a frame passed (part of variable_step)
  this_frame_keys = {}
  this_frame_released_keys = {}
  this_frame_unicodes = {}

  -- need this to be true to process input locally
  match.P1.is_local = true
  match.P1:receiveConfirmedInput(string.rep(match.P1:idleInput(), 200))
  while match.P1.clock < 200 do
    assert(match:matchOutcome() == nil, "Game isn't expected to end yet")
    assert(#match.P1.input_buffer > 0)
    match:run()
  end
  local raiseKey = GAME.input.playerInputConfigurationsMap[1][1]["raise1"]
  love.event.push("keypressed", raiseKey, raiseKey, false)
  love.event.push("keyreleased", raiseKey, raiseKey, false)
  CustomRun.processEvents()
  match:run()
  assert(match.P1.confirmedInput[#match.P1.confirmedInput] == "g")
end

testSameFrameKeyPressRelease()