-- this file documents presets for level data
-- level data has the following format:
-- {
  -- the initial speed upon match start, defines how many frameConstantss it takes to rise one row via the SPEED_TO_RISE_TIME table
--   startingSpeed = 1,
  -- the mechanism through which speed increases throughout the game
  -- mode 1: in constant time intervals
  -- mode 2: depending on how many panels were cleared according to the PANELS_TO_NEXT_SPEED table
--   speedIncreaseMode = 1,
  -- how many blocks need to be cleared to queue the next shock panel for panel generation
--   shockFrequency = 12,
  -- how many shock panels can be queued at maximum; set to 0 to disable shock blocks
--   shockCap = 21,
  -- how many colors are used for panel generation
--   colors = 5,
  -- unconditional invincibility frameConstantss that run out while topped out with no other type of invincibility frameConstantss available
  -- may refill once no longer topped out
--   maxHealth = 121,
  -- the stop table contains constants for calculating the awarded stop time from chains and combos
--   stop = {
    -- the formula used for calculating stop time
--     formula = 1,
    -- formula 1 & 2: unconditional constant awarded for any combo while not topped out
--     comboConstant = -20,
    -- formula 1: unconditional constant awarded for any chain while not topped and any combo while topped out
    -- formula 2: unconditional constant awarded for any chain while not topped out
--     chainConstant = 80,
    -- formula 1: unconditional constant awarded for any chain while topped out
    -- formula 2: unconditional costant awarded for any combo or chain while topped out
--     dangerConstant = 160,
    -- formula 1: additional stoptime is provided upon meeting certain thresholds for chain length / combo size, both regular and topped out
    -- formula 2: does not use coefficients
--     coefficient = 20,
--   },
  -- the frameConstants table contains information relevant for panels physics
--   frameConstants = {
    -- for how long a panel stays above an empty space before falling down
--     HOVER = 12,
    -- for how long garbage panels are in hover state after popping
--     GARBAGE_HOVER = 41,
    -- for how long panels flash after being matched
--     FLASH = 44,
    -- for how long panels show their matched face after completing the flash (before the pop timers of the panels start)
    -- this may not be directly referenced in favor of a MATCH constant that equals FLASH + FACE (the total time a panel stays in matched state)
--     FACE = 20,
    -- how long it takes for 1 panel of a match to pop (go from popping to popped)
--     POP = 9
--   }
-- }


local modern = {}
modern[1] = {
  startingSpeed = 1,
  speedIncreaseMode = 1,
  shockFrequency = 12,
  shockCap = 21,
  colors = 5,
  maxHealth = 121,
  stop = {
    formula = 1,
    comboConstant = -20,
    chainConstant = 80,
    dangerConstant = 160,
    coefficient = 20,
    dangerCoefficient = 20,
  },
  frameConstants = {
    HOVER = 12,
    GARBAGE_HOVER = 41,
    FLASH = 44,
    FACE = 20,
    POP = 9
  }
}

modern[2] = {
  startingSpeed = 5,
  speedIncreaseMode = 1,
  shockFrequency = 14,
  shockCap = 18,
  colors = 5,
  maxHealth = 101,
  stop = {
    formula = 1,
    comboConstant = -16,
    chainConstant = 77,
    dangerConstant = 152,
    coefficient = 18,
    dangerCoefficient = 18,
  },
  frameConstants = {
    HOVER = 12,
    GARBAGE_HOVER = 36,
    FLASH = 44,
    FACE = 18,
    POP = 9
  }
}

modern[3] = {
  startingSpeed = 9,
  speedIncreaseMode = 1,
  shockFrequency = 16,
  shockCap = 18,
  colors = 5,
  maxHealth = 81,
  stop = {
    formula = 1,
    comboConstant = -12,
    chainConstant = 74,
    dangerConstant = 144,
    coefficient = 16,
    dangerCoefficient = 16,
  },
  frameConstants = {
    HOVER = 11,
    GARBAGE_HOVER = 31,
    FLASH = 42,
    FACE = 17,
    POP = 8
  }
}

