local tableUtils = require("common.lib.tableUtils")

-- A puzzle is a particular instance of the game, where there is a specific goal for clearing the panels
Puzzle =
  class(
  function(self, puzzleType, doCountdown, moves, stack, stop_time, shake_time)
    self.puzzleType = puzzleType or "moves"
    self.doCountdown = doCountdown
    self.moves = moves or 0
    self.stack = string.gsub(stack, "%s+", "") -- Remove whitespace so files can be easier to read
    self.randomizeColors = false
    self.stop_time = stop_time or 0
    self.shake_time = shake_time or 0
  end
)

function Puzzle.getPuzzleTypes()
  return { "moves", "chain", "clear" }
end

function Puzzle.getLegalCharacters()
  return { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "[", "]", "{", "}", "=" }
end

function Puzzle:fillMissingPanelsInPuzzleString(width, height)
  local puzzleString = self.stack
  local boardSizeInPanels = width * height
  if self.puzzleType == "clear" then
    -- first fill up the currently started row
    local fillUpLength = (puzzleString:len() % width)
    if fillUpLength > 0 then
      puzzleString = string.rep("0", width - fillUpLength) .. puzzleString
    end
    -- then fill up with single line garbage to ensure topout
    while string.len(puzzleString) < boardSizeInPanels do
      puzzleString = "[" .. string.rep("=", width - 2) .. "]" .. puzzleString
    end
  else
    puzzleString = string.rep("0", boardSizeInPanels - string.len(puzzleString)) .. puzzleString
  end

  return puzzleString
end

function Puzzle.randomizeColorsInPuzzleString(puzzleString)
  local colorArray = Panel.regularColorsArray()
  if puzzleString:find("7") then
    colorArray = Panel.extendedRegularColorsArray()
  end
  local newColorOrder = {}

  for i = 1, #colorArray, 1 do
    newColorOrder[tostring(tableUtils.length(newColorOrder)+1)] = tostring(table.remove(colorArray, love.math.random(1, #colorArray)))
  end
  
  puzzleString = puzzleString:gsub("%d", newColorOrder)

  return puzzleString
end

function Puzzle:horizontallyFlipPuzzleString()
  local rowWidth = 6
  local height = 12
  puzzleString = self:fillMissingPanelsInPuzzleString(rowWidth, height)
  local result = ""
  local unreverseMap = {}
  unreverseMap["{"] = "}"
  unreverseMap["}"] = "{"
  unreverseMap["["] = "]"
  unreverseMap["]"] = "["
  for i = 1, puzzleString:len(), rowWidth do
    local rowString = string.sub(puzzleString, i, i+rowWidth-1)
    if string.find(rowString, "%d") then
      rowString = string.reverse(rowString)
      rowString = string.gsub(rowString, "[%{%}%[%]]", unreverseMap)
    end
    result = result .. rowString
  end

  return result
end

function Puzzle.validate(self)
  local errMessage = ""

  if type(self.doCountdown) ~= "boolean" then
    errMessage = "\nInvalid value for property 'doCountdown'"
  end

  local stackLength = string.len(self.stack)
  if stackLength > 6*12 then
    -- any encoded panels extending beyond the height of the playfield need to be garbage or empty
    local overflowStack = self.stack:sub(1, stackLength - 72)
    local matches = {}
    for match in string.gmatch(overflowStack, "[1-9]") do
      matches[#matches+1] = match
    end
    if #matches > 0 then
      errMessage = errMessage ..
     "\nThere cannot be any panels on above the top of the stack, only garbage and whitespace." ..
     "\nPanels above the top identified: " .. table.concat(matches)
    end
  end

  local illegalCharacters = {}
  local pendingGarbageStart = nil
  local pendingGarbageStartIndex = 0
  for i = 1, #self.stack do
    local char = string.sub(self.stack, i, i)
    if not tableUtils.contains(Puzzle.getLegalCharacters(), char)
      and not tableUtils.contains(illegalCharacters, char) then
      table.insert(illegalCharacters, char)
    end
    if char == "[" or char == "{" then
      if not pendingGarbageStart then
        pendingGarbageStart = char
        pendingGarbageStartIndex = i
      else
        errMessage = errMessage ..
        "\nPuzzlestring contains invalid garbage notation, make sure you close garbage before you open another."
      end
    elseif char == "]" and pendingGarbageStart ~= "[" and pendingGarbageStart
      or char == "}" and pendingGarbageStart ~= "{" and pendingGarbageStart then
        errMessage = errMessage ..
        "\nPuzzlestring contains invalid garbage notation, make sure to not mix the symbols for opening/closing regular and shock garbage in your puzzle."
    elseif char == "]" and pendingGarbageStart == "["
      or char == "}" and pendingGarbageStart == "{" then
        if (i + 1 - pendingGarbageStartIndex) - 6 > 0 then-- more than 6 panels in the garbage -> chain garbage
          if ((i + 1 - pendingGarbageStartIndex) % 6 > 0 -- length of the garbage is not valid (needs to be divisable by 6)
            or (i % 6 > 0)) then -- end position of the garbage is not valid (needs to be at the end of a row)
            errMessage = errMessage ..
            "\nPuzzlestring contains invalid garbage notation, make sure to enter a valid length for chain type garbage, creating garbage that is  possible to encounter in the game."
          end
        else -- combo garbage
          if math.floor((i - 1) / 6) ~= math.floor(pendingGarbageStartIndex / 6) then
            errMessage = errMessage ..
            "\nPuzzlestring contains invalid garbage notation, make sure that your combo garbage does not extend over the scope of a single row."
          end
        end
        -- garbage has been properly closed - most likely
        pendingGarbageStart = nil
    end
  end

  if #illegalCharacters > 0 then
    errMessage = errMessage .. "\nPuzzlestring contains invalid characters: " .. table.concat(illegalCharacters, ", ")
  end

  if not tableUtils.contains(Puzzle.getPuzzleTypes(), self.puzzleType) then
    errMessage = errMessage ..
    "\nInvalid puzzle type detected, available puzzle types are: " .. table.concat(Puzzle.getPuzzleTypes(), ", ")
  end

  if string.lower(self.puzzleType) == "moves" and (not tonumber(self.moves) or tonumber(self.moves) < 1 ) then
    errMessage = errMessage ..
    "\nInvalid number of moves detected, expecting a number greater than zero but instead got " .. self.moves
  end

  return errMessage == "", errMessage
end

function Puzzle.toPuzzleString(panels)
  local function getPanelColor(panel)
    if panel.isGarbage then
      local effectiveHeight = panel.height
      if panel.state == "matched" then
        -- this is making the assumption that garbage that is currently clearing into panels is still to be included for the garbage block
        effectiveHeight = panel.height + 1
      end
      -- offsets are being calculated from the bottom left corner of garbage
      -- but we need to go in our order of traversal, therefore...
      -- top left anchor point
      if panel.x_offset == 0 and panel.y_offset == panel.height - 1 then
        -- garbage start
        if panel.metal then
          return "{"
        else
          return "["
        end
      -- bottom right anchor point
      elseif panel.x_offset == panel.width - 1 and panel.y_offset == panel.height - effectiveHeight then
        -- garbage end
        if panel.metal then
          return "}"
        else
          return "]"
        end
      else
        -- garbage body
        return "="
      end
    else
      return tostring(panel.color)
    end
  end
  local puzzleMatrix = {}

  for row = #panels, 1, -1 do
    for column = 1, #panels[row] do
      puzzleMatrix[#puzzleMatrix+1] = getPanelColor(panels[row][column])
    end
  end

  return table.concat(puzzleMatrix)
end