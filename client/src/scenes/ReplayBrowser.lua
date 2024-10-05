local Scene = require("client.src.scenes.Scene")
local input = require("common.lib.inputManager")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local fileUtils = require("client.src.FileUtils")
local Replay = require("common.engine.Replay")
local class = require("common.lib.class")
local GameModes = require("common.engine.GameModes")
local ReplayGame = require("client.src.scenes.ReplayGame")

--@module replayBrowser
local ReplayBrowser = class(
  function (self, sceneParams)
    self.keepMusic = true
    self:load(sceneParams)
  end,
  Scene
)

ReplayBrowser.name = "ReplayBrowser"

local selection = nil
local base_path = "replays"
local current_path = "/"
local path_contents = {}
local filename = nil
local state = "browser"
-- technically this should start as nil but it drives the language server a bit crazy
local selectedReplay = {}

local menu_x = 400
local menu_y = 280
local menu_h = 14
local menu_cursor_offset = 16

local cursor_pos = 0

local replay_id_top = 0

local function replayMenu()
  if (replay_id_top == 0) then
    if current_path ~= "/" then
      GraphicsUtil.print("< " .. loc("rp_browser_up") .. " >", menu_x, menu_y)
    else
      GraphicsUtil.print("< " .. loc("rp_browser_root") .. " >", menu_x, menu_y)
    end
  else
    GraphicsUtil.print("^ " .. loc("rp_browser_more") .. " ^", menu_x, menu_y)
  end

  for i, p in pairs(path_contents) do
    if (i > replay_id_top) and (i <= replay_id_top + 20) then
      GraphicsUtil.print(p, menu_x, menu_y + (i - replay_id_top) * menu_h)
    end
  end

  if #path_contents > replay_id_top + 20 then
    GraphicsUtil.print("v " .. loc("rp_browser_more") .. " v", menu_x, menu_y + 21 * menu_h)
  end

  GraphicsUtil.print(">", menu_x - menu_cursor_offset + math.sin(love.timer.getTime() * 8) * 5, menu_y + (cursor_pos - replay_id_top) * menu_h)
end

