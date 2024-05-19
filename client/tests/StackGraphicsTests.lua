require("client.src.graphics.Stack")
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")
require("common.engine.Stack")
local StackReplayTestingUtils = require("common.engine.tests.StackReplayTestingUtils")
local GFX_SCALE = consts.GFX_SCALE

local Theme = require("client.src.mods.Theme")

local function test(func)
  func()
end

local legacyScoreX = 546
local legacyScoreXP2 = 642
local legacyScoreY = 208

local currentTheme = themes[config.theme]

local function setTheme(theme)
  themes[config.theme] = theme
end

local v1Theme = Theme("V1Test")
assert(v1Theme ~= nil)
local defaultTheme = Theme(consts.DEFAULT_THEME_DIRECTORY)
assert(defaultTheme ~= nil)

-- ORIGIN TESTING

local function testOriginalThemeStackGraphics()
  setTheme(v1Theme)
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 1)
  local stack = match.P1

  assert(match ~= nil)
  assert(stack.origin_x == 184)
  assert(stack:elementOriginX(false, false) == stack.origin_x * GFX_SCALE)
  assert(stack:elementOriginY(false, false) == stack.panelOriginY * GFX_SCALE)
  assert(stack:elementOriginX(true, false) == legacyScoreX)
  assert(stack:elementOriginY(true, false) == legacyScoreY)
end

--test(testOriginalThemeStackGraphics)

local function testOriginalThemeStackGraphicsPlayer2()
  setTheme(v1Theme)
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 2)
  local stack = match.P2

  assert(match ~= nil)
  assert(stack.origin_x * GFX_SCALE == 728)
  assert(stack:elementOriginX(false, false) == stack.origin_x * GFX_SCALE)
  assert(stack:elementOriginY(false, false) == stack.panelOriginY * GFX_SCALE)
  assert(stack:elementOriginX(true, false) == legacyScoreXP2)
  assert(stack:elementOriginY(true, false) == legacyScoreY)
end

--test(testOriginalThemeStackGraphicsPlayer2)

local function testNewThemeStackGraphics()
  setTheme(defaultTheme)
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 1)
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
  setTheme(defaultTheme)
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 2)
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
  setTheme(v1Theme)
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 1)
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

--test(testOriginalThemeOffset)

local function testOriginalThemeOffsetPlayer2()
  setTheme(v1Theme)
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 2)
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

--test(testOriginalThemeOffsetPlayer2)

local function testNewThemeOffset()
  setTheme(defaultTheme)
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 1)
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
  setTheme(defaultTheme)
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 2)
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

setTheme(currentTheme)

