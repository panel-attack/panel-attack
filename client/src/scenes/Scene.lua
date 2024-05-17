local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")

--@module Scene
-- Base class for a container representing a single screen of PanelAttack.
-- Each scene should have a field called <Scene>.name = <Scene> (for identification in errors and debugging)
-- Each scene must add its UiElements as children to its uiRoot property
local Scene = class(
  function (self, sceneParams)
    self.uiRoot = UiElement({x = 0, y = 0, width = consts.CANVAS_WIDTH, height = consts.CANVAS_HEIGHT})
  end
)

-- abstract functions to be implemented per scene

-- Ran every time the scene is started
-- used to setup the state of the scene before running
function Scene:load(sceneParams) end

-- Ran every frame while the scene is active
function Scene:update(dt)
  error("every scene MUST implement an update function, even " .. self.name)
end

-- main draw
function Scene:draw()
  error("every scene MUST implement a draw function, even " .. self.name)
end

function Scene:refreshLocalization()
  self.uiRoot:refreshLocalization()
end

function Scene:drawCommunityMessage()
  -- Draw the community message
  if not config.debug_mode then
    GraphicsUtil.printf(join_community_msg or "", 0, 668, consts.CANVAS_WIDTH, "center")
  end
end

-- Ran every time the scene is ending
-- used to clean up resources/global state used within the scene (stopping audio, hiding menus, etc.)
function Scene:unload() end

return Scene