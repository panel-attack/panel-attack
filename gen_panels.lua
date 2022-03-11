require("util")
require("server_globals")
require("csprng")
local logger = require("logger")

-- class used for generating panels
PanelGenerator =
  class(
  function(self)

  end
)

function PanelGenerator.setSeed(seed)
  if seed then
    initialize_mt_generator(seed)
  end
end

function PanelGenerator.privateGeneratePanels(rows_to_make, ncolors, previousPanels, disallowAdjacentColors)
  local result = previousPanels

  for x = 0, rows_to_make - 1 do
    for y = 0, 5 do
      local previousTwoMatchOnThisRow = y > 1 and panel_color_to_number[string.sub(result, -1, -1)] == panel_color_to_number[string.sub(result, -2, -2)]
      local nogood = true
      local color = 0
      local belowColor = panel_color_to_number[string.sub(result, -6, -6)]
      while nogood do
        color = extract_mt(1, ncolors)
        nogood = (previousTwoMatchOnThisRow and color == panel_color_to_number[string.sub(result, -1, -1)]) or -- Can't have three in a row on this column
                 color == belowColor or -- can't have the same color as below
                 (y > 0 and color == panel_color_to_number[string.sub(result, -1, -1)] and disallowAdjacentColors) -- on level 8+ vs, don't allow any adjacent colors
      end
      result = result .. tostring(color)
    end
  end

  return result
end


function PanelGenerator.privateCheckPanels(ret)
  if TESTS_ENABLED then
    assert(string.len(ret) % 6 == 0)
    for i = 7, string.len(ret) do
      local color = panel_color_to_number[string.sub(ret, i, i)]
      if color ~= 0 and color == panel_color_to_number[string.sub(ret, i-6, i-6)] then
        error("invalid panels")
      end
    end
  end
end

function PanelGenerator.makePanels(seed, ncolors, prev_panels, mode, level, opponentLevel)

  PanelGenerator.setSeed(seed)

  --logger.debug("make_panels(" .. ncolors .. ", " .. prev_panels .. ", ") .. ")")
  local ret = prev_panels
  local rows_to_make = 100 -- setting the seed is slow, so try to build a lot of panels at once.
  if ncolors < 2 then
    return
  end
  local cut_panels = false
  local disallowAdjacentColors = (mode == "vs" and level > 7)

  if prev_panels == "" then
    ret = "000000"
    rows_to_make = 7
    -- During the initial board we can't allow adjacent colors if the other player can't
    disallowAdjacentColors = (mode == "vs" and (level > 7 or opponentLevel > 7))
    if mode == "vs" or mode == "endless" or mode == "time" then
      cut_panels = true
    end
  end

  ret = PanelGenerator.privateGeneratePanels(rows_to_make, ncolors, ret, disallowAdjacentColors)

  -- If this is the first time panels, remove the placeholder "000000"
  if prev_panels == "" then
    ret = string.sub(ret, 7, -1)
  end

  PanelGenerator.privateCheckPanels(ret)

  --logger.debug("panels before potential metal panel position assignments:")
  --logger.debug(ret)
  --assign potential metal panel placements
  local row_width = 6 --this may belong in globals if we were to ever make a game mode with a different width
  local new_ret = "000000"
  local new_row
  local prev_row
  for i = 1, string.len(ret) / 6 do
    local current_row_from_ret = string.sub(ret, (i - 1) * row_width + 1, (i - 1) * row_width + row_width)
    --logger.debug("current_row_from_ret: " .. current_row_from_ret)
    if tonumber(current_row_from_ret) then --doesn't already have letters in it for metal panel locations
      prev_row = string.sub(new_ret, 0 - row_width, -1)
      local first, second  --locations of potential metal panels
      --while panel vertically adjacent is not numeric, so can be a metal panel
      while not first or not tonumber(string.sub(prev_row, first, first)) do
        first = extract_mt(1, row_width)
      end
      while not second or second == first or not tonumber(string.sub(prev_row, second, second)) do
        second = extract_mt(1, row_width)
      end
      new_row = ""
      for j = 1, row_width do
        local chr_from_ret = string.sub(ret, (i - 1) * row_width + j, (i - 1) * row_width + j)
        local num_from_ret = tonumber(chr_from_ret)
        if j == first then
          new_row = new_row .. (panel_color_number_to_upper[num_from_ret] or chr_from_ret or "0")
        elseif j == second then
          new_row = new_row .. (panel_color_number_to_lower[num_from_ret] or chr_from_ret or "0")
        else
          new_row = new_row .. chr_from_ret
        end
      end
    else
      new_row = current_row_from_ret
    end
    new_ret = new_ret .. new_row
  end
  ret = new_ret

  PanelGenerator.privateCheckPanels(ret)

  --logger.debug("panels after potential metal panel position assignments:")
  --logger.debug(ret)
  if cut_panels then
    ret = procat(ret)
    local height = {7, 7, 7, 7, 7, 7}
    local to_remove = 12
    while to_remove > 0 do
      local idx = extract_mt(1, 6) -- pick a random column
      if height[idx] > 0 then
        ret[idx + 6 * (-height[idx] + 8)] = "0" -- delete the topmost panel in this column
        height[idx] = height[idx] - 1
        to_remove = to_remove - 1
      end
    end
    ret = table.concat(ret)
  end
  -- if cut_panels then
  -- logger.debug("panels after cut_panels")
  -- end

  ret = string.sub(ret, 7, -1)

  PanelGenerator.privateCheckPanels(ret)

  return ret
end

function PanelGenerator.makeGarbagePanels(seed, ncolors, prev_panels, mode, level)

  PanelGenerator.setSeed(seed)

  local firstPanelSet = false
  if prev_panels == "" then
    firstPanelSet = true
    prev_panels = "000000"
  end

  local disallowAdjacentColors = (mode == "vs" and level > 7)
  local ret = PanelGenerator.privateGeneratePanels(20, ncolors, prev_panels, disallowAdjacentColors)

  if firstPanelSet then
    ret = string.sub(ret, 7, -1)
  end
  return ret
end
