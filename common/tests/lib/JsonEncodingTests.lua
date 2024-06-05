local json = require("common.lib.dkjson")

local function testEncodingDecoding(data)
  local encoded = json.encode(data)
  local reformedData = json.decode(encoded)
  for key, value in pairs(reformedData) do
    assert(data[key] == value)
  end
end

testEncodingDecoding({table = 1, bob = 2})

-- dkjson puts the utf8 directly into the json. So we need to be able to support utf8 strings
testEncodingDecoding({input = "Ā210Ĭ3Ī13Ā400Ĝ5Ğ5Ā37Ĭ108Ī6Ā48Đ4", output = 2})