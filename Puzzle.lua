-- A puzzle is a particular instance of the game, where there is a specific goal for clearing the panels
Puzzle =
  class(
  function(self, puzzleType, doCountdown, moves, stack)
    self.puzzleType = puzzleType
    self.doCountdown = doCountdown
    self.moves = moves
    self.stack = string.gsub(stack, "%s+", "") -- Remove whitespace so files can be easier to read
    self.randomizeColors = false
  end
)

function Puzzle.getPuzzleTypes()
  return { "moves", "chain" }
end

function Puzzle.getLegalCharacters()
  return { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "[", "]", "{", "}", "=" }
end

function Puzzle.randomizeColorString(colorString)
  local colorArray = Panel.regularColorsArray()
  if colorString:find("7") then
    colorArray = Panel.extendedRegularColorsArray()
  end
  local newColorOrder = {}

  for i = 1, #colorArray, 1 do
    newColorOrder[tostring(table.length(newColorOrder)+1)] = tostring(table.remove(colorArray, math.random(1, #colorArray)))
  end
  
  colorString = colorString:gsub("%d", newColorOrder)

  return colorString
end

function Puzzle.validate(self)
  local errMessage = ""

  if type(self.doCountdown) ~= "boolean" then
    errMessage = "\nInvalid value for property 'doCountdown'"
  end

  if string.len(self.stack) > 6*12 then
    errMessage = errMessage ..
     "\nPuzzlestring contains more panels than the playfield can contain." ..
     "\nNumber of panels: " .. string.len(self.stack) ..
     "\nMaximum allowed: " .. 6*12
  end

  local illegalCharacters = {}
  local pendingGarbageStart = nil
  local pendingGarbageStartIndex = 0
  for i = 1, #self.stack do
    local char = string.sub(self.stack, i, i)
    if not table.contains(Puzzle.getLegalCharacters(), char)
      and not table.contains(illegalCharacters, char) then
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

  if not table.contains(Puzzle.getPuzzleTypes(), self.puzzleType) then
    errMessage = errMessage ..
    "\nInvalid puzzle type detected, available puzzle types are: " .. table.concat(Puzzle.getPuzzleTypes(), ", ")
  end

  if string.lower(self.puzzleType) == "moves" and (not tonumber(self.moves) or tonumber(self.moves) < 1 ) then
    errMessage = errMessage ..
    "\nInvalid number of moves detected, expecting a number greater than zero but instead got " .. self.moves
  end

  return errMessage == "", errMessage
end