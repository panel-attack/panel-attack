require("graphics")
local consts = require("consts")
require("engine")
local StackReplayTestingUtils = require("tests.StackReplayTestingUtils")

local function test(func)
  func()
  GAME:clearMatch()
end

local legacyScoreX = 546
local legacyScoreXP2 = 642
local legacyScoreY = 208

local v1Theme = Theme("V1Test")
assert(v1Theme ~= nil)
local defaultTheme = Theme(consts.DEFAULT_THEME_DIRECTORY)
assert(defaultTheme ~= nil)

-- ORIGIN TESTING

local function testOriginalThemeStackGraphics()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 1, v1Theme)
  match.seed = 1
  local stack = match.P1

  assert(match ~= nil)
  assert(stack.origin_x == 184)
  assert(stack:elementOriginX(false, false) == stack.origin_x * GFX_SCALE)
  assert(stack:elementOriginY(false, false) == stack.panelOriginY * GFX_SCALE)
  assert(stack:elementOriginX(true, false) == legacyScoreX)
  assert(stack:elementOriginY(true, false) == legacyScoreY)
end

test(testOriginalThemeStackGraphics)

local function testOriginalThemeStackGraphicsPlayer2()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 2, v1Theme)
  match.seed = 1
  local stack = match.P2

  assert(match ~= nil)
  assert(stack.origin_x * GFX_SCALE == 728)
  assert(stack:elementOriginX(false, false) == stack.origin_x * GFX_SCALE)
  assert(stack:elementOriginY(false, false) == stack.panelOriginY * GFX_SCALE)
  assert(stack:elementOriginX(true, false) == legacyScoreXP2)
  assert(stack:elementOriginY(true, false) == legacyScoreY)
end

test(testOriginalThemeStackGraphicsPlayer2)

local function testNewThemeStackGraphics()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 1, defaultTheme)
  match.seed = 1
  local stack = match.P1

  assert(match ~= nil)
  assert(stack.origin_x == 184)
  assert(stack:elementOriginX(false, false) == stack.origin_x * GFX_SCALE)
  assert(stack:elementOriginY(false, false) == stack.panelOriginY * GFX_SCALE)
  assert(stack:elementOriginX(true, false) == stack.origin_x * GFX_SCALE)
  assert(stack:elementOriginY(true, false) == stack.panelOriginY * GFX_SCALE)
end

test(testNewThemeStackGraphics)

local function testNewThemeStackGraphicsPlayer2()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 2, defaultTheme)
  match.seed = 1
  local stack = match.P2

  assert(match ~= nil)
  assert(stack.origin_x * GFX_SCALE == 728)
  assert(stack:elementOriginX(false, false) == stack.origin_x * GFX_SCALE)
  assert(stack:elementOriginY(false, false) == stack.panelOriginY * GFX_SCALE)
  assert(stack:elementOriginX(true, false) == stack.origin_x * GFX_SCALE)
  assert(stack:elementOriginY(true, false) == stack.panelOriginY * GFX_SCALE)
end

test(testNewThemeStackGraphicsPlayer2)

-- ORIGIN SHIFT TESTING 

local function testOriginalThemeOffset()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 1, v1Theme)
  match.seed = 1
  local stack = match.P1

  assert(match ~= nil)
  -- non "score" based values WERE in GFX_SCALE coordinates
  assert(stack:elementOriginXWithOffset({100, 100}, false) == stack.origin_x * GFX_SCALE + 100 * GFX_SCALE)
  assert(stack:elementOriginYWithOffset({100, 100}, false) == stack.panelOriginY * GFX_SCALE + 100 * GFX_SCALE)
  -- legacy score offsets were in absolute coordinates
  assert(stack:elementOriginXWithOffset({100, 100}, true) == legacyScoreX + 100)
  assert(stack:elementOriginYWithOffset({100, 100}, true) == legacyScoreY + 100)

  -- player 1 doesn't offset by width
  assert(stack:labelOriginXWithOffset({100, 100}, 1, false, 100, 0) == stack.origin_x * GFX_SCALE + 100 * GFX_SCALE - 0)
  assert(stack:labelOriginXWithOffset({100, 100}, 1, true, 100, 0) == legacyScoreX + 100 - 0)
end

test(testOriginalThemeOffset)

