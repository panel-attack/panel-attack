local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local Replay = require("replay")
local class = require("class")
local Signal = require("helpers.signal")

--@module endlessGame
-- Scene for an endless mode instance of the game
local Game2pVs = class(
  function (self, sceneParams)
    self.nextScene = sceneParams.nextScene

    self:load(sceneParams)
    self.match:connectSignal("matchEnded", self, self.onMatchEnded)
  end,
  GameBase
)

Game2pVs.name = "Game2pVs"
sceneManager:addScene(Game2pVs)

function Game2pVs:onMatchEnded(match)
  local extraPath, extraFilename = "", ""
  local rep_a_name, rep_b_name = match.players[1].name, match.players[2].name
    --sort player names alphabetically for folder name so we don't have a folder "a-vs-b" and also "b-vs-a"
    if rep_b_name < rep_a_name then
      extraPath = rep_b_name .. "-vs-" .. rep_a_name
    else
      extraPath = rep_a_name .. "-vs-" .. rep_b_name
    end
    extraFilename = extraFilename .. rep_a_name .. "-L" .. match.P1.level .. "-vs-" .. rep_b_name .. "-L" .. match.P2.level
    if match.ranked then
      extraFilename = extraFilename .. "-" .. "Ranked"
    else
      extraFilename = extraFilename .. "-" .. "Casual"
    end
    if not match.replay.incomplete then
      if match.replay.winnerIndex then
        extraFilename = extraFilename .. "-P" .. match.replay.winnerIndex .. "wins"
      else
        extraFilename = extraFilename .. "-draw"
      end
    end
  Replay.finalizeAndWriteReplay(extraPath, extraFilename, match.replay)
end

return Game2pVs