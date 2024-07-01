require("client.src.graphics.animated_sprite")
-- make environment
local env = {
  Animation = Animation,
  addFrame = Animation.addFrame,
  setLoopStart = Animation.setLoopStart,
  setLoopEnd = Animation.setLoopEnd,
  Animation.createAnimation
} -- add functions you know are safe here
-- run code under environment [Lua 5.2]
local ModApi = {}
function ModApi.runFromFile(untrusted_file)
  local untrusted_function, message = love.filesystem.load(untrusted_file)
  if not untrusted_function then return nil, message end
  setfenv(untrusted_function, env)
  return pcall(untrusted_function)
end

function ModApi.run(untrusted_code)
  local untrusted_function, message = load(untrusted_code, nil, 't', env)
  if not untrusted_function then return nil, message end
  return pcall(untrusted_function)
end

return ModApi
-- test
-- assert(not run [[print(debug.getinfo(1))]]) --> fails
-- assert(run [[x=1]]) --> ok
-- assert(run [[while 1 do end]]) --> ok (but never returns)