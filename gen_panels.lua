require("util")
require("csprng")
local logger = require("logger")

-- table of static functions used for generating panels
local PanelGenerator = { rng = love.math.newRandomGenerator(), generatedCount = 0}

PanelGenerator.PANEL_COLOR_NUMBER_TO_UPPER = {"A", "B", "C", "D", "E", "F", "G", "H", "I", [0] = "0"}
PanelGenerator.PANEL_COLOR_NUMBER_TO_LOWER = {"a", "b", "c", "d", "e", "f", "g", "h", "i", [0] = "0" }
PanelGenerator.PANEL_COLOR_TO_NUMBER = {
  ["A"] = 1, ["B"] = 2, ["C"] = 3, ["D"] = 4, ["E"] = 5, ["F"] = 6, ["G"] = 7, ["H"] = 8, ["I"] = 9, ["J"] = 0,
  ["a"] = 1, ["b"] = 2, ["c"] = 3, ["d"] = 4, ["e"] = 5, ["f"] = 6, ["g"] = 7, ["h"] = 8, ["i"] = 9, ["j"] = 0,
  ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9, ["0"] = 0
}

-- sets the seed for the PanelGenerators own random number generator
-- seed has to be a number
function PanelGenerator:setSeed(seed)
  if seed then
    self.generatedCount = 0
    self.seed = seed
    self.rng:setSeed(seed)
  end
end

function PanelGenerator:random(min, max)
  self.generatedCount = self.generatedCount + 1
  return self.rng:random(min, max)
end

function PanelGenerator.privateGeneratePanels(rowsToMake, rowWidth, ncolors, previousPanels, disallowAdjacentColors)
  -- logger.info("generating panels with seed: " .. PanelGenerator.rng:getSeed() ..
  --              "\nbuffer: " .. previousPanels ..
  --              "\ncolors: " .. ncolors)

  local result = previousPanels

  if ncolors < 2 then
    error("Trying to generate panels with only " .. ncolors .. " colors")
  end

  for x = 0, rowsToMake - 1 do
    for y = 0, rowWidth - 1 do
      local previousTwoMatchOnThisRow = y > 1 and PanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(result, -1, -1)] ==
                                            PanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(result, -2, -2)]
      local nogood = true
      local color = 0
      local belowColor = PanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(result, -rowWidth, -rowWidth)]
      while nogood do
        color = PanelGenerator:random(1, ncolors)
        nogood =
            (previousTwoMatchOnThisRow and color == PanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(result, -1, -1)]) or -- Can't have three in a row on this column
            color == belowColor or -- can't have the same color as below
                (y > 0 and color == PanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(result, -1, -1)] and disallowAdjacentColors) -- on level 8+ vs, don't allow any adjacent colors
      end
      result = result .. tostring(color)
    end
  end
  PanelGenerator.privateCheckPanels(result, rowWidth)
  -- logger.debug(result)
  return result
end

function PanelGenerator.privateCheckPanels(ret, rowWidth)
  if TESTS_ENABLED then
    assert(string.len(ret) % rowWidth == 0)
    for i = rowWidth + 1, string.len(ret) do
      local color = PanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(ret, i, i)]
      if color ~= 0 and color == PanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(ret, i - rowWidth, i - rowWidth)] then
        error("invalid panels: " .. ret)
      end
    end
  end
end

function PanelGenerator.assignMetalLocations(ret, rowWidth)
  -- logger.debug("panels before potential metal panel position assignments:")
  -- logger.debug(ret)
  -- assign potential metal panel placements
  local new_ret = string.rep("0", rowWidth)
  local new_row
  local prev_row
  for i = 1, string.len(ret) / rowWidth do
    local current_row_from_ret = string.sub(ret, (i - 1) * rowWidth + 1, (i - 1) * rowWidth + rowWidth)
    -- logger.debug("current_row_from_ret: " .. current_row_from_ret)
    if tonumber(current_row_from_ret) then -- doesn't already have letters in it for metal panel locations
      prev_row = string.sub(new_ret, 0 - rowWidth, -1)
      local first, second -- locations of potential metal panels
      -- while panel vertically adjacent is not numeric, so can be a metal panel
      while not first or not tonumber(string.sub(prev_row, first, first)) do
        first = PanelGenerator:random(1, rowWidth)
      end
      while not second or second == first or not tonumber(string.sub(prev_row, second, second)) do
        second = PanelGenerator:random(1, rowWidth)
      end
      new_row = ""
      for j = 1, rowWidth do
        local chr_from_ret = string.sub(ret, (i - 1) * rowWidth + j, (i - 1) * rowWidth + j)
        local num_from_ret = tonumber(chr_from_ret)
        if j == first then
          new_row = new_row .. (PanelGenerator.PANEL_COLOR_NUMBER_TO_UPPER[num_from_ret] or chr_from_ret or "0")
        elseif j == second then
          new_row = new_row .. (PanelGenerator.PANEL_COLOR_NUMBER_TO_LOWER[num_from_ret] or chr_from_ret or "0")
        else
          new_row = new_row .. chr_from_ret
        end
      end
    else
      new_row = current_row_from_ret
    end
    new_ret = new_ret .. new_row
  end

  -- new_ret was started with a row of 0 because the algorithm relies on a row without shock panels being there at the start
  -- so cut that extra row out again
  new_ret = string.sub(new_ret, rowWidth + 1)
  PanelGenerator.privateCheckPanels(new_ret, rowWidth)

  -- logger.debug("panels after potential metal panel position assignments:")
  -- logger.debug(ret)
  return new_ret
end

return PanelGenerator