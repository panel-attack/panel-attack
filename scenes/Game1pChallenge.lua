local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local Replay = require("replay")
local class = require("class")
local Signal = require("helpers.signal")

--@module endlessGame
-- Scene for an endless mode instance of the game
local Game1pChallenge = class(
  function (self, sceneParams)
    self.nextScene = "CharacterSelectChallenge"
    self:load(sceneParams)
    Signal.connectSignal(self.match, "onMatchEnded", self, self.onMatchEnded)
  end,
  GameBase
)

Game1pChallenge.name = "Game1pChallenge"
sceneManager:addScene(Game1pChallenge)

function Game1pChallenge:onMatchEnded(match)
  Replay.finalizeAndWriteReplay("Challenge Mode", "stage-" .. match.players[1].wins + 1, match.replay)
end

return Game1pChallenge