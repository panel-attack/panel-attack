local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local Label = require("client.src.ui.Label")
local canBeFocused = require("client.src.ui.Focusable")
local util = require("common.lib.util")

local Leaderboard = class(function(self, options)
  self.label = Label({
    text = "",
    translate = false
  })
  self:addChild(self.label)

  self.string = nil
  self.data = nil

  self.visibleEntries = options.visibleEntries or 20
  self.firstVisibleIndex = nil
  self.lastVisibleIndex = nil

  canBeFocused(self)
end,
UiElement)

local function build_viewable_leaderboard_string(report, firstVisibleIndex, lastVisibleIndex)
  str = loc("lb_header_board") .. "\n"
  firstVisibleIndex = math.max(firstVisibleIndex, 1)
  lastVisibleIndex = math.min(lastVisibleIndex, #report)

  for i = firstVisibleIndex, lastVisibleIndex do
    ratingSpacing = "     " .. string.rep("  ", (3 - string.len(i)))
    nameSpacing = "     " .. string.rep("  ", (4 - string.len(report[i].rating)))
    if report[i].is_you then
      str = str .. loc("lb_you") .. "-> "
    else
      str = str .. "      "
    end
    str = str .. i .. ratingSpacing .. report[i].rating .. nameSpacing .. report[i].user_name
    if i < #report then
      str = str .. "\n"
    end
  end
  return str
end

function Leaderboard:updateData(leaderboardData)
  for rank = #leaderboardData, 1, -1 do
    if leaderboardData[rank].user_name == config.name then
      self.myRank = rank
    end
  end
  if not self.data then
    -- first update, set indexes to show our rank if we are on the leaderboard!
    self.firstVisibleIndex = math.max((self.myRank or 1) - 8, 1)
    self.lastVisibleIndex = math.min(self.firstVisibleIndex + self.visibleEntries, #leaderboardData)
  end
  self.data = leaderboardData
  self:refreshView()
  self.height = self.label.height
  self.width = self.label.width
end

function Leaderboard:refreshView()
  self.string = build_viewable_leaderboard_string(self.data, self.firstVisibleIndex, self.lastVisibleIndex)
  self.label:setText(self.string)
end

function Leaderboard:receiveInputs(inputs)
  if self.data then
    if inputs:isPressedWithRepeat("MenuUp", .25, 0.03) then
      GAME.theme:playMoveSfx()
      self.firstVisibleIndex = util.bound(1, self.firstVisibleIndex - 1, #self.data)
      self.lastVisibleIndex = util.bound(1, self.firstVisibleIndex + self.visibleEntries, #self.data)
      self:refreshView()
    elseif inputs:isPressedWithRepeat("MenuDown", .25, 0.03) then
      GAME.theme:playMoveSfx()
      self.lastVisibleIndex = util.bound(1, self.lastVisibleIndex + 1, #self.data)
      self.firstVisibleIndex = util.bound(1, self.lastVisibleIndex - self.visibleEntries, #self.data)
      self:refreshView()
    elseif inputs.isDown["MenuLeft"] then
      GAME.theme:playMoveSfx()
      self.firstVisibleIndex = util.bound(1, self.firstVisibleIndex - self.visibleEntries, #self.data)
      self.lastVisibleIndex = util.bound(1, self.firstVisibleIndex + self.visibleEntries, #self.data)
      self:refreshView()
    elseif inputs.isDown["MenuRight"] then
      GAME.theme:playMoveSfx()
      self.lastVisibleIndex = util.bound(1, self.lastVisibleIndex + self.visibleEntries, #self.data)
      self.firstVisibleIndex = util.bound(1, self.lastVisibleIndex - self.visibleEntries, #self.data)
      self:refreshView()
    end
  end

  if inputs.isDown["MenuEsc"] then
    if self.hasFocus then
      self:yieldFocus()
    end
  end
end

function Leaderboard:onTouch(x, y)
  self.swiping = true
  self.initialTouchY = y
  self.initialFirstVisible = self.firstVisibleIndex
  self.initialLastVisible = self.lastVisibleIndex
end

function Leaderboard:onDrag(x, y)
  if self.data then
    local indexOffset = math.round((y - self.initialTouchY) / 15)
    if indexOffset ~= 0 then
      local direction = math.sign(indexOffset)
      if direction == -1 then
        self.firstVisibleIndex = util.bound(1, self.initialFirstVisible - indexOffset, #self.data - self.visibleEntries)
        self.lastVisibleIndex = util.bound(self.visibleEntries, self.firstVisibleIndex + self.visibleEntries - 1, #self.data)
      else
        self.lastVisibleIndex = util.bound(self.visibleEntries, self.initialLastVisible - indexOffset, #self.data)
        self.firstVisibleIndex = util.bound(1, self.lastVisibleIndex - self.visibleEntries + 1, #self.data - self.visibleEntries)
      end
      self:refreshView()
    end
  end
end

function Leaderboard:onRelease(x, y)
  self:onDrag(x, y)
  self.swiping = false
end

return Leaderboard