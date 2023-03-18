local class = require("class")

--@module Scene
-- Base class for a container representing a single screen of PanelAttack.
-- Each scene needs to be registered in Game.lua 
local Scene = class(
  function (self, name)
    self.name = name
  end
)

-- abstract functions to be implemented per scene

-- Ran once per instance of PanelAttack
-- used to create objects once per scene to be reused for the lifetime of the game
function Scene:init() end

-- Ran every time the scene is started
-- used to setup the state of the scene before running
function Scene:load() end

-- Ran every frame while the scene is active
function Scene:update() end

-- Ran every frame before anything is drawn
function Scene:drawBackground() end

-- Ran every frame after everything is drawn
function Scene:drawForeground() end

-- Ran every time the scene is ending
-- used to clean up resources/global state used within the scene (stopping audio, hiding menus, etc.)
function Scene:unload() end

return Scene