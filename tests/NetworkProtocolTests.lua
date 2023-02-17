
local NetworkProtocol = require("NetworkProtocol")

local utf8 = require("utf8Additions")

for i = 1, 70000 do
  local jsonString = NetworkProtocol.JSONStringFromLength(i)
  local decodedLength = NetworkProtocol.JSONlengthFromString(jsonString)
  assert(decodedLength == i)

  -- Test that extra data on the end doesn't mess it up
  decodedLength = NetworkProtocol.JSONlengthFromString(jsonString .. "IĀ210Ĭ3Ī13Ā400Ĝ5Ğ5Ā37Ĭ108Ī6Ā48Đ4")
  assert(decodedLength == i)

  -- TODO: test partial returns nil
end

local function testGetMessage(messageBuffer, expectedTypes, expectedMessages, isServerMessage)
  local buffer = messageBuffer
  local typeResults = {}
  local messageResults = {}
  while buffer ~= nil do
    local type, message, remaining = NetworkProtocol.getMessageFromString(buffer, isServerMessage)
    if type then
      typeResults[#typeResults+1] = type
      messageResults[#messageResults+1] = message
      buffer = remaining
    else
      buffer = nil
    end
  end

  assert(#expectedTypes == #typeResults)
  assert(#expectedMessages == #messageResults)

  for i = 1, #typeResults do
    assert(expectedTypes[i] == typeResults[i])
    assert(expectedMessages[i] == messageResults[i])
  end
end

-- Test we can send I and U unicode messages with part of the next message after
testGetMessage("H047" .. NetworkProtocol.markedMessageForTypeAndBody("I", "Ā") .. "I", {"H", "I"}, {"047", "Ā"}, false)
testGetMessage("H047" .. NetworkProtocol.markedMessageForTypeAndBody("U", "Ā") .. "U", {"H", "U"}, {"047", "Ā"}, false)

-- Test we can send a J and then H message
testGetMessage(NetworkProtocol.markedMessageForTypeAndBody("J", "{body=1}") .. "H", {"J", "H"}, {"{body=1}", ""}, true)

-- Test we can send a J and then H message with part of the next message after
testGetMessage(NetworkProtocol.markedMessageForTypeAndBody("J", "{body=1}") .. string.char(128), {"J"}, {"{body=1}"}, true)