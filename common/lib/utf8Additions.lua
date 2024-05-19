local utf8
if love then
  utf8 = require("utf8")
else
  utf8 = require("lua-utf8")
end



assert(utf8.len ~= nil)
assert(utf8.offset ~= nil)

function utf8.firstLetter(unicodeString)
  --result = unicodeString:match("[%z\1-\127\194-\244][\128-\191]*")
  local result = string.match(unicodeString, utf8.charpattern)
  return result
end

function utf8.sub(s,i,j)
  assert(i ~= nil)
  assert(i > 0)
  assert(j == nil or j > 0)
  i = utf8.offset(s,i)
  j = j or utf8.len(s)
  j = utf8.offset(s,j+1)-1
  return string.sub(s,i,j)
end

return utf8