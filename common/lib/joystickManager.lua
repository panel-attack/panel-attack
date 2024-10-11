local tableUtils = require("common.lib.tableUtils")
local logger = require("common.lib.logger")

--@module joystickManager
local joystickManager = {
  guidToName = {},

  -- TODO: Convert this into a list of sensitivities per device or input configuration
  joystickSensitivity = .5,
  -- mapping of GUID to map of joysticks under that GUID (GUIDs are unique per controller type)
  -- the joystick map is a list of {joystickID: customJoystickID}
  -- the custom joystick id is a number starting at 0 and increases by 1 for each new joystick of that type
  -- this is to give each joystick an id that will remain consistant over multiple sessions (the joystick IDs can change per session)
  guidsToJoysticks = {},
  -- mapping of joystick ID to a joystick information containing recorded default axis whether the joystick is a gamepad and a reference to the joystick itself
  devices = {},
}

-- list of (directions, axis) pairs for the 8 cardinal directions
local stickMap = { 
  {"-x"}, 
  {"-x", "-y"}, 
  {"-y"}, 
  {"+x", "-y"}, 
  {"+x"}, 
  {"+x", "+y"}, 
  {"+y"}, 
  {"-x", "+y"}
}

-- map of LOVE's hat directions to a list of readable directions
local joystickHatToDirs = {
  c = {}, -- centered
  u = {"up"},
  d = {"down"},
  l = {"left"},
  r = {"right"},
  lu = {"left", "up"},
  ld = {"left", "down"},
  ru = {"right", "up"},
  rd = {"right", "down"}
}

function joystickManager:getJoystickButtonName(joystick, button)
  return string.format("%s:%s:%s", joystick:getGUID(), joystickManager.guidsToJoysticks[joystick:getGUID()][joystick:getID()], button)
end

-- -- maps joysticks to buttons by converting the {x, y} axis values to {direction, magnitude} pair
-- -- this will give more even mapping along the diagonals when thresholded by a single value (joystickSensitivity)
-- function joystickManager:joystickToDPad(joystick, xAxisIndex, yAxisIndex)
--   self:recordDefaultAxis(joystick)

--   local axis = yAxisIndex/2
--   local x = "x"..axis
--   local y = "y"..axis

--   local dpadState = {
--     [joystickManager:getJoystickButtonName(joystick, "+"..x)] = false,
--     [joystickManager:getJoystickButtonName(joystick, "-"..x)] = false,
--     [joystickManager:getJoystickButtonName(joystick, "+"..y)] = false,
--     [joystickManager:getJoystickButtonName(joystick, "-"..y)] = false
--   }
  
--   local xValue = joystickToDefaultAxisPositions[joystick][xAxisIndex] - joystick:getAxis(xAxisIndex)
--   local yValue = joystickToDefaultAxisPositions[joystick][yAxisIndex] - joystick:getAxis(yAxisIndex)

--   -- not taking the square root to get the magnitude since it's it more expensive than squaring the joystickSensitivity
--   local magSquared = xValue * xValue + yValue * yValue
--   local dir = math.atan2(yValue, xValue) * 180.0 / math.pi
--   -- atan2 maps to [-180, 180] the quantizedDir equation prefers positive numbers (due to modulo) so mapping to [0, 360]
--   dir = dir + 180
--   -- number of segments we are quantizing the joystick values to
--   local numDirSegments = #stickMap
--   -- the minimum angle we care to detect
--   local quantizationAngle = 360.0 / numDirSegments
--   -- if we quantized the raw direction the direction wouldn't register until you are greater than the direction
--   -- Ex: quantizedDir would be 0 (left) until you hit exactly 45deg before it changes to 1 (left, up) and would stay there until you are at 90deg
--   -- adding this offset so the transition is equidistant from both sides of the direction
--   -- Ex: quantizedDir is 1 (left, up) from the range [22.5, 67.5]
--   local angleOffset = quantizationAngle / 2
--   -- convert the continuous direction value into 8 quantized values which map to the stickMap indexes
--   local quantizedDir = math.floor(((dir + angleOffset) / quantizationAngle) % numDirSegments) + 1 

--   for _, button in ipairs(stickMap[quantizedDir]) do
--     local key = joystickManager:getJoystickButtonName(joystick, button..axis)
--     if magSquared > self.joystickSensitivity * self.joystickSensitivity then
--       dpadState[key] = true
--     end
--   end
--   return dpadState
-- end