local function testOriginalThemeOffsetPlayer2()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 2, v1Theme)
  match.seed = 1
  local stack = match.P2

  assert(match ~= nil)
  -- non "score" based values WERE in GFX_SCALE coordinates, and mirror
  assert(stack:elementOriginXWithOffset({100, 100}, false) == stack.origin_x * GFX_SCALE - 100 * GFX_SCALE)
  assert(stack:elementOriginYWithOffset({100, 100}, false) == stack.panelOriginY * GFX_SCALE + 100 * GFX_SCALE)
  -- legacy score offsets were in absolute coordinates, and did NOT mirror
  assert(stack:elementOriginXWithOffset({100, 100}, true) == legacyScoreXP2 + 100)
  assert(stack:elementOriginYWithOffset({100, 100}, true) == legacyScoreY + 100)

  -- player 2 offsets by width in absolute coordinates
  assert(stack:labelOriginXWithOffset({100, 100}, 1, false, 100, 1) == stack.origin_x * GFX_SCALE - 100 * GFX_SCALE - 100)
  assert(stack:labelOriginXWithOffset({100, 100}, 1, true, 100, 1) == legacyScoreXP2 + 100 - 100)
end

test(testOriginalThemeOffsetPlayer2)

local function testNewThemeOffset()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 1, defaultTheme)
  match.seed = 1
  local stack = match.P1

  assert(match ~= nil)
  -- non "score" based values in new themes are in absolute coordinates
  assert(stack:elementOriginXWithOffset({100, 100}, false) == stack.origin_x * GFX_SCALE + 100)
  assert(stack:elementOriginYWithOffset({100, 100}, false) == stack.panelOriginY * GFX_SCALE + 100)
  -- legacy score offsets in the new themes are the same as above, absolute coordinates from the origin_x / panelOriginY
  assert(stack:elementOriginXWithOffset({100, 100}, true) == stack.origin_x * GFX_SCALE + 100)
  assert(stack:elementOriginYWithOffset({100, 100}, true) == stack.panelOriginY * GFX_SCALE + 100)

  -- player 1 doesn't offset by width
  assert(stack:labelOriginXWithOffset({100, 100}, 1, false, 100, 0) == stack.origin_x * GFX_SCALE + 100 - 0)
  assert(stack:labelOriginXWithOffset({100, 100}, 1, true, 100, 0) == stack.origin_x * GFX_SCALE + 100 - 0)
end

test(testNewThemeOffset)

local function testNewThemeOffsetPlayer2()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 2, defaultTheme)
  match.seed = 1
  local stack = match.P2

  assert(match ~= nil)
  -- non "score" based values in new themes are in absolute coordinates
  assert(stack:elementOriginXWithOffset({100, 100}, false) == stack.origin_x * GFX_SCALE - 100)
  assert(stack:elementOriginYWithOffset({100, 100}, false) == stack.panelOriginY * GFX_SCALE + 100)
  -- legacy score offsets in the new themes are the same as above, absolute coordinates from the origin_x / panelOriginY
  assert(stack:elementOriginXWithOffset({100, 100}, true) == stack.origin_x * GFX_SCALE - 100)
  assert(stack:elementOriginYWithOffset({100, 100}, true) == stack.panelOriginY * GFX_SCALE + 100)

  -- player 2 offsets by width in absolute coordinates
  assert(stack:labelOriginXWithOffset({100, 100}, 1, false, 100, 1) == stack.origin_x * GFX_SCALE - 100 - 100)
  assert(stack:labelOriginXWithOffset({100, 100}, 1, true, 100, 1) == stack.origin_x * GFX_SCALE - 100 - 100)
end

test(testNewThemeOffsetPlayer2)

local function testShakeOffset()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 2, defaultTheme)
  match.seed = 1
  local stack = match.P2

  assert(stack:shakeOffsetForShakeFrames(76, 76) == 0)
  assert(stack:shakeOffsetForShakeFrames(73, 76) == -16)
  assert(stack:shakeOffsetForShakeFrames(1, 76) == 1)
  assert(stack:shakeOffsetForShakeFrames(0, 76) == 0)

  assert(stack:shakeOffsetForShakeFrames(18, 18) == 0)
  assert(stack:shakeOffsetForShakeFrames(15, 18) == -3)
  assert(stack:shakeOffsetForShakeFrames(0, 18) == 0)
end

test(testShakeOffset)