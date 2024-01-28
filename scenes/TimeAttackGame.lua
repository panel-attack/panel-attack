local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local Replay = require("replay")
local class = require("class")
local GameModes = require("GameModes")
local Signal = require("helpers.signal")

--@module timeAttackGame
-- Scene for an time attack mode instance of the game
local TimeAttackGame = class(
  function (self, sceneParams)
    self.nextScene = "TimeAttackMenu"
    
    self:load(sceneParams)
    self.match:connectSignal("matchEnded", self, self.onMatchEnded)
  end,
  GameBase
)

TimeAttackGame.name = "TimeAttackGame"
sceneManager:addScene(TimeAttackGame)

function TimeAttackGame:onMatchEnded(match)
  local extraPath = "Time Attack"
  local extraFilename = "-timeattack"
  if match.players[1].settings.style == GameModes.Styles.CLASSIC then
    GAME.scores:saveTimeAttack1PScoreForLevel(match.players[1].stack.score, match.players[1].stack.difficulty)
    extraFilename = "Spd" .. match.players[1].settings.levelData.startingSpeed .. "-Dif" .. match.players[1].stack.difficulty .. extraFilename
    Replay.finalizeAndWriteReplay(extraPath, extraFilename, self.match.replay)
  elseif match.players[1].settings.style == GameModes.Styles.MODERN then
    extraFilename = "Spd" .. match.players[1].settings.levelData.startingSpeed .. "-Lev" .. match.players[1].stack.level .. extraFilename
    Replay.finalizeAndWriteReplay(extraPath, extraFilename, self.match.replay)
  end
end

return TimeAttackGame