-- maps dpad dir to buttons
function joystickManager:getDPadState(joystick, hatIndex)
  local dir = joystick:getHat(hatIndex)
  local activeButtons = joystickHatToDirs[dir]
  return {
    [joystickManager:getJoystickButtonName(joystick, "up"..hatIndex)] = tableUtils.contains(activeButtons, "up"),
    [joystickManager:getJoystickButtonName(joystick, "down"..hatIndex)] = tableUtils.contains(activeButtons, "down"),
    [joystickManager:getJoystickButtonName(joystick, "left"..hatIndex)] = tableUtils.contains(activeButtons, "left"),
    [joystickManager:getJoystickButtonName(joystick, "right"..hatIndex)] = tableUtils.contains(activeButtons, "right")
  }
end

function love.joystickadded(joystick)
  -- GUID identifies the device type, 2 controllers of the same type will have a matching GUID
  -- the GUID is consistent across sessions
  local guid = joystick:getGUID()
  -- ID is a per-session identifier for each controller regardless of type
  local id = joystick:getID()

  if not joystickManager.guidsToJoysticks[guid] then
    joystickManager.guidsToJoysticks[guid] = {}
    joystickManager.guidToName[guid] = joystick:getName()
  end

  local guidSticks = joystickManager.guidsToJoysticks[guid]

  if not guidSticks[id] then
    guidSticks[id] = #guidSticks + 1
  end

  local device = { defaultAxisPositions = {}, isGamepad = joystick:isGamepad(), joystick = joystick}

  local vendorID, productID, productVersion = joystick:getDeviceInfo( )

  logger.info("Connecting new device " .. vendorID .. ";" .. productID .. ";" .. productVersion .. ";" .. joystick:getName() .. ";" .. guid .. ";" .. id)

  if device.isGamepad then
    logger.info("Connecting new gamepad " .. joystick:getGamepadMappingString())
    logger.info("Gamepad has " .. joystick:getAxisCount() .. " axes")

    device.axisToGamepadAxis = {}
    -- if we have a known gamepad, assume 0 center for sticks but record axis for triggers as they often won't be 0 based
    for i, gamepadAxis in ipairs({"leftx", "lefty", "rightx", "righty", "triggerleft", "triggerright"}) do
      local inputtype, inputindex, _ = joystick:getGamepadMapping(gamepadAxis)
      if inputtype == "axis" then
        device.axisToGamepadAxis[inputindex] = gamepadAxis
        if string.match(gamepadAxis, "trigger") then
          device.defaultAxisPositions[inputindex] = joystick:getAxis(inputindex)
        else
          -- the controller would malfunction if a stick was held in a position when connecting
          device.defaultAxisPositions[inputindex] = 0
        end
      end
    end

    -- in case we still somehow have more axes, record them
    for axisIndex = 1, joystick:getAxisCount() do
      if not device.defaultAxisPositions[axisIndex] then
        local baseValue = joystick:getAxis(axisIndex)
        device.defaultAxisPositions[axisIndex] = baseValue
      end
    end
  else
    logger.info("Connecting new Joystick")
    logger.info("Joystick has " .. joystick:getAxisCount() .. " axes")

    -- if we don't have a known gamepad, just record everything
    for axisIndex = 1, joystick:getAxisCount() do
      local baseValue = joystick:getAxis(axisIndex)
      device.defaultAxisPositions[axisIndex] = baseValue
    end
  end

  joystickManager.devices[id] = device
end

function love.joystickremoved(joystick)
  -- GUID identifies the device type, 2 controllers of the same type will have a matching GUID
  -- the GUID is consistent across sessions
  local guid = joystick:getGUID()
  -- ID is a per-session identifier for each controller regardless of type
  local id = joystick:getID()

  local vendorID, productID, productVersion = joystick:getDeviceInfo( )

  logger.info("Disconnecting device " .. vendorID .. ";" .. productID .. ";" .. productVersion .. ";" .. joystick:getName() .. ";" .. guid .. ";" .. id)

  joystickManager.guidsToJoysticks[guid][id] = nil

  if tableUtils.length(joystickManager.guidsToJoysticks[guid]) == 0 then
    joystickManager.guidsToJoysticks[guid] = nil
  end

  joystickManager.devices[id] = nil
end

return joystickManager