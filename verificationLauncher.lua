-- HOW TO USE:
-- this verification launcher can be used as an arg to love
-- it runs through all replays under the specified VERIFICATION_PATH inside the save directory
-- replays that do not finish as expected* are copied into the OUTPUT directory
-- the idea is to use bulks of replays to verify that older replays still run as intended
--   after engine modifications that were supposed to be physics neutral
-- these replays should be sourced from the SERVER https://drive.google.com/drive/folders/1xJwrS3PRjuzOdYSsd7qroHUQSCQKuVXV?usp=sharing
-- The server only saves replays if both clients reported the same result
-- meaning there is a high degree of confidence they are not corrupted via experimental clients by developers

-- replays are deleted after verification so that only faulty ones are left
-- at the end, a json is written with additional annotations why each replay failed:
--   a winner index of 0 means the game did not end after exhausting the inputs
--   a shorter duration means the game ended earlier than it should have
--   a different winner index means the winner differed somehow although it finished in the expected time

-- * it's not entirely certain if the current criteria is enough to really catch all possible divergences but it should be significant enough
--   by testing enough replays e.g. an entire month it should be possible to find at least one replay that exhibits misbehaviour to indicate a problem


local VERIFICATION_PATH = "replays/verifier/2024/04/01"
local OUTPUT = "problematicReplays"
-- override the replay version of the used replays
-- this is a crutch because server replays never saved the engine version in the replay
-- and there is a countdown fix in engine code specifically referencing v046 that can lead to issues
local ENGINE_VERSION_OVERRIDE = "047"

require("common.lib.mathExtensions")
local util = require("common.lib.util")
util.addToCPath("./common/lib/??")
util.addToCPath("./server/lib/??")
local logger = require("common.lib.logger")
require("client.src.globals")
local Game = require("client.src.Game")
local verifier = require("common.tests.engine.IntegrityVerification")
local cr = coroutine.create(verifier.bulkVerifyReplays)

function love.load()
  -- this is necessary setup of globals while non-client tests still depend on client components
  GAME = Game()
  GAME:load()

  local cr = coroutine.create(GAME.setupRoutine)
  while coroutine.status(cr) ~= "dead" do
    local success, status = coroutine.resume(cr, GAME)
    if not success then
      GAME.crashTrace = debug.traceback(cr)
      error(status)
    end
  end

  GAME.muteSound = true

  if not love.filesystem.exists(OUTPUT) then
    love.filesystem.createDirectory(OUTPUT)
  end

  verifier.overrideEngineVersion(ENGINE_VERSION_OVERRIDE)
end

function love.update()
  if coroutine.status(cr) ~= "dead" then
    coroutine.resume(cr, VERIFICATION_PATH, OUTPUT)
  else
    love.filesystem.write(OUTPUT .. "/faulty.json", json.encode(verifier.faulty))
    love.event.quit(0)
  end
end

function love.draw()
  love.graphics.print("Processed " .. verifier.processed .. " replays with " .. #verifier.faulty .. " problems", 10, 10)
end