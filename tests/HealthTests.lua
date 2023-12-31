require("Health")

local function testHealthDamageBaseCase()
  local secondsToppedOutToLose = 10
  local lineClearGPM = 0
  local lineHeightToKill = 6
  local riseLevel = 10
  local health = Health(secondsToppedOutToLose, lineClearGPM, lineHeightToKill, riseLevel)

  assert(health ~= nil)
  assertAlmostEqual(health:damageForHeight(1), 1)
  assertAlmostEqual(health:damageForHeight(2), 2)
  assertAlmostEqual(health:damageForHeight(3), 3)
  assertAlmostEqual(health:damageForHeight(4), 4)
  assertAlmostEqual(health:damageForHeight(5), 5)
end

testHealthDamageBaseCase()

local function testHealthDamageReducedForBigChains()
  local secondsToppedOutToLose = 10
  local lineClearGPM = 0
  local lineHeightToKill = 6
  local riseLevel = 10
  local health = Health(secondsToppedOutToLose, lineClearGPM, lineHeightToKill, riseLevel)

  assert(health ~= nil)
  assertAlmostEqual(health:damageForHeight(6), 5.8)
  assertAlmostEqual(health:damageForHeight(7), 6.4)
  assertAlmostEqual(health:damageForHeight(8), 6.8)
  assertAlmostEqual(health:damageForHeight(9), 7.0)
  assertAlmostEqual(health:damageForHeight(10), 7.0)
  assertAlmostEqual(health:damageForHeight(13), 7.0)
end

testHealthDamageReducedForBigChains()