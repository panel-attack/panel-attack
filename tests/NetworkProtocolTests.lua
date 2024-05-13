local NetworkProtocol = require("network.NetworkProtocol")

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
testGetMessage("H" .. NetworkProtocol.markedMessageForTypeAndBody("U", "Ā") .. "U", {"H", "U"}, {"", "Ā"}, true)

-- Test we can send a J and then H message
testGetMessage(NetworkProtocol.markedMessageForTypeAndBody("J", "{body=1}") .. "H", {"J", "H"}, {"{body=1}", ""}, true)

-- Test we can send a J and then part of the next message after
testGetMessage(NetworkProtocol.markedMessageForTypeAndBody("J", "{body=1}") .. "J" .. string.char(128), {"J"}, {"{body=1}"}, true)