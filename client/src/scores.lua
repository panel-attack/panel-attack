local levelPresets = require("client.src.LevelPresets")
local fileUtils = require("client.src.FileUtils")
local class = require("common.lib.class")

-- 1 had only vs scores in an incompatible format
-- 2 has vs self, time attack, endless
local currentVersion = 2

-- Holds on the current scores and records for game modes
Scores =
  class(
  function(self)
    -- The lastly used version
    self.version = currentVersion

    self.vsSelf = {}
    for i = 1, levelPresets.modernPresetCount do
      self.vsSelf[i] = {}
      self.vsSelf[i]["record"] = 0
      self.vsSelf[i]["last"] = 0
    end

    self.timeAttack1P = {}
    for i = 1, levelPresets.classicPresetCount do
      self.timeAttack1P[i] = {}
      self.timeAttack1P[i]["record"] = 0
      self.timeAttack1P[i]["last"] = 0
    end

    self.endless = {}
    for i = 1, levelPresets.classicPresetCount do
      self.endless[i] = {}
      self.endless[i]["record"] = 0
      self.endless[i]["last"] = 0
    end
  end
)

function Scores.saveVsSelfScoreForLevel(self, score, level)
  self.vsSelf[level]["last"] = score
  if self.vsSelf[level]["record"] < score then
    self.vsSelf[level]["record"] = score
  end
  self:saveToFile()
end

function Scores.lastVsScoreForLevel(self, level)
  return self.vsSelf[level]["last"]
end

function Scores.recordVsScoreForLevel(self, level)
  return self.vsSelf[level]["record"]
end

function Scores.saveTimeAttack1PScoreForLevel(self, score, level)
  self.timeAttack1P[level]["last"] = score
  if self.timeAttack1P[level]["record"] < score then
    self.timeAttack1P[level]["record"] = score
  end
  self:saveToFile()
end

function Scores.lastTimeAttack1PForLevel(self, level)
  return self.timeAttack1P[level]["last"]
end

function Scores.recordTimeAttack1PForLevel(self, level)
  return self.timeAttack1P[level]["record"]
end

function Scores.saveEndlessScoreForLevel(self, score, level)
  self.endless[level]["last"] = score
  if self.endless[level]["record"] < score then
    self.endless[level]["record"] = score
  end
  self:saveToFile()
end

function Scores.lastEndlessForLevel(self, level)
  return self.endless[level]["last"]
end

function Scores.recordEndlessForLevel(self, level)
  return self.endless[level]["record"]
end

local function read_score_file()
  local scores = Scores()
  pcall(
    function()
      local read_data = fileUtils.readJsonFile("scores.json")
      if read_data then
        if read_data.version and type(read_data.version) == "number" then
          scores.version = read_data.version
        elseif read_data.vsSelf["last"] then
          scores.version = 1
        end

        -- Ignore the scores save file if its the old format
        if scores.version == 1 then
        elseif scores.version == currentVersion then
          if read_data.vsSelf then scores.vsSelf = read_data.vsSelf end
          if read_data.timeAttack1P then scores.timeAttack1P = read_data.timeAttack1P end
          if read_data.endless then scores.endless = read_data.endless end
        end
      end
    end
  )

  if scores.version == 1 then
    scores.version = currentVersion
    scores:saveToFile()
  end
  return scores
end

function Scores.saveToFile(self)
  if self.version == currentVersion then
    love.filesystem.write("scores.json", json.encode(self))
  end
end

local scores = read_score_file()

return scores