modern[4] = {
  startingSpeed = 13,
  speedIncreaseMode = 1,
  shockFrequency = 19,
  shockCap = 15,
  colors = 5,
  maxHealth = 66,
  stop = {
    formula = 1,
    comboConstant = -8,
    chainConstant = 71,
    dangerConstant = 136,
    coefficient = 14,
    dangerCoefficient = 14,
  },
  frameConstants = {
    HOVER = 10,
    GARBAGE_HOVER = 26,
    FLASH = 42,
    FACE = 16,
    POP = 8
  }
}

modern[5] = {
  startingSpeed = 17,
  speedIncreaseMode = 1,
  shockFrequency = 23,
  shockCap = 15,
  colors = 5,
  maxHealth = 51,
  stop = {
    formula = 1,
    comboConstant = -3,
    chainConstant = 68,
    dangerConstant = 128,
    coefficient = 12,
    dangerCoefficient = 12,
  },
  frameConstants = {
    HOVER = 9,
    GARBAGE_HOVER = 21,
    FLASH = 38,
    FACE = 15,
    POP = 8
  }
}

modern[6] = {
  startingSpeed = 21,
  speedIncreaseMode = 1,
  shockFrequency = 26,
  shockCap = 12,
  colors = 5,
  maxHealth = 41,
  stop = {
    formula = 1,
    comboConstant = 2,
    chainConstant = 65,
    dangerConstant = 120,
    coefficient = 10,
    dangerCoefficient = 10,
  },
  frameConstants = {
    HOVER = 6,
    GARBAGE_HOVER = 16,
    FLASH = 36,
    FACE = 14,
    POP = 8
  }
}

modern[7] = {
  startingSpeed = 25,
  speedIncreaseMode = 1,
  shockFrequency = 29,
  shockCap = 9,
  colors = 5,
  maxHealth = 31,
  stop = {
    formula = 1,
    comboConstant = 7,
    chainConstant = 62,
    dangerConstant = 112,
    coefficient = 8,
    dangerCoefficient = 8,
  },
  frameConstants = {
    HOVER = 5,
    GARBAGE_HOVER = 13,
    FLASH = 34,
    FACE = 13,
    POP = 8
  }
}

modern[8] = {
  startingSpeed = 29,
  speedIncreaseMode = 1,
  shockFrequency = 33,
  shockCap = 6,
  colors = 5,
  maxHealth = 21,
  stop = {
    formula = 1,
    comboConstant = 12,
    chainConstant = 60,
    dangerConstant = 104,
    coefficient = 6,
    dangerCoefficient = 6,
  },
  frameConstants = {
    HOVER = 4,
    GARBAGE_HOVER = 10,
    FLASH = 32,
    FACE = 12,
    POP = 7
  }
}

modern[9] = {
  startingSpeed = 27,
  speedIncreaseMode = 1,
  shockFrequency = 37,
  shockCap = 6,
  colors = 6,
  maxHealth = 11,
  stop = {
    formula = 1,
    comboConstant = 17,
    chainConstant = 58,
    dangerConstant = 96,
    coefficient = 4,
    dangerCoefficient = 4,
  },
  frameConstants = {
    HOVER = 3,
    GARBAGE_HOVER = 7,
    FLASH = 30,
    FACE = 11,
    POP = 7
  }
}

modern[10] = {
  startingSpeed = 32,
  speedIncreaseMode = 1,
  shockFrequency = 41,
  shockCap = 3,
  colors = 6,
  maxHealth = 1,
  stop = {
    formula = 1,
    comboConstant = 22,
    chainConstant = 56,
    dangerConstant = 88,
    coefficient = 2,
    dangerCoefficient = 2,
  },
  frameConstants = {
    HOVER = 6,
    GARBAGE_HOVER = 4,
    FLASH = 28,
    FACE = 10,
    POP = 7
  }
}

