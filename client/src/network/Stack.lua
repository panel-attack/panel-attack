local NetworkProtocol = require("common.network.NetworkProtocol")
local TouchDataEncoding = require("common.engine.TouchDataEncoding")
local ClientMessages = require("common.network.ClientProtocol")

function Stack.handle_input_taunt(self)
  if self.inputMethod ~= "touch" then
    local input = self.player.inputConfiguration
    if input.isDown["TauntUp"] and self:can_taunt() and #characters[self.character].sounds.taunt_up > 0 then
      self.taunt_up = math.random(#characters[self.character].sounds.taunt_up)
      GAME.netClient:sendTauntUp(self.taunt_up)
    elseif input.isDown["TauntDown"] and self:can_taunt() and #characters[self.character].sounds.taunt_down > 0 then
      self.taunt_down = math.random(#characters[self.character].sounds.taunt_down)
      GAME.netClient:sendTauntDown(self.taunt_down)
    end
  end
end

local touchIdleInput = TouchDataEncoding.touchDataToLatinString(false, 0, 0, 6)
function Stack.idleInput(self) 
  return (self.inputMethod == "touch" and touchIdleInput) or base64encode[1]
end

function Stack.send_controls(self)
  if self.is_local and GAME.netClient:isConnected() and #self.confirmedInput > 0 and self.garbageTarget and #self.garbageTarget.confirmedInput == 0 then
    -- Send 1 frame at clock time 0 then wait till we get our first input from the other player.
    -- This will cause a player that got the start message earlier than the other player to wait for the other player just once.
    -- print("self.confirmedInput="..(self.confirmedInput or "nil"))
    -- print("self.input_buffer="..(self.input_buffer or "nil"))
    -- print("send_controls returned immediately")
    return
  end

  local to_send
  if self.inputMethod == "controller" then
    local input = self.player.inputConfiguration
    to_send = base64encode[
      ((input.isDown["Raise1"] or input.isDown["Raise2"] or input.isPressed["Raise1"] or input.isPressed["Raise2"]) and 32 or 0) + 
      ((input.isDown["Swap1"] or input.isDown["Swap2"]) and 16 or 0) + 
      ((input.isDown["Up"] or input.isPressed["Up"]) and 8 or 0) + 
      ((input.isDown["Down"] or input.isPressed["Down"]) and 4 or 0) + 
      ((input.isDown["Left"] or input.isPressed["Left"]) and 2 or 0) + 
      ((input.isDown["Right"] or input.isPressed["Right"]) and 1 or 0) + 1
    ]
  elseif self.inputMethod == "touch" then
    to_send = self.touchInputController:encodedCharacterForCurrentTouchInput()
  end
  GAME.netClient:sendInput(to_send)

  self:handle_input_taunt()

  self:receiveConfirmedInput(to_send)
end