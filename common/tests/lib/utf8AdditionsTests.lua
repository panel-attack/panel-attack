
local utf8 = require("common.lib.utf8Additions")

assert(utf8 ~= nil)

assert(utf8.len("test") == 4)
assert(utf8.len("Ā") == 1)
assert(utf8.len("3Ī") == 2)
assert(utf8.len("Ī1") == 2)
assert(utf8.len("ĪĪĪ") == 3)
assert(utf8.len("") == 0)

assert(utf8.firstLetter("test") == "t")
assert(utf8.firstLetter("ĪĪĪ") == "Ī")
assert(utf8.firstLetter("3Ī") == "3")

assert(utf8.sub("test", 2) == "est")
assert(utf8.sub("ĪĪa", 2, 3) == "Īa")
assert(utf8.sub("3Ī", 1, 1) == "3")
