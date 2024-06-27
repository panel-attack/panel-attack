local RollbackBuffer = require("common.engine.RollbackBuffer")

local function testNormalRollback()
  local buffer = RollbackBuffer(250)

  for i = 1, 300 do
    buffer:saveCopy(i, { i = i})
  end

  local rollbackCopy = buffer:rollbackToFrame(147)
  assert(rollbackCopy, "Should have been able to rollback 103 frames")
  assert(rollbackCopy.i == 147, "Rolled back to frame " .. rollbackCopy.i .. " instead of 147")
end

local function testStaleMarking()
  local buffer = RollbackBuffer(250)

  for i = 1, 300 do
    buffer:saveCopy(i, { i = i})
  end

  local rollbackCopy = buffer:rollbackToFrame(147)
  rollbackCopy = buffer:rollbackToFrame(150)
  assert(rollbackCopy == nil, "Rollback copies in the future should no longer be available via the accessor")
  rollbackCopy = buffer.buffer[buffer.currentIndex + 3]
  assert(rollbackCopy, "copies for stale frames should not get discarded")
  assert(rollbackCopy.i, "the copy for frame 150 should still be available here, instead it is the copy for " .. rollbackCopy.i)
end

local function testFrameTooOld()
  local buffer = RollbackBuffer(250)

  for i = 1, 300 do
    buffer:saveCopy(i, { i = i})
  end

  local rollbackCopy = buffer:rollbackToFrame(20)
  assert(rollbackCopy == nil, "Buffer should have only saved the last 250 copies")
end

local function testPostRollbackWrite()
  local buffer = RollbackBuffer(245)

  for i = 1, 500 do
    local copy = buffer:getOldest() or {}
    copy.i = i
    buffer:saveCopy(i, copy)
  end

  local rollbackCopy = buffer:rollbackToFrame(463)
  assert(rollbackCopy, "Expected to have a rollback copy for frame 463 but did not")
  assert(rollbackCopy.i == 463, "Expected to find a rollback copy with i = 463 but got i = " .. rollbackCopy.i)
  for i = rollbackCopy.i, 500 do
    local copy = buffer:getOldest() or {}
    copy.i = i
    buffer:saveCopy(i, copy)
  end

  local expected = 500
  local currentIndex = buffer.currentIndex
  for i = 1, buffer.size do
    currentIndex = wrap(1, currentIndex - 1, buffer.size)
    assert(buffer.buffer[currentIndex].i == expected,
    "Expected " .. expected .. " at position " .. currentIndex
    .. " but got " .. buffer.buffer[currentIndex].i .. " instead")
    expected = expected - 1
  end
end

testNormalRollback()
testStaleMarking()
testFrameTooOld()
testPostRollbackWrite()