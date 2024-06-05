local consts = require("common.engine.consts")
local tableUtils = require("common.lib.tableUtils")
local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local GameModes = require("common.engine.GameModes")
local logger = require("common.lib.logger")

local testReplayFolder = "common/tests/engine/replays/"

local function test(func)
  func()
end

-- Swap finishing the frame chaining is applied should not apply to swapped panel
local function testChainingPropagationThroughSwap1()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v047-2023-03-20-03-39-20-PDR_Lava-L10-vs-JamBox-L8-Casual-INCOMPLETE.json")

  StackReplayTestingUtils:simulateMatchUntil(match, 3162)
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TOUCH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.stacks[2].panels[4][5].chaining == nil)
  assert(not match.stacks[2].panels[4][5].matchAnyway)
  assert(match.stacks[2].panels[5][5].chaining == true)
  assert(match.stacks[2].panels[5][5].matchAnyway == true)
  StackReplayTestingUtils:cleanup(match)
end

local function testHoverInheritanceOverSwapOverGarbageHover()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "swapOverGarbageHoverInheritance.json")

  StackReplayTestingUtils:simulateMatchUntil(match, 9028)
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TOUCH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.stacks[2].panels[8][4].state == "hovering")
  -- hovering above garbage, timer should be GPHOVER (on level 8 -> 10 frames)
  assert(match.stacks[2].panels[8][4].timer == 10)
  assert(match.stacks[2].panels[9][4].state == "swapping")
  assert(match.stacks[2].panels[9][4].timer == 3)
  assert(match.stacks[2].panels[10][4].state == "hovering")
  -- 10 frames GPHover + 3 frames left from the swap
  assert(match.stacks[2].panels[10][4].timer == 13)
  StackReplayTestingUtils:cleanup(match)
end

local function testFirstHoverFrameMatch()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "firstHoverFrameMatchReplay.json")
  StackReplayTestingUtils:simulateMatchUntil(match, 4269)
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TOUCH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.stacks[1].panels[4][4].state == "hovering")
  assert(match.stacks[1].panels[4][4].chaining == true)
  StackReplayTestingUtils:simulateMatchUntil(match, 4270)
  assert(match.stacks[1].panels[4][4].state == "matched")
  assert(match.stacks[1].panels[4][4].chaining ~= true)
  -- for this specific replay, the match combines with another one to form a +6
  assert(match.stacks[1].combos[4269][1].width == 5)
  StackReplayTestingUtils:cleanup(match)
end

local function testHoverChainOverGarbageClear()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "hoverChainOverGarbageClearReplay.json")
  StackReplayTestingUtils:simulateMatchUntil(match, 3073)
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TOUCH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.stacks[1].panels[5][4].state == "hovering")
  assert(match.stacks[1].panels[5][4].chaining == true)
  assert(match.stacks[1].panels[5][4].matchAnyway == false, "Panels starting to hover above fully cleared garbage don't match on their first hoverframe")
  assert(match.stacks[1].panels[6][4].state == "hovering")
  assert(match.stacks[1].panels[6][4].chaining == true)
  assert(match.stacks[1].panels[6][4].matchAnyway == false, "Panels starting to hover above fully cleared garbage don't match on their first hoverframe")
  assert(match.stacks[1].panels[7][4].state == "hovering")
  assert(not match.stacks[1].panels[7][4].chaining, "The panel came out of a swap without chaining before so it can't be chaining")
  assert(match.stacks[1].panels[7][4].matchAnyway == false, "Panels starting to hover above fully cleared garbage don't match on their first hoverframe")
  assert(match.stacks[1].panels[8][4].state == "hovering")
  assert(match.stacks[1].panels[8][4].chaining == true)
  assert(match.stacks[1].panels[8][4].matchAnyway == false, "Panels starting to hover above fully cleared garbage don't match on their first hoverframe")
  StackReplayTestingUtils:simulateMatchUntil(match, 3081)
  assert(match.stacks[1].chains[match.stacks[1].currentChainStartFrame].size == 3, "We should've gotten a +4 x3 on this frame")
  assert(match.stacks[1].combos[3080][1] ~= nil and match.stacks[1].combos[3080][1].width == 3, "We should've gotten a +4 x3 on this frame")
  StackReplayTestingUtils:simulateMatchUntil(match, 3272)
  assert(match.stacks[2]:game_ended() == true, "P2 should have died here")
  StackReplayTestingUtils:cleanup(match)