local function moveCursor(dir)
  cursor_pos = wrap(0, cursor_pos + dir, #path_contents)
  if cursor_pos <= replay_id_top then
    replay_id_top = math.max(cursor_pos, 1) - 1
  end
  if replay_id_top < cursor_pos - 20 then
    replay_id_top = cursor_pos - 20
  end
end

local function updateBrowsingPath(new_path)
  if new_path then
    cursor_pos = 0
    replay_id_top = 0
    if new_path == "" then
      new_path = "/"
    end
    current_path = new_path
  end
  path_contents = fileUtils.getFilteredDirectoryItems(base_path .. current_path)
  if not path_contents[cursor_pos] then
    cursor_pos = replay_id_top
  end
end
  
local function setPathToParentDir()
  updateBrowsingPath(current_path:gsub("(.*/).*/$", "%1"))
end

local function selectMenuItem()
  if cursor_pos == 0 then
    setPathToParentDir()
  else
    selection = base_path .. current_path .. path_contents[cursor_pos]
    local file_info = love.filesystem.getInfo(selection)
    if file_info then
      if file_info.type == "file" then
        filename = selection
        local success, replay = Replay.load(fileUtils.readJsonFile(selection))
        if success then
          selectedReplay = replay
        end
        return success
      elseif file_info.type == "directory" then
        updateBrowsingPath(current_path .. path_contents[cursor_pos] .. "/")
      else
        --print(loc("rp_browser_error_unknown_filetype", file_info.type, selection))
      end
    else
      --print(loc("rp_browser_error_file_not_found", selection))
    end
  end
end

function ReplayBrowser:load()
  if Replay.lastPath then
    current_path = string.sub(Replay.lastPath, (string.len(base_path) + 1)) .. "/"
  end

  state = "browser"
  updateBrowsingPath()
end

function ReplayBrowser:update()
  if state == "browser" then
    if input.isDown["MenuEsc"] then
      GAME.theme:playCancelSfx()
      GAME.navigationStack:pop()
    end
    if input.isDown["MenuSelect"] then
      GAME.theme:playValidationSfx()
      if selectMenuItem() then
        state = "info"
      end
    end
    if input.isDown["MenuBack"] then
      if current_path == "/" then
        GAME.theme:playCancelSfx()
      else
        GAME.theme:playValidationSfx()
        setPathToParentDir()
      end
    end
    if input:isPressedWithRepeat("MenuUp") then
      GAME.theme:playMoveSfx()
      moveCursor(-1)
    end
    if input:isPressedWithRepeat("MenuDown") then
      GAME.theme:playMoveSfx()
      moveCursor(1)
    end
  elseif state == "info" then
    if input.isDown["MenuEsc"] or input.isDown["MenuBack"] then
      GAME.theme:playValidationSfx()
      state = "browser"
    end
    if input.isDown["MenuSelect"] and Replay.replayCanBeViewed(selectedReplay) then
      GAME.theme:playValidationSfx()
      local match = Match.createFromReplay(selectedReplay, false)
      match.renderDuringPause = true
      match:start()
      GAME.navigationStack:push(ReplayGame({match = match}))
    end
  end
end

function ReplayBrowser:draw()
  themes[config.theme].images.bg_main:draw()

  if state == "browser" then
    GraphicsUtil.print(loc("rp_browser_header"), menu_x + 170, menu_y - 40)
    GraphicsUtil.print(loc("rp_browser_current_dir", base_path .. current_path), menu_x, menu_y - 40 + menu_h)
    replayMenu()
  elseif state == "info" then
    local next_func = nil
    if Replay.replayCanBeViewed(selectedReplay) == false then
      GraphicsUtil.print(loc("rp_browser_wrong_version"), menu_x - 150, menu_y - 80 + menu_h)
    end
    
    GraphicsUtil.print(loc("rp_browser_info_header"), menu_x + 170, menu_y - 40)
    GraphicsUtil.print(filename, menu_x - 150, menu_y - 40 + menu_h)

    local modeText
    if #selectedReplay.players == 2 then
      modeText = loc("rp_browser_info_2p_vs")
    else
      if selectedReplay.gameMode.stackInteraction == GameModes.StackInteractions.SELF then
        modeText = loc("rp_browser_info_1p_vs")
      elseif selectedReplay.gameMode.puzzle then
        modeText = loc("rp_browser_info_puzzle")
      elseif selectedReplay.gameMode.timeLimit then
        modeText = loc("rp_browser_info_time")
      else
        modeText = loc("rp_browser_info_endless")
      end
    end
    GraphicsUtil.print(modeText, menu_x + 220, menu_y + 20)

    local offsetX = 0
    for i = 1, #selectedReplay.players do
      GraphicsUtil.print(loc("rp_browser_info_" .. i .. "p"), menu_x + offsetX, menu_y + 50)
      GraphicsUtil.print(loc("rp_browser_info_name", selectedReplay.players[i].name or ("Player " .. i)), menu_x + offsetX, menu_y + 65)
      GraphicsUtil.print(loc("rp_browser_info_character", selectedReplay.players[i].settings.characterId or ""), menu_x + offsetX, menu_y + 80)
      if selectedReplay.players[i].human then
        if selectedReplay.players[i].settings.level then
          GraphicsUtil.print(loc("rp_browser_info_level", selectedReplay.players[i].settings.level), menu_x + offsetX, menu_y + 95)
        else
          GraphicsUtil.print(loc("rp_browser_info_speed", selectedReplay.players[i].settings.levelData.startingSpeed), menu_x + offsetX, menu_y + 95)
          GraphicsUtil.print(loc("rp_browser_info_difficulty", selectedReplay.players[i].settings.difficulty), menu_x + offsetX, menu_y + 110)
        end
      else

      end
      offsetX = offsetX + 300
    end

    if selectedReplay.ranked then
      GraphicsUtil.print(loc("rp_browser_info_ranked"), menu_x + 200, menu_y + 130)
    end

    if Replay.replayCanBeViewed(selectedReplay) then
      GraphicsUtil.print(loc("rp_browser_watch"), menu_x + 75, menu_y + 150)
    end
  end
end

return ReplayBrowser