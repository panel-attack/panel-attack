local class = require("class")

--@module Scene
local Scene = class(
  function (self, name)
    self.name = name
  end
)

-- abstract functions to be implemented per scene
function Scene:init() end

function Scene:load() end

function Scene:update() end

function Scene:unload() end

return Scene