end

local function horizontalSwapIntoHoverTest()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "sideBySideSwapIntoHoverReplay.json")
  StackReplayTestingUtils:simulateMatchUntil(match, 4220)
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TOUCH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.stacks[2].panels[4][4].state == "hovering")
  assert(match.stacks[2].panels[4][4].chaining)
  assert(match.stacks[2].panels[5][4].state == "hovering")
  assert(not match.stacks[2].panels[5][4].chaining, "panel just finished a swap on the same frame hover was applied, therefore it should not be chaining")
  assert(match.stacks[2].panels[6][4].state == "hovering")
  assert(match.stacks[2].panels[6][4].chaining)
  StackReplayTestingUtils:simulateMatchUntil(match, 4221)
  -- matching on the first hover frame, chaining flag should get reset without increasing chain counter
  assert(match.stacks[2].panels[4][4].state == "matched")
  assert(not match.stacks[2].panels[4][4].chaining)
  assert(match.stacks[2].panels[5][4].state == "matched")
  assert(not match.stacks[2].panels[5][4].chaining)
  assert(match.stacks[2].panels[6][4].state == "matched")
  assert(not match.stacks[2].panels[6][4].chaining)
  assert(match.stacks[2].chain_counter == 2)
  StackReplayTestingUtils:simulateMatchUntil(match, 4228)
  assert(match.stacks[2].chain_counter == 0, "chain counter should reset here as all other falling panels lost their chaining status by now")
  StackReplayTestingUtils:cleanup(match)
end

local function basicEndlessTest()
  local match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v046-2023-01-30-00-35-24-Spd1-Dif3-endless.txt")
  assert(match ~= nil)
  assert(match.stackInteraction == GameModes.StackInteractions.NONE)
  assert(match.timeLimit == nil)
  assert(tableUtils.length(match.winConditions) == 0)
  assert(match.seed == 7161965)
  assert(match.stacks[1].game_over_clock == 402)
  assert(match.stacks[1].levelData.maxHealth == 1)
  assert(match.stacks[1].score == 37)
  assert(match.stacks[1].difficulty == 3)
  StackReplayTestingUtils:cleanup(match)
end

local function basicTimeAttackTest()
  local match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v046-2022-09-12-04-02-30-Spd11-Dif1-timeattack.txt")
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.NONE)
  assert(match.timeLimit ~= nil)
  assert(tableUtils.length(match.winConditions) == 0)
  assert(match.seed == 3490465)
  assert(match.stacks[1].game_stopwatch == 7200)
  assert(match.stacks[1].levelData.maxHealth == 1)
  assert(match.stacks[1].score == 10353)
  assert(match.stacks[1].difficulty == 1)
  assert(tableUtils.length(match.stacks[1].chains) == 8)
  assert(tableUtils.length(match.stacks[1].combos) == 4)
  StackReplayTestingUtils:cleanup(match)
end

