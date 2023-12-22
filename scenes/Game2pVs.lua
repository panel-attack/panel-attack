local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local Replay = require("replay")
local class = require("class")

--@module endlessGame
-- Scene for an endless mode instance of the game
local Game2pVs = class(
  function (self, sceneParams)
    self.nextScene = sceneParams.nextScene

    self:load(sceneParams)
    self.winnerSFX = self.S1:pick_win_sfx()
  end,
  GameBase
)

Game2pVs.name = "Game2pVs"
sceneManager:addScene(Game2pVs)

function Game2pVs:processGameResults(gameResult)
  local extraPath, extraFilename = "", ""
  local rep_a_name, rep_b_name = self.match.players[1].name, self.match.players[2].name
    --sort player names alphabetically for folder name so we don't have a folder "a-vs-b" and also "b-vs-a"
    if rep_b_name < rep_a_name then
      extraPath = rep_b_name .. "-vs-" .. rep_a_name
    else
      extraPath = rep_a_name .. "-vs-" .. rep_b_name
    end
    extraFilename = extraFilename .. rep_a_name .. "-L" .. self.match.P1.level .. "-vs-" .. rep_b_name .. "-L" .. self.match.P2.level
    if match_type and match_type ~= "" then
      extraFilename = extraFilename .. "-" .. match_type
    end
    if not self.match.replay.incomplete then
      if self.match.replay.winnerIndex then
        extraFilename = extraFilename .. "-P" .. self.match.replay.winnerIndex .. "wins"
      else
        extraFilename = extraFilename .. "-draw"
      end
    end
  Replay.finalizeAndWriteReplay(extraPath, extraFilename, self.match.replay)
end

return Game2pVs