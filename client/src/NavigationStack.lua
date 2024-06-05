local DirectTransition = require("client.src.scenes.Transitions.DirectTransition")
local SoundController = require("client.src.music.SoundController")
local tableUtils = require("common.lib.tableUtils")
local logger = require("common.lib.logger")

local NavigationStack = {
  scenes = {},
  transition = nil,
  callback = nil,
}

local sceneMusicLabels = { "title_screen", "main", "select_screen" }
-- tries to apply the passed music with respect to the current theme's available musics
local function applyMusic(music)
  if music and tableUtils.contains(sceneMusicLabels, music) then
    if GAME.theme.stageTracks[music] then
      SoundController:playMusic(GAME.theme.stageTracks[music])
      return true
    end
  end
  return false
end

local function applySceneMusic(scene)
  if not applyMusic(scene.music) then
    if not applyMusic(scene.fallbackMusic) then
      if not scene.keepMusic then
        SoundController:stopMusic()
      end
    end
  end
end

function NavigationStack:push(newScene, transition)
  local activeScene = self.scenes[#self.scenes]
  if not transition then
    transition = DirectTransition()
  end
  transition.oldScene = activeScene
  transition.newScene = newScene

  self.transition = transition

  if activeScene and activeScene.name == newScene.name then
    -- a bit of a crutch for puzzlemode:
    -- if the same scene is already on top of the stack
    -- replace the current one instead of pushing on top
    logger.debug("Replacing scene " .. newScene.name .. " on top of stack (caused by push)")
    self.scenes[#self.scenes] = newScene
  else
    logger.debug("Pushing scene " .. newScene.name .. " on top of stack")
    self.scenes[#self.scenes+1] = newScene
  end
end

-- transitions to the previous scene optionally using a specified transition
-- an optional callback may be passed that is called when the transition completed
function NavigationStack:pop(transition, callback)
  if #self.scenes > 1 then
    local activeScene = self.scenes[#self.scenes]
    local previousScene = self.scenes[#self.scenes - 1]

    logger.debug("Popping scene " .. activeScene.name .. ", new active scene is " .. previousScene.name)

    if not transition then
      transition = DirectTransition()
    end
    transition.oldScene = activeScene
    transition.newScene = previousScene

    self.transition = transition
    self.callback = callback
    table.remove(self.scenes)
  end
end

-- transitions to the bottom most scene in the stack optionally using a specified transition
-- usually this will be MainMenu
-- an optional callback may be passed that is called when the transition completed
function NavigationStack:popToTop(transition, callback)
  if #self.scenes > 1 then
    local activeScene = self.scenes[#self.scenes]
    local top = self.scenes[1]

    logger.debug("Popping from scene " .. activeScene.name .. " to top scene " .. top.name)


    if not transition then
      transition = DirectTransition()
    end
    transition.oldScene = activeScene
    transition.newScene = top

    self.transition = transition
    self.callback = callback

    for i = #self.scenes, 2, -1 do
      self.scenes[i] = nil
    end
  end
end

-- transitions to the first scene in the stack with the given name optionally using a specified transition
-- if none is found, this pops to top instead
-- an optional callback may be passed that is called when the transition completed
function NavigationStack:popToName(name, transition, callback)
  local targetScene
  local targetIndex
  -- if we're already at the desired scene, we also just stay
  for i = #self.scenes, 1, -1 do
    if self.scenes[i].name == name then
      targetIndex = i
      targetScene = self.scenes[i]
    end
  end

  if not targetScene then
    self:popToTop(transition, callback)
  else
    local activeScene = self.scenes[#self.scenes]
    logger.debug("Popping scene " .. activeScene.name .. ", down to " .. targetScene.name)


    if not transition then
      transition = DirectTransition()
    end
    transition.oldScene = activeScene
    transition.newScene = targetScene

    self.transition = transition
    self.callback = callback

    for i = #self.scenes, targetIndex + 1, -1 do
      self.scenes[i] = nil
    end
  end
end

-- transitions to the newScene, optionally using a specified transition while removing the current scene from the stack
-- an optional callback may be passed that is called when the transition completed
function NavigationStack:replace(newScene, transition, callback)
  local activeScene = self.scenes[#self.scenes]

  if activeScene then
    logger.debug("Replacing scene " .. activeScene.name .. " with scene " .. newScene.name)

    if not transition then
      transition = DirectTransition()
    end
    transition.oldScene = activeScene
    transition.newScene = newScene

    self.transition = transition
    self.callback = callback
    self.scenes[#self.scenes] = newScene
  else
    self:push(newScene, transition)
  end
end

function NavigationStack:getActiveScene()
  if self.transition then
    return nil
  else
    return self.scenes[#self.scenes]
  end
end

function NavigationStack:update(dt)
  if self.transition then
    self.transition:update(dt)

    if self.transition.progress >= 1 then
      self.transition = nil
      applySceneMusic(self.scenes[#self.scenes])
      if self.callback then
        self.callback()
        self.callback = nil
      end
      self.scenes[#self.scenes]:refresh()
    end
  else
    if #self.scenes == 0 then
      error("There better be an active scene. We bricked.")
    end
    self.scenes[#self.scenes]:update(dt)
  end
end

function NavigationStack:draw()
  if self.transition then
    self.transition:draw()
  else
    if #self.scenes == 0 then
      error("There better be an active scene. We bricked.")
    end
    self.scenes[#self.scenes]:draw()
  end
end

return NavigationStack