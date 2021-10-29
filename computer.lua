require("engine")

-- A computer player for the game
Computer =
  class(
  function(self, mode)
    self.difficulty = 1
  end
)

local profiled = true

function Computer.run(self, stack)

  local profiler, result
  if profiled == false then
    profiler = newProfiler()
    profiler:start()
    profiled = true
  end

  if stack.CLOCK % 3 == 0 then
    print("Computer Running at Clock: " .. stack.CLOCK)
    
    local bestAction = nil
    local bestEvaluation = -10000
    local actions = self:allActions(stack)
    for idx = 1, #actions do
      local action = actions[idx]
      local evaluation = self:evaluateAction(stack, action)
      if evaluation > bestEvaluation then
        bestAction = action
        bestEvaluation = evaluation
      end
    end

    result = bestAction
  else
    result = self:idleAction()
  end


  if profiler and stack.CLOCK > 1000 then
    profiler:stop()

    local outfile = io.open( "profile.txt", "w+" )
    profiler:report( outfile )
    outfile:close()
    profiler = nil
  end

  return result
end

function Computer.allActions(self, stack)
  local actions = {}
  actions[#actions + 1] = self:action( true, false, false, false, false, true)
  actions[#actions + 1] = self:action(false,  true, false, false, false, true)
  actions[#actions + 1] = self:action(false, false,  true, false, false, true)
  actions[#actions + 1] = self:action(false, false, false,  true, false, true)
  return actions
end

function Computer.action(self, up, right, down, left, raise, swap)
  local to_send = base64encode[(raise and 32 or 0) + (swap and 16 or 0) + (up and 8 or 0) + (down and 4 or 0) + (left and 2 or 0) + (right and 1 or 0) + 1]
  return to_send
end

function Computer.idleAction(self, idleCount)
  local result = ""
  idleCount = idleCount or 1
  for idx = 1, idleCount do
    local to_send = base64encode[1]
    result = result .. to_send
  end
  return result
end

function Computer.idle(self, stack, idleCount)
  local idleInput = self:idleAction(idleCount)
  stack.input_buffer = stack.input_buffer .. idleInput
end

function Computer.evaluateAction(self, oldStack, action)

  local stack = deepcopy(oldStack, {prev_states=true, computer=true, garbage_target=true, canvas=true})

  stack.input_buffer = (stack.input_buffer or "") .. action
  self:idle(stack, 20)
  stack:run(10)

  local result = math.random() / 1000 -- small amount of randomness

  if stack:game_ended() then
    result = -1000
    print("avoiding game over")
  end

  local cursorRow = stack.cur_row
  local cursorColumn = stack.cur_col
  if cursorRow and cursorColumn and stack.width and stack.height then
    if stack.width >= cursorColumn and stack.height >= cursorRow then
      if stack.panels[cursorRow][cursorColumn].color == 0 then
        if stack.panels[cursorRow][cursorColumn+1].color == 0 then
          print("avoiding empty")
          result = result - 100 -- avoid cursor positions that do nothing
        end
      end
    end
  end

  for col = 1, stack.width do
    for row = 1, stack.height do
      if stack.panels[row][col].matching then
        result = result + 10
        print("preferring state with matches")
      end
    end
  end

  return result
end