local function basicVsTest()
  local match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.seed == 2992240)
  assert(match.stacks[1].game_over_clock == 2039)
  assert(match.stacks[1].level == 10)
  assert(tableUtils.length(match.stacks[1].chains) == 4)
  assert(tableUtils.length(match.stacks[1].combos) == 4)
  assert(match.stacks[2].game_over_clock <= 0)
  assert(match.stacks[2].level == 10)
  assert(tableUtils.length(match.stacks[2].chains) == 4)
  assert(tableUtils.length(match.stacks[2].combos) == 4)
  local winners = match:getWinners()
  assert(#winners == 1)
  assert(winners[1].playerNumber == 2)
  StackReplayTestingUtils:cleanup(match)
end

--the above replay did not succeed in throwing errors for some of the bugs I coded in during the checkMatches refactor
--namely a color override issue where the transforming garbage panel had colors assigned more than once, leading to different panels
--secondly an issue where the y_offset for offscreen chain garbage wasn't updated causing the bottom line of chain garbage to not convert into panels
local function basicVsTest2()
  local match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v046-2023-02-26-02-44-49-Endaris-L10-vs-z26PingMeDiscord-L10-Casual-P1wins.json")
  assert(match ~= nil)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.seed == 9285831)
  assert(match.stacks[1].game_over_clock == 3394)
  assert(match.stacks[1].level == 10)
  assert(tableUtils.length(match.stacks[1].chains) == 7)
  assert(tableUtils.length(match.stacks[1].combos) == 8)
  assert(match.stacks[2].game_over_clock <= 0)
  assert(match.stacks[2].level == 10)
  assert(tableUtils.length(match.stacks[2].chains) == 5)
  assert(tableUtils.length(match.stacks[2].combos) == 8)
  local winners = match:getWinners()
  assert(#winners == 1)
  assert(winners[1].playerNumber == 2)
  StackReplayTestingUtils:cleanup(match)
end

local function noInputsInVsIsDrawTest()
  local match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v046-2023-01-30-22-27-36-Player 1-L10-vs-Player 2-L10-draw.txt")
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.seed == 1866552)
  assert(match.stacks[1].game_over_clock == 908)
  assert(match.stacks[1].level == 10)
  assert(tableUtils.length(match.stacks[1].chains) == 0)
  assert(tableUtils.length(match.stacks[1].combos) == 0)
  assert(match.stacks[2].game_over_clock == 908)
  assert(match.stacks[2].level == 10)
  assert(tableUtils.length(match.stacks[2].chains) == 0)
  assert(tableUtils.length(match.stacks[2].combos) == 0)
  local winners = match:getWinners()
  assert(#winners == 2)
  StackReplayTestingUtils:cleanup(match)
end

-- Tests a bunch of different frame specific tricks and makes sure we still end at the expected time.
-- In the future we should probably expand this to testing each specific trick and making sure the board changes correctly.
local function frameTricksTest()
  local match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v046-2023-01-07-16-37-02-Spd10-Dif3-endless.txt")
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.NONE)
  assert(match.timeLimit == nil)
  assert(tableUtils.length(match.winConditions) == 0)
  assert(match.seed == 9399683)
  assert(match.stacks[1].game_over_clock == 10032)
  assert(match.stacks[1].difficulty == 3)
  assert(tableUtils.length(match.stacks[1].chains) == 13)
  assert(tableUtils.length(match.stacks[1].combos) == 7)
  StackReplayTestingUtils:cleanup(match)
end

-- Tests a catch that also did a "sync" (two separate matches on the same frame)
local function catchAndSyncTest()
  local match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v046-2023-01-31-08-57-51-Galadic97-L10-vs-iTSMEJASOn-L8-Casual-P1wins.txt")
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.seed == 8739468)
  assert(match.stacks[1].game_over_clock <= 0)
  assert(match.stacks[1].level == 10)
  assert(tableUtils.length(match.stacks[1].chains) == 4)
  assert(tableUtils.length(match.stacks[1].combos) == 6)
  assert(match.stacks[2].game_over_clock == 2431)
  assert(match.stacks[2].level == 8)
  assert(tableUtils.length(match.stacks[2].chains) == 2)
  assert(tableUtils.length(match.stacks[2].combos) == 2)
  local winners = match:getWinners()
  assert(#winners == 1)
  assert(winners[1].playerNumber == 1)
  StackReplayTestingUtils:cleanup(match)
end

-- Moving the cursor before ready is done
-- Prior to the touch builds, you couldn't move the cursor before it was in position
-- Thus we need to make sure we don't allow moving in replays before touch
local function movingBeforeInPositionDisallowedPriorToTouch()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-02-11-23-29-43-Newsy-L8-vs-ilikebeingsmart-L8-Casual-P2wins.txt")

  StackReplayTestingUtils:simulateMatchUntil(match, 10)
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.stacks[1].cur_row == 11)
  assert(match.stacks[1].cur_col == 5)

  StackReplayTestingUtils:simulateMatchUntil(match, 15)
  assert(match.stacks[1].cur_row == 10)
  assert(match.stacks[1].cur_col == 5)

  StackReplayTestingUtils:simulateMatchUntil(match, 19)
  assert(match.stacks[1].cur_row == 9)
  assert(match.stacks[1].cur_col == 5)

  StackReplayTestingUtils:simulateMatchUntil(match, 23)
  assert(match.stacks[1].cur_row == 8)
  assert(match.stacks[1].cur_col == 5)

  StackReplayTestingUtils:simulateMatchUntil(match, 27)
  assert(match.stacks[1].cur_row == 7)
  assert(match.stacks[1].cur_col == 5)

  StackReplayTestingUtils:simulateMatchUntil(match, 31)
  assert(match.stacks[1].cur_row == 7)
  assert(match.stacks[1].cur_col == 4)

  StackReplayTestingUtils:simulateMatchUntil(match, 35)
  assert(match.stacks[1].cur_row == 7)
  assert(match.stacks[1].cur_col == 3)

  -- Make sure the user can move now
  StackReplayTestingUtils:simulateMatchUntil(match, 60)
  assert(match.stacks[1].cur_row == 6)
  assert(match.stacks[1].cur_col == 3)
  StackReplayTestingUtils:cleanup(match)
end

-- Test that down stacking under garbage makes everything fall even if panels are sandwiched between.
local function downStackDropsSandwichedGarbageAllTogether()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "downStackDropsSandwichedGarbageAllTogether.txt")

  StackReplayTestingUtils:simulateMatchUntil(match, 4668)
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.seed == 1123596)
  assert(match.stacks[1].level == 8)
  assert(match.stacks[2].level == 8)
  assert(match.stacks[2].panels[4][4].state == "normal")
  assert(match.stacks[2].panels[4][4].isGarbage == false)
  assert(match.stacks[2].panels[5][4].state == "normal")
  assert(match.stacks[2].panels[5][4].isGarbage == true)
  assert(match.stacks[2].panels[9][4].state == "normal")
  assert(match.stacks[2].panels[9][4].isGarbage == true)
  
  -- After swapping out the panel, the garbage, panels and more garbage should all drop
  StackReplayTestingUtils:simulateMatchUntil(match, 4669)
  assert(match.stacks[2].panels[4][4].state == "falling")
  assert(match.stacks[2].panels[4][4].isGarbage == true)
  assert(match.stacks[2].panels[5][4].state == "falling")
  assert(match.stacks[2].panels[5][4].isGarbage == false)
  assert(match.stacks[2].panels[8][4].state == "falling")
  assert(match.stacks[2].panels[8][4].isGarbage == true)
  StackReplayTestingUtils:cleanup(match)
end

-- Test that a match that touches metal and a garbage block that also matches the metal still clears the whole metal
local function matchMetalAndGarbageClearsAllMetalTest()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "matchMetalAndGarbageClearsAllMetal.txt")

  StackReplayTestingUtils:simulateMatchUntil(match, 7274)
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.seed == 6141756)
  assert(match.stacks[1].level == 5)
  assert(match.stacks[2].level == 5)
  assert(match.stacks[1].panels[6][3].state == "normal")
  assert(match.stacks[1].panels[6][3].isGarbage == true)
  assert(match.stacks[1].panels[6][3].metal == nil)
  assert(match.stacks[1].panels[7][3].state == "normal")
  assert(match.stacks[1].panels[7][3].isGarbage == true)
  assert(match.stacks[1].panels[7][3].metal == true)
  
  -- Note the panels raised up one in the mean time
  -- But we now expect the panels to be matched
  StackReplayTestingUtils:simulateMatchUntil(match, 7341)
  assert(match.stacks[1].panels[7][3].state == "matched")
  assert(match.stacks[1].panels[8][1].state == "matched")
  assert(match.stacks[1].panels[8][2].state == "matched")
  assert(match.stacks[1].panels[8][3].state == "matched")
  assert(match.stacks[1].panels[8][4].state == "matched")
  assert(match.stacks[1].panels[8][5].state == "matched")
  assert(match.stacks[1].panels[8][6].state == "matched")
  StackReplayTestingUtils:cleanup(match)
end

-- Test that a panel that is still falling when it starts hovering doesn't get the chain flag.
-- I believe the reasoning behind this is it wasn't "established" enough to count as a chain.
local function fallingWhileHoverBeginsDoesNotChain()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "fallingWhileHoverBeginsDoesNotChain.txt")

  StackReplayTestingUtils:simulateMatchUntil(match, 5571)
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.seed == 5439756)
  assert(match.stacks[1].level == 10)
  assert(match.stacks[2].level == 10)
  assert(match.stacks[2].panels[8][3].state == "falling")
  assert(match.stacks[2].panels[8][3].isGarbage == false)
  assert(match.stacks[2].panels[8][3].chaining == nil)
  assert(match.stacks[2].panels[7][3].state == "normal")
  assert(match.stacks[2].panels[7][3].isGarbage == false)
  assert(match.stacks[2].panels[7][3].chaining == nil)
  
  -- if panels started hovering while a panel was still falling, it doesn't get the chain flag
  StackReplayTestingUtils:simulateMatchUntil(match, 5572)
  assert(match.stacks[2].panels[8][3].state == "hovering")
  assert(match.stacks[2].panels[8][3].isGarbage == false)
  assert(match.stacks[2].panels[8][3].chaining == nil)
  assert(match.stacks[2].panels[7][3].state == "hovering")
  assert(match.stacks[2].panels[7][3].isGarbage == false)
  assert(match.stacks[2].panels[7][3].chaining == true)
  StackReplayTestingUtils:cleanup(match)
end

logger.info("running basicTimeAttackTest")
test(basicTimeAttackTest)

logger.info("running testChainingPropagationThroughSwap1")
test(testChainingPropagationThroughSwap1)

logger.info("running testHoverInheritanceOverSwapOverGarbageHover")
test(testHoverInheritanceOverSwapOverGarbageHover)

logger.info("running testFirstHoverFrameMatch")
test(testFirstHoverFrameMatch)

logger.info("running testHoverChainOverGarbageClear")
test(testHoverChainOverGarbageClear)

logger.info("running horizontalSwapIntoHoverTest")
test(horizontalSwapIntoHoverTest)

logger.info("running basicEndlessTest")
test(basicEndlessTest)

logger.info("running basicVsTest")
test(basicVsTest)

logger.info("running basicVsTest2")
test(basicVsTest2)

logger.info("running noInputsInVsIsDrawTest")
test(noInputsInVsIsDrawTest)

logger.info("running frameTricksTest")
test(frameTricksTest)

logger.info("running catchAndSyncTest")
test(catchAndSyncTest)

logger.info("running movingBeforeInPositionDisallowedPriorToTouch")
test(movingBeforeInPositionDisallowedPriorToTouch)

logger.info("running downStackDropsSandwichedGarbageAllTogether")
test(downStackDropsSandwichedGarbageAllTogether)

logger.info("running matchMetalAndGarbageClearsAllMetalTest")
test(matchMetalAndGarbageClearsAllMetalTest)

logger.info("running fallingWhileHoverBeginsDoesNotChain")
test(fallingWhileHoverBeginsDoesNotChain)