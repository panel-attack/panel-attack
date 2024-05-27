local utf8 = require("common.lib.utf8Additions")

function string.toCharTable(self)
  local t = {}
  for _, codePoint in utf8.codes(self) do
    local character = utf8.char(codePoint)
    t[#t+1] = character
  end
  return t
end