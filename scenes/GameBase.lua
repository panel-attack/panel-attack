local Scene = require("scenes.Scene")
local replay_browser = require("replay_browser")
local logger = require("logger")
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
local consts = require("consts")

--@module MainMenu
local GameBase = class(
  function (self, name, options)
    self.name = name
    self.abort_game = false
    self.text = ""
    self.winner_SFX = nil
    self.keep_music = false
    self.current_stage = config.stage
  end,
  Scene
)

-- abstract functions
function GameBase:processGameResults(gameResult) end

function GameBase:customLoad(scene_params) end

function GameBase:abortGame() end

function GameBase:customRun() end

function GameBase:customGameOverSetup() end
-- end abstract functions

function GameBase:init()
  scene_manager:addScene(self)
end

function GameBase:finalizeAndWriteReplay(extraPath, extraFilename)
  replay[GAME.match.mode].in_buf = GAME.match.P1.confirmedInput

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

function GameBase:finalizeAndWriteVsReplay(battleRoom, outcome_claim, incompleteGame)

  incompleteGame = incompleteGame or false
  
  local extraPath, extraFilename
  if GAME.match.P2 then
    replay[GAME.match.mode].I = GAME.match.P2.confirmedInput

    local rep_a_name, rep_b_name = battleRoom.playerNames[1], battleRoom.playerNames[2]
    --sort player names alphabetically for folder name so we don't have a folder "a-vs-b" and also "b-vs-a"
    if rep_b_name < rep_a_name then
      extraPath = rep_b_name .. "-vs-" .. rep_a_name
    else
      extraPath = rep_a_name .. "-vs-" .. rep_b_name
    end
    extraFilename = rep_a_name .. "-L" .. GAME.match.P1.level .. "-vs-" .. rep_b_name .. "-L" .. GAME.match.P2.level
    if match_type and match_type ~= "" then
      extraFilename = extraFilename .. "-" .. match_type
    end
    if incompleteGame then
      extraFilename = extraFilename .. "-INCOMPLETE"
    else
      if outcome_claim == 1 or outcome_claim == 2 then
        extraFilename = extraFilename .. "-P" .. outcome_claim .. "wins"
      elseif outcome_claim == 0 then
        extraFilename = extraFilename .. "-draw"
      end
    end
  else -- vs Self
    extraPath = "Vs Self"
    extraFilename = "vsSelf-" .. "L" .. GAME.match.P1.level
  end

  self:finalizeAndWriteReplay(extraPath, extraFilename)
end

function GameBase:pickRandomStage()
  self.current_stage = table.getRandomElement(stages_ids_for_current_theme)
  if stages[self.current_stage]:is_bundle() then -- may pick a bundle!
    self.current_stage = table.getRandomElement(stages[self.current_stage].sub_stages)
  end
end

function GameBase:useCurrentStage()
  if config.stage == consts.RANDOM_STAGE_SPECIAL_VALUE then
    self:pickRandomStage()
  end
  current_stage = self.current_stage
  
  stage_loader_load(self.current_stage)
  stage_loader_wait()
  GAME.backgroundImage = UpdatingImage(stages[self.current_stage].images.background, false, 0, 0, canvas_width, canvas_height)
  GAME.background_overlay = themes[config.theme].images.bg_overlay
  GAME.foreground_overlay = themes[config.theme].images.fg_overlay
end

local function pickUseMusicFrom()
  if config.use_music_from == "stage" or config.use_music_from == "characters" then
    current_use_music_from = config.use_music_from
    return
  end
  local percent = math.random(1, 4)
  if config.use_music_from == "either" then
    current_use_music_from = percent <= 2 and "stage" or "characters"
  elseif config.use_music_from == "often_stage" then
    current_use_music_from = percent == 1 and "characters" or "stage"
  else
    current_use_music_from = percent == 1 and "stage" or "characters"
  end
end

function GameBase:load(scene_params)
  leftover_time = 1 / 120
  self.abort_game = false

  self:useCurrentStage()
  pickUseMusicFrom()
  self:customLoad(scene_params)
  replay = createNewReplay(GAME.match)
end



function GameBase:handlePause()
  if GAME.match.supportsPause and (input.isDown["Start"] or (not GAME.focused and not GAME.gameIsPaused)) then
    GAME.gameIsPaused = not GAME.gameIsPaused

    setMusicPaused(GAME.gameIsPaused)

    if not GAME.renderDuringPause then
      if GAME.gameIsPaused then
        reset_filters()
      else
        self:useCurrentStage()
      end
    end
  end
end

local t = 0 -- the amount of frames that have passed since the game over screen was displayed
local font = love.graphics.getFont()
local timemin = 60 -- the minimum amount of frames the game over screen will be displayed for
local timemax = -1
local winnerTime = 60
local initialMusicVolumes = {}

function GameBase:setupGameOver()
  --timemax = timemax or -1 -- negative values means the user needs to press enter/escape to continue
  --text = text or ""
  --keepMusic = keepMusic or false
  --local button_text = loc("continue_button") or ""
  
  t = 0 -- the amount of frames that have passed since the game over screen was displayed
  timemin = 60 -- the minimum amount of frames the game over screen will be displayed for
  timemax = -1
  winnerTime = 60
  initialMusicVolumes = {}
  
  self:customGameOverSetup()

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

function GameBase:runGameOver()
  gprint(self.text, (canvas_width - font:getWidth(self.text)) / 2, 10)
  gprint(loc("continue_button"), (canvas_width - font:getWidth(loc("continue_button"))) / 2, 10 + 30)
  -- wait()
  local ret = nil
  if not self.keep_music then
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
      if self.winner_SFX ~= nil then -- play winnerSFX then nil it so it doesn't loop
        self.winner_SFX:play()
        self.winner_SFX = nil
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
    scene_manager:switchScene(self.next_scene, self.next_scene_params)
  end
  t = t + 1
  
  GAME.match:render()
end

function GameBase:runGame(dt)
  repeat 
    GAME.match:run()
    self:customRun()
    dt = dt - consts.FRAME_RATE
  until (dt < consts.FRAME_RATE)
  
  if not ((GAME.match.P1 and GAME.match.P1.play_to_end) or (GAME.match.P2 and GAME.match.P2.play_to_end)) then
    self:handlePause()

    if GAME.gameIsPaused and input.isDown["Swap2"] then
      self:abortGame()
      self.abort_game = true
    end
  end
  
  if self.abort_game then
    return
  end
  
  if GAME.match.P1:gameResult() then
    self:setupGameOver()
    return
  end
  
  -- Render only if we are not catching up to a current spectate match
  if not (GAME.match.P1 and GAME.match.P1.play_to_end) and not (GAME.match.P2 and GAME.match.P2.play_to_end) then
    GAME.match:render()
  end
end

function GameBase:update(dt)
  if GAME.match.P1:gameResult() then
    self:runGameOver()
  else
    self:runGame(dt)
  end
end

function GameBase:unload()
  local game_result = GAME.match.P1:gameResult()
  if game_result then
    self:processGameResults(game_result)
  end
  analytics.game_ends(GAME.match.P1.analytic)
  GAME:clearMatch()
end

return GameBase