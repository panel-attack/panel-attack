local GameBase = require("client.src.scenes.GameBase")
local sceneManager = require("client.src.scenes.sceneManager")
local Replay = require("common.engine.Replay")
local class = require("common.lib.class")
local GameModes = require("common.engine.GameModes")

--@module endlessGame
-- Scene for an endless mode instance of the game
local EndlessGame = class(
  function (self, sceneParams)
    self.nextScene = "EndlessMenu"

    self:load(sceneParams)
    self.match:connectSignal("matchEnded", self, self.onMatchEnded)
  end,
  GameBase
)

EndlessGame.name = "EndlessGame"
sceneManager:addScene(EndlessGame)

function EndlessGame:onMatchEnded(match)
  local extraPath = "Endless"
  local extraFilename = "-endless"
  if match.players[1].settings.style == GameModes.Styles.CLASSIC then
    GAME.scores:saveEndlessScoreForLevel(match.players[1].stack.score, match.players[1].stack.difficulty)
    extraFilename = "Spd" .. match.players[1].settings.levelData.startingSpeed .. "-Dif" .. match.players[1].stack.difficulty .. extraFilename
    Replay.finalizeAndWriteReplay(extraPath, extraFilename, self.match.replay)
  elseif match.players[1].settings.style == GameModes.Styles.MODERN then
    extraFilename = "Spd" .. match.players[1].settings.levelData.startingSpeed .. "-Lev" .. match.players[1].stack.level .. extraFilename
    Replay.finalizeAndWriteReplay(extraPath, extraFilename, self.match.replay)
  end
end

return EndlessGame