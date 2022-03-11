require("csprng")

local seed = 2131451567743265

initialize_mt_generator(seed)
local color = extract_mt(1, 5)

initialize_mt_generator(seed)
local color2 = extract_mt(1, 5)

assert(color == color2)