require("common.lib.util")
require("common.lib.mathExtensions")

-- math.sign tests
assert(math.sign(0.5) == 1)
assert(math.sign(2) == 1)
assert(math.sign(-0.5) == -1)
assert(math.sign(-2) == -1)
assert(math.sign(0) == 1)

-- math.round tests
assert(math.round(0) == 0)
assert(math.round(0.5) == 1)
assert(math.round(0.49) == 0)
assert(math.round(0.1) == 0)
assert(math.round(-0.1) == 0)
assert(math.round(-0.5) == -1)
assert(math.round(-0.51) == -1)
assert(math.round(-1.1) == -1)
assert(math.round(-1.5) == -2)
assert(math.round(-1.51) == -2)
assert(math.round(12, -1) == 10)
assert(math.round(0.11, 1) == 0.1)
assert(math.round(-1.11, 1) == -1.1)
assert(math.round(0.119, 2) == 0.12)

-- math.integerAwayFromZero tests
assert(math.integerAwayFromZero(0) == 0)
assert(math.integerAwayFromZero(0.5) == 1)
assert(math.integerAwayFromZero(0.49) == 1)
assert(math.integerAwayFromZero(0.1) == 1)
assert(math.integerAwayFromZero(-0.1) == -1)
assert(math.integerAwayFromZero(-0.5) == -1)
assert(math.integerAwayFromZero(-0.51) == -1)
assert(math.integerAwayFromZero(-1.1) == -2)
assert(math.integerAwayFromZero(-1.5) == -2)
assert(math.integerAwayFromZero(-1.51) == -2)

local function testFramesToTimeStringPartialSeconds()
  assert(frames_to_time_string(0, false) == "0:00")
  assert(frames_to_time_string(0, true) == "0:00'00")
  assert(frames_to_time_string(1, false) == "0:00")
  assert(frames_to_time_string(1, true) == "0:00'01")
  assert(frames_to_time_string(2, false) == "0:00")
  assert(frames_to_time_string(2, true) == "0:00'03")
  assert(frames_to_time_string(3, false) == "0:00")
  assert(frames_to_time_string(3, true) == "0:00'05")
  assert(frames_to_time_string(4, false) == "0:00")
  assert(frames_to_time_string(4, true) == "0:00'06")
  assert(frames_to_time_string(5, false) == "0:00")
  assert(frames_to_time_string(5, true) == "0:00'08")
  assert(frames_to_time_string(6, false) == "0:00")
  assert(frames_to_time_string(6, true) == "0:00'10")
end

testFramesToTimeStringPartialSeconds()

local function testFramesToTimeStringSeconds()
  assert(frames_to_time_string(60, false) == "0:01")
  assert(frames_to_time_string(60, true) == "0:01'00")
  assert(frames_to_time_string(61, false) == "0:01")
  assert(frames_to_time_string(61, true) == "0:01'01")
  assert(frames_to_time_string(62, false) == "0:01")
  assert(frames_to_time_string(62, true) == "0:01'03")
  assert(frames_to_time_string(63, false) == "0:01")
  assert(frames_to_time_string(63, true) == "0:01'05")
  assert(frames_to_time_string(64, false) == "0:01")
  assert(frames_to_time_string(64, true) == "0:01'06")
  assert(frames_to_time_string(65, false) == "0:01")
  assert(frames_to_time_string(65, true) == "0:01'08")
  assert(frames_to_time_string(66, false) == "0:01")
  assert(frames_to_time_string(66, true) == "0:01'10")
  assert(frames_to_time_string(606, false) == "0:10")
  assert(frames_to_time_string(606, true) == "0:10'10")
end

testFramesToTimeStringSeconds()

local function testFramesToTimeStringMinutes()
  assert(frames_to_time_string(60 * 60, false) == "1:00")
  assert(frames_to_time_string(60 * 60, true) == "1:00'00")
  assert(frames_to_time_string(60 * 60 + 61, false) == "1:01")
  assert(frames_to_time_string(60 * 60 + 61, true) == "1:01'01")
  assert(frames_to_time_string(60 * 60 * 10, false) == "10:00")
  assert(frames_to_time_string(60 * 60 * 10, true) == "10:00'00")
end

testFramesToTimeStringMinutes()

local function testFramesToTimeStringHours()
  -- Right now we don't treat hours special, just counts as 60 minutes
  assert(frames_to_time_string(60 * 60 * 60, false) == "60:00")
  assert(frames_to_time_string(60 * 60 * 60, true) == "60:00'00")
  assert(frames_to_time_string(60 * 60 * 60 + 61, false) == "60:01")
  assert(frames_to_time_string(60 * 60 * 60 + 61, true) == "60:01'01")
end

testFramesToTimeStringHours()


local function testfloatsEqualWithPrecision()
  assert(math.floatsEqualWithPrecision(1, 1, 20))
  assert(math.floatsEqualWithPrecision(1, 2, 20) == false)
  assert(math.floatsEqualWithPrecision(1.333, 1.334, 2))
  assert(math.floatsEqualWithPrecision(1.333, 1.334, 3) == false)
end

testfloatsEqualWithPrecision()

