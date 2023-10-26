local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local CharacterSelect = require("scenes.CharacterSelect")
local class = require("class")

--@module CharacterSelectChallenge
-- 
local CharacterSelectChallenge = class(
  function (self, sceneParams)
    self.players = {{}, {}}
    self:load(sceneParams)
  end,
  CharacterSelect
)

CharacterSelectChallenge.name = "CharacterSelectChallenge"
sceneManager:addScene(CharacterSelectChallenge)

return CharacterSelectChallenge