modern[11] = {
  startingSpeed = 45,
  speedIncreaseMode = 1,
  shockFrequency = 18,
  shockCap = 3,
  colors = 6,
  maxHealth = 1,
  stop = {
    formula = 1,
    comboConstant = 27,
    chainConstant = 53,
    dangerConstant = 80,
    coefficient = 1,
    dangerCoefficient = 0,
  },
  frameConstants = {
    HOVER = 3,
    GARBAGE_HOVER = 3,
    FLASH = 22,
    FACE = 8,
    POP = 6
  }
}

local classic = {}
classic.easy = {
  startingSpeed = 1,
  speedIncreaseMode = 2,
  shockFrequency = 18,
  -- no metal panels in classic mode
  shockCap = 0,
  colors = 6,
  maxHealth = 1,
  stop = {
    formula = 2,
    comboConstant = 120,
    chainConstant = 300,
    dangerConstant = 600,
    coefficient = 0,
    dangerCoefficient = 0,
  },
  frameConstants = {
    HOVER = 12,
    -- made up number, classic has no garbage
    -- GARBAGE_HOVER = 36,
    FLASH = 44,
    FACE = 17,
    POP = 9
  }
}
classic[1] = classic.easy

classic.normal = {
  startingSpeed = 1,
  speedIncreaseMode = 2,
  shockFrequency = 18,
  -- no metal panels in classic mode
  shockCap = 0,
  -- game prep code and replay loading code needs to check for game mode and override
  -- endless has only 5 colors on the lowest classic difficulty
  colors = 6,
  maxHealth = 1,
  stop = {
    formula = 2,
    comboConstant = 120,
    chainConstant = 180,
    dangerConstant = 420,
    coefficient = 0,
    dangerCoefficient = 0,
  },
  frameConstants = {
    HOVER = 9,
    -- made up number, classic has no garbage
    -- GARBAGE_HOVER = 21,
    FLASH = 36,
    FACE = 13,
    POP = 8
  }
}
classic[2] = classic.normal

classic.hard = {
  startingSpeed = 1,
  speedIncreaseMode = 2,
  shockFrequency = 18,
  -- no metal panels in classic mode
  shockCap = 0,
  colors = 6,
  maxHealth = 1,
  stop = {
    formula = 2,
    comboConstant = 120,
    chainConstant = 120,
    dangerConstant = 240,
    coefficient = 0,
    dangerCoefficient = 0,
  },
  frameConstants = {
    HOVER = 6,
    -- made up number, classic has no garbage
    -- GARBAGE_HOVER = 4,
    FLASH = 22,
    FACE = 15,
    POP = 7
  }
}
classic[3] = classic.hard

classic.ex = {
  startingSpeed = 1,
  speedIncreaseMode = 2,
  shockFrequency = 18,
  -- no metal panels in classic mode
  shockCap = 0,
  colors = 6,
  maxHealth = 1,
  stop = {
    formula = 2,
    comboConstant = 90,
    chainConstant = 90,
    dangerConstant = 180,
    coefficient = 0,
  },
  frameConstants = {
    HOVER = 3,
    -- made up number, classic has no garbage
    -- GARBAGE_HOVER = 3,
    FLASH = 16,
    FACE = 10,
    POP = 6
  }
}
classic[4] = classic.ex

local LevelPresets = {}

-- returns a deepcopy of the modern preset
function LevelPresets.getModern(level)
  assert(modern[level], "trying to load inexistent level preset" .. level)
  return deepcpy(modern[level])
end

LevelPresets.modernPresetCount = #modern

function LevelPresets.getClassic(difficulty)
  assert(classic[difficulty], "trying to load inexistent difficulty preset" .. difficulty)
  return deepcpy(classic[difficulty])
end

LevelPresets.classicPresetCount = #classic

return LevelPresets