local function testShakeOffsetLargeGarbage()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 2, defaultTheme)
  match.seed = 1
  local stack = match.P2

  -- for i = 76, 1, -1 do
  --   logger.info("assert(stack:shakeOffsetForShakeFrames(" .. i .. ", 0, 1) == " .. stack:shakeOffsetForShakeFrames(i, 0, 1) .. ")")
  -- end

  -- This is a characterization test, I.E. I just recorded the current behavior so I could prove I didn't break it.
  -- Thus I can't vouch that these values are "expected" just that I didn't change them.
  assert(stack:shakeOffsetForShakeFrames(76, 0, 1) == 2)
  assert(stack:shakeOffsetForShakeFrames(75, 0, 1) == 0)
  assert(stack:shakeOffsetForShakeFrames(74, 0, 1) == 3)
  assert(stack:shakeOffsetForShakeFrames(73, 0, 1) == 8)
  assert(stack:shakeOffsetForShakeFrames(72, 0, 1) == 16)
  assert(stack:shakeOffsetForShakeFrames(71, 0, 1) == 23)
  assert(stack:shakeOffsetForShakeFrames(70, 0, 1) == 30)
  assert(stack:shakeOffsetForShakeFrames(69, 0, 1) == 33)
  assert(stack:shakeOffsetForShakeFrames(68, 0, 1) == 32)
  assert(stack:shakeOffsetForShakeFrames(67, 0, 1) == 28)
  assert(stack:shakeOffsetForShakeFrames(66, 0, 1) == 22)
  assert(stack:shakeOffsetForShakeFrames(65, 0, 1) == 14)
  assert(stack:shakeOffsetForShakeFrames(64, 0, 1) == 7)
  assert(stack:shakeOffsetForShakeFrames(63, 0, 1) == 2)
  assert(stack:shakeOffsetForShakeFrames(62, 0, 1) == 0)
  assert(stack:shakeOffsetForShakeFrames(61, 0, 1) == 2)
  assert(stack:shakeOffsetForShakeFrames(60, 0, 1) == 8)
  assert(stack:shakeOffsetForShakeFrames(59, 0, 1) == 15)
  assert(stack:shakeOffsetForShakeFrames(58, 0, 1) == 21)
  assert(stack:shakeOffsetForShakeFrames(57, 0, 1) == 26)
  assert(stack:shakeOffsetForShakeFrames(56, 0, 1) == 27)
  assert(stack:shakeOffsetForShakeFrames(55, 0, 1) == 25)
  assert(stack:shakeOffsetForShakeFrames(54, 0, 1) == 20)
  assert(stack:shakeOffsetForShakeFrames(53, 0, 1) == 13)
  assert(stack:shakeOffsetForShakeFrames(52, 0, 1) == 7)
  assert(stack:shakeOffsetForShakeFrames(51, 0, 1) == 2)
  assert(stack:shakeOffsetForShakeFrames(50, 0, 1) == 0)
  assert(stack:shakeOffsetForShakeFrames(49, 0, 1) == 2)
  assert(stack:shakeOffsetForShakeFrames(48, 0, 1) == 7)
  assert(stack:shakeOffsetForShakeFrames(47, 0, 1) == 13)
  assert(stack:shakeOffsetForShakeFrames(46, 0, 1) == 19)
  assert(stack:shakeOffsetForShakeFrames(45, 0, 1) == 21)
  assert(stack:shakeOffsetForShakeFrames(44, 0, 1) == 21)
  assert(stack:shakeOffsetForShakeFrames(43, 0, 1) == 17)
  assert(stack:shakeOffsetForShakeFrames(42, 0, 1) == 12)
  assert(stack:shakeOffsetForShakeFrames(41, 0, 1) == 6)
  assert(stack:shakeOffsetForShakeFrames(40, 0, 1) == 2)
  assert(stack:shakeOffsetForShakeFrames(39, 0, 1) == 0)
  assert(stack:shakeOffsetForShakeFrames(38, 0, 1) == 2)
  assert(stack:shakeOffsetForShakeFrames(37, 0, 1) == 7)
  assert(stack:shakeOffsetForShakeFrames(36, 0, 1) == 12)
  assert(stack:shakeOffsetForShakeFrames(35, 0, 1) == 16)
  assert(stack:shakeOffsetForShakeFrames(34, 0, 1) == 17)
  assert(stack:shakeOffsetForShakeFrames(33, 0, 1) == 15)
  assert(stack:shakeOffsetForShakeFrames(32, 0, 1) == 10)
  assert(stack:shakeOffsetForShakeFrames(31, 0, 1) == 6)
  assert(stack:shakeOffsetForShakeFrames(30, 0, 1) == 2)
  assert(stack:shakeOffsetForShakeFrames(29, 0, 1) == 0)
  assert(stack:shakeOffsetForShakeFrames(28, 0, 1) == 2)
  assert(stack:shakeOffsetForShakeFrames(27, 0, 1) == 6)
  assert(stack:shakeOffsetForShakeFrames(26, 0, 1) == 10)
  assert(stack:shakeOffsetForShakeFrames(25, 0, 1) == 12)
  assert(stack:shakeOffsetForShakeFrames(24, 0, 1) == 12)
  assert(stack:shakeOffsetForShakeFrames(23, 0, 1) == 9)
  assert(stack:shakeOffsetForShakeFrames(22, 0, 1) == 5)
  assert(stack:shakeOffsetForShakeFrames(21, 0, 1) == 2)
  assert(stack:shakeOffsetForShakeFrames(20, 0, 1) == 0)
  assert(stack:shakeOffsetForShakeFrames(19, 0, 1) == 2)
  assert(stack:shakeOffsetForShakeFrames(18, 0, 1) == 5)
  assert(stack:shakeOffsetForShakeFrames(17, 0, 1) == 7)
  assert(stack:shakeOffsetForShakeFrames(16, 0, 1) == 8)
  assert(stack:shakeOffsetForShakeFrames(15, 0, 1) == 7)
  assert(stack:shakeOffsetForShakeFrames(14, 0, 1) == 4)
  assert(stack:shakeOffsetForShakeFrames(13, 0, 1) == 1)
  assert(stack:shakeOffsetForShakeFrames(12, 0, 1) == 0)
  assert(stack:shakeOffsetForShakeFrames(11, 0, 1) == 1)
  assert(stack:shakeOffsetForShakeFrames(10, 0, 1) == 3)
  assert(stack:shakeOffsetForShakeFrames(9, 0, 1) == 5)
  assert(stack:shakeOffsetForShakeFrames(8, 0, 1) == 4)
  assert(stack:shakeOffsetForShakeFrames(7, 0, 1) == 3)
  assert(stack:shakeOffsetForShakeFrames(6, 0, 1) == 1)
  assert(stack:shakeOffsetForShakeFrames(5, 0, 1) == 0)
  assert(stack:shakeOffsetForShakeFrames(4, 0, 1) == 1)
  assert(stack:shakeOffsetForShakeFrames(3, 0, 1) == 2)
  assert(stack:shakeOffsetForShakeFrames(2, 0, 1) == 1)
  assert(stack:shakeOffsetForShakeFrames(1, 0, 1) == 1)  
  assert(stack:shakeOffsetForShakeFrames(0, 0, 1) == 0)
end

test(testShakeOffsetLargeGarbage)

-- Tests that having reduction properly reduces and rounds
local function testShakeOffsetReduction()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 2, defaultTheme)
  match.seed = 1
  local stack = match.P2
  assert(stack:shakeOffsetForShakeFrames(76, 0, 0.5) == 1)
  assert(stack:shakeOffsetForShakeFrames(75, 0, 0.5) == 0)
  assert(stack:shakeOffsetForShakeFrames(74, 0, 0.5) == 2)
  assert(stack:shakeOffsetForShakeFrames(73, 0, 0.5) == 4)
  assert(stack:shakeOffsetForShakeFrames(72, 0, 0.5) == 8)
  assert(stack:shakeOffsetForShakeFrames(71, 0, 0.5) == 12)
  assert(stack:shakeOffsetForShakeFrames(70, 0, 0.5) == 15)
  assert(stack:shakeOffsetForShakeFrames(69, 0, 0.5) == 17)
  assert(stack:shakeOffsetForShakeFrames(68, 0, 0.5) == 16)
  assert(stack:shakeOffsetForShakeFrames(67, 0, 0.5) == 14)
  assert(stack:shakeOffsetForShakeFrames(66, 0, 0.5) == 11)
  assert(stack:shakeOffsetForShakeFrames(65, 0, 0.5) == 7)
  assert(stack:shakeOffsetForShakeFrames(64, 0, 0.5) == 4)
  assert(stack:shakeOffsetForShakeFrames(63, 0, 0.5) == 1)
  assert(stack:shakeOffsetForShakeFrames(62, 0, 0.5) == 0)
  
  assert(stack:shakeOffsetForShakeFrames(12, 0, 0.5) == 0)
  assert(stack:shakeOffsetForShakeFrames(11, 0, 0.5) == 1)
  assert(stack:shakeOffsetForShakeFrames(10, 0, 0.5) == 2)
  assert(stack:shakeOffsetForShakeFrames(9, 0, 0.5) == 3)
  assert(stack:shakeOffsetForShakeFrames(8, 0, 0.5) == 2)
  assert(stack:shakeOffsetForShakeFrames(7, 0, 0.5) == 2)
  assert(stack:shakeOffsetForShakeFrames(6, 0, 0.5) == 1)
  assert(stack:shakeOffsetForShakeFrames(5, 0, 0.5) == 0)
  assert(stack:shakeOffsetForShakeFrames(4, 0, 0.5) == 1)
  assert(stack:shakeOffsetForShakeFrames(3, 0, 0.5) == 1)
  assert(stack:shakeOffsetForShakeFrames(2, 0, 0.5) == 1)
  assert(stack:shakeOffsetForShakeFrames(1, 0, 0.5) == 1)  
  assert(stack:shakeOffsetForShakeFrames(0, 0, 0.5) == 0)
end

test(testShakeOffsetReduction)

local function testShakeOffsetMassiveReduction()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 2, defaultTheme)
  match.seed = 1
  local stack = match.P2
  assert(stack:shakeOffsetForShakeFrames(76, 0, 0.25) == 1)
  assert(stack:shakeOffsetForShakeFrames(75, 0, 0.25) == 0)
  assert(stack:shakeOffsetForShakeFrames(74, 0, 0.25) == 1)
  assert(stack:shakeOffsetForShakeFrames(73, 0, 0.25) == 2)
  assert(stack:shakeOffsetForShakeFrames(72, 0, 0.25) == 4)
  assert(stack:shakeOffsetForShakeFrames(71, 0, 0.25) == 6)
  assert(stack:shakeOffsetForShakeFrames(70, 0, 0.25) == 8)
  assert(stack:shakeOffsetForShakeFrames(69, 0, 0.25) == 9)
  assert(stack:shakeOffsetForShakeFrames(68, 0, 0.25) == 8)
  assert(stack:shakeOffsetForShakeFrames(67, 0, 0.25) == 7)
  assert(stack:shakeOffsetForShakeFrames(66, 0, 0.25) == 6)
  assert(stack:shakeOffsetForShakeFrames(65, 0, 0.25) == 4)
  assert(stack:shakeOffsetForShakeFrames(64, 0, 0.25) == 2)
  assert(stack:shakeOffsetForShakeFrames(63, 0, 0.25) == 1)
  assert(stack:shakeOffsetForShakeFrames(62, 0, 0.25) == 0)
  
  assert(stack:shakeOffsetForShakeFrames(12, 0, 0.25) == 0)
  assert(stack:shakeOffsetForShakeFrames(11, 0, 0.25) == 1)
  assert(stack:shakeOffsetForShakeFrames(10, 0, 0.25) == 1)
  assert(stack:shakeOffsetForShakeFrames(9, 0, 0.25) == 2)
  assert(stack:shakeOffsetForShakeFrames(8, 0, 0.25) == 1)
  assert(stack:shakeOffsetForShakeFrames(7, 0, 0.25) == 1)
  assert(stack:shakeOffsetForShakeFrames(6, 0, 0.25) == 1)
  assert(stack:shakeOffsetForShakeFrames(5, 0, 0.25) == 0)
  assert(stack:shakeOffsetForShakeFrames(4, 0, 0.25) == 1)
  assert(stack:shakeOffsetForShakeFrames(3, 0, 0.25) == 1)
  assert(stack:shakeOffsetForShakeFrames(2, 0, 0.25) == 1)
  assert(stack:shakeOffsetForShakeFrames(1, 0, 0.25) == 1)  
  assert(stack:shakeOffsetForShakeFrames(0, 0, 0.25) == 0)
end

test(testShakeOffsetMassiveReduction)

local function testShakeInterpolate()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10, true, 2, defaultTheme)
  match.seed = 1
  local stack = match.P2
  assert(stack:shakeOffsetForShakeFrames(70, 0, 1) == 30)
  assert(stack:shakeOffsetForShakeFrames(16, 0, 1) == 8)
  assert(stack:shakeOffsetForShakeFrames(70, 16, 1) == 19)
  assert(stack:shakeOffsetForShakeFrames(2, 0, 1) == 1)
  assert(stack:shakeOffsetForShakeFrames(1, 0, 1) == 1)  
  assert(stack:shakeOffsetForShakeFrames(2, 1, 1) == 1)
end

test(testShakeInterpolate)
