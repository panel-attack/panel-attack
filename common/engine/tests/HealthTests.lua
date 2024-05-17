require("Health")

local function testHealthDamageBaseCase()
  local secondsToppedOutToLose = 10
  local lineClearGPM = 0
  local lineHeightToKill = 6
  local riseLevel = 10
  local health = Health(secondsToppedOutToLose, lineClearGPM, lineHeightToKill, riseLevel)

  assert(health ~= nil)
  assertEqual(health:damageForHeight(1), 1)
  assertEqual(health:damageForHeight(2), 2)
  assertEqual(health:damageForHeight(3), 3)
  assertEqual(health:damageForHeight(4), 4)
  assertEqual(health:damageForHeight(5), 5)
end

testHealthDamageBaseCase()

local function testHealthDamageReducedForBigChains()
  local secondsToppedOutToLose = 10
  local lineClearGPM = 0
  local lineHeightToKill = 6
  local riseLevel = 10
  local health = Health(secondsToppedOutToLose, lineClearGPM, lineHeightToKill, riseLevel)

  assert(health ~= nil)
  assert(math.floatsEqualWithPrecision(health:damageForHeight(6), 5.8, 10))
  assert(math.floatsEqualWithPrecision(health:damageForHeight(7), 6.4, 10))
  assert(math.floatsEqualWithPrecision(health:damageForHeight(8), 6.8, 10))
  assert(math.floatsEqualWithPrecision(health:damageForHeight(9), 7, 10))
  assert(math.floatsEqualWithPrecision(health:damageForHeight(10), 7, 10))
  assert(math.floatsEqualWithPrecision(health:damageForHeight(13), 7, 10))
end

testHealthDamageReducedForBigChains()