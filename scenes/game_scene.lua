local Scene = require("scenes.Scene")
local replay_browser = require("replay_browser")
local logger = require("logger")
local select_screen = require("select_screen")
local options = require("options")
local utf8 = require("utf8")
local analytics = require("analytics")
local main_config_input = require("config_inputs")
local ServerQueue = require("ServerQueue")
local Button = require("ui.Button")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local LevelSlider = require("ui.LevelSlider")
local Label = require("ui.Label")
local scene_manager = require("scenes.scene_manager")
local input = require("input2")
local util = require("util")
local save = require("save")
local table_utils = require("table_utils")

--@module MainMenu
local game_scene = Scene("game_scene")

function game_scene:init()
  scene_manager:addScene(game_scene)
end

local abort_game = false

function game_scene:load()
  leftover_time = 1 / 120
  abort_game = false
end

local function pick_random_stage()
  current_stage = table.getRandomElement(stages_ids_for_current_theme)
  if stages[current_stage]:is_bundle() then -- may pick a bundle!
    current_stage = table.getRandomElement(stages[current_stage].sub_stages)
  end
end

local function use_current_stage()
  if current_stage == nil then
    pick_random_stage()
  end
  
  stage_loader_load(current_stage)
  stage_loader_wait()
  GAME.backgroundImage = stages[current_stage].images.background
  GAME.background_overlay = themes[config.theme].images.bg_overlay
  GAME.foreground_overlay = themes[config.theme].images.fg_overlay
end

local function handle_pause()
  if GAME.match.supportsPause then
    if input.isDown["Start"] or (not GAME.focused and not GAME.gameIsPaused) then
      GAME.gameIsPaused = not GAME.gameIsPaused

      setMusicPaused(GAME.gameIsPaused)

      if not GAME.renderDuringPause then
        if GAME.gameIsPaused then
          reset_filters()
        else
          use_current_stage()
        end
      end
    end
  end
end

local function finalizeAndWriteReplay(extraPath, extraFilename)
  replay[GAME.match.mode].in_buf = P1.confirmedInput

  local now = os.date("*t", to_UTC(os.time()))
  local sep = "/"
  local path = "replays" .. sep .. "v" .. VERSION .. sep .. string.format("%04d" .. sep .. "%02d" .. sep .. "%02d", now.year, now.month, now.day)
  if extraPath then
    path = path .. sep .. extraPath
  end
  local filename = "v" .. VERSION .. "-" .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)
  if extraFilename then
    filename = filename .. "-" .. extraFilename
  end
  filename = filename .. ".txt"
  save.write_replay_file()
  logger.info("saving replay as " .. path .. sep .. filename)
  save.write_replay_file(path, filename)
end

local function processGameResults(gameResult) 
  local extraPath, extraFilename
  local stack = P1
  if stack.level == nil then
    if GAME.match.mode == "endless" then
      GAME.scores:saveEndlessScoreForLevel(P1.score, P1.difficulty)
      extraPath = "Endless"
      extraFilename = "Spd" .. stack.speed .. "-Dif" .. stack.difficulty .. "-endless"
    elseif GAME.match.mode == "time" then
      GAME.scores:saveTimeAttack1PScoreForLevel(P1.score, P1.difficulty)
      extraPath = "Time Attack"
      extraFilename = "Spd" .. stack.speed .. "-Dif" .. stack.difficulty .. "-timeattack"
    end
    finalizeAndWriteReplay(extraPath, extraFilename)
  end

  --return {game_over_transition, {nextFunction, nil, P1:pick_win_sfx()}}
end

local t = 0 -- the amount of frames that have passed since the game over screen was displayed
local font = love.graphics.getFont()
local timemin = 60 -- the minimum amount of frames the game over screen will be displayed for
local timemax = -1
local text = ""
local keep_music = false
local winnerTime = 60
local initialMusicVolumes = {}
local winnerSFX

local function setupGameOver()
  --timemax = timemax or -1 -- negative values means the user needs to press enter/escape to continue
  --text = text or ""
  --keepMusic = keepMusic or false
  --local button_text = loc("continue_button") or ""
  
  t = 0 -- the amount of frames that have passed since the game over screen was displayed
  timemin = 60 -- the minimum amount of frames the game over screen will be displayed for
  timemax = -1
  keep_music = false
  winnerTime = 60
  initialMusicVolumes = {}
  winnerSFX = P1:pick_win_sfx()

  if SFX_GameOver_Play == 1 then
    themes[config.theme].sounds.game_over:play()
    SFX_GameOver_Play = 0
  else
    winnerTime = 0
  end

  -- The music may have already been partially faded due to dynamic music or something else,
  -- record what volume it was so we can fade down from that.
  for k, v in pairs(currently_playing_tracks) do
    initialMusicVolumes[v] = v:getVolume()
  end
end

local function runGameOver()
  gprint(text, (canvas_width - font:getWidth(text)) / 2, 10)
  gprint(loc("continue_button"), (canvas_width - font:getWidth(loc("continue_button"))) / 2, 10 + 30)
  -- wait()
  local ret = nil
  if not keep_music then
    -- Fade the music out over time
    local fadeMusicLength = 3 * 60
    if t <= fadeMusicLength then
      local percentage = (fadeMusicLength - t) / fadeMusicLength
      for k, v in pairs(initialMusicVolumes) do
        local volume = v * percentage
        setFadePercentageForGivenTracks(volume, {k}, true)
      end
    else
      if t == fadeMusicLength + 1 then
        setMusicFadePercentage(1) -- reset the music back to normal config volume
        stop_the_music()
      end
    end
  end

  -- Play the winner sound effect after a delay
  if not SFX_mute then
    if t >= winnerTime then
      if winnerSFX ~= nil then -- play winnerSFX then nil it so it doesn't loop
        winnerSFX:play()
        winnerSFX = nil
      end
    end
  end

  GAME.match:run()


  if network_connected() then
    do_messages() -- recieve messages so we know if the next game is in the queue
  end

  local left_select_menu = false -- Whether a message has been sent that indicates a match has started or the room has closed
  if this_frame_messages then
    for _, msg in ipairs(this_frame_messages) do
      -- if a new match has started or the room is being closed, flag the left select menu variavle
      if msg.match_start or replay_of_match_so_far or msg.leave_room then
        left_select_menu = true
      end
    end
  end

  -- if conditions are met, leave the game over screen
  local key_pressed = table_utils.trueForAny(input.isDown, function(key) return key end)
  if t >= timemin and ((t >= timemax and timemax >= 0) or key_pressed) or left_select_menu then
    play_optional_sfx(themes[config.theme].sounds.menu_validate)
    setMusicFadePercentage(1) -- reset the music back to normal config volume
    if not keep_music then
      stop_the_music()
    end
    SFX_GameOver_Play = 0
    analytics.game_ends(P1.analytic)
    scene_manager:switchScene("endless_menu")
  end
  t = t + 1
  
  GAME.match:render()
end

local function runGame()
  GAME.match:run()
  if not ((P1 and P1.play_to_end) or (P2 and P2.play_to_end)) then
    handle_pause()

    if GAME.gameIsPaused and input.isDown["Swap2"] then
      -- returnFunction = abortGameFunction()
      scene_manager:switchScene("endless_menu")
      abort_game = true
    end
  end

  if abort_game then
    return
  end
  
  gameResult = P1:gameResult()
  if gameResult then
    --scene_manager:switchScene("endless_menu")
    setupGameOver()
    return
  end
  
  -- Render only if we are not catching up to a current spectate match
  if not (P1 and P1.play_to_end) and not (P2 and P2.play_to_end) then
    GAME.match:render()
  end

  --[[
  if not returnFunction then
    local gameResult = P1:gameResult()
    if gameResult then
      returnFunction = processGameResultsFunction(gameResult)
    end
  end
  --]]
  
  

  --[[
  if returnFunction then
    undo_stonermode()
    return unpack(returnFunction)
  end
  --]]
end

function game_scene:update()
  local gameResult = P1:gameResult()
  if gameResult then
    runGameOver()
  else
    runGame()
  end
  -- local returnFunction = nil
  -- Uncomment this to cripple your game :D
  -- love.timer.sleep(0.030)

  --returnFunction = updateFunction()
  --if returnFunction then 
  --  return unpack(returnFunction)
  --end
  
  
end


function game_scene:unload()
  local gameResult = P1:gameResult()
  if gameResult then
    processGameResults(gameResult)
  end
  GAME:clearMatch()
end

return game_scene