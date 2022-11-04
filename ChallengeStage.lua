local logger = require("logger")
require("health")

-- Challenge Stage is a particular stage in challenge mode.
ChallengeStage =
  class(
  function(self, stageNumber, secondsToppedOutToLose, lineClearGPM, lineHeightToKill, riseDifficulty)
    self.stageNumber = stageNumber
    self.secondsToppedOutToLose = secondsToppedOutToLose
    self.lineClearGPM = lineClearGPM
    self.lineHeightToKill = lineHeightToKill
    self.riseDifficulty = riseDifficulty
    self.expendedTime = 0
  end
)


function ChallengeStage:createHealth()
  return Health(self.secondsToppedOutToLose, self.lineClearGPM, self.lineHeightToKill, self.riseDifficulty)
end
