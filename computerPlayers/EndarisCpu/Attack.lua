Attack = class(
        function(strategy, cpu)
            Strategy.init(strategy, "Attack", cpu)
        end,
        Strategy
)

function Attack.chooseAction(self)
    for i = 1, #self.cpu.actions do
        cpuLog(
            'Action at index' ..
                i .. ': ' .. self.cpu.actions[i].name .. ' with cost of ' .. self.cpu.actions[i].estimatedCost
        )
    end

    if #self.cpu.actions > 0 then
        self.cpu.currentAction = self:getCheapestAction()      
    else
        self.cpu.currentAction = Raise()
    end
    self.cpu.inputQueue = self.cpu.currentAction.executionPath
end

function Attack.getCheapestAction(self)
    local actions = {}

    if #self.cpu.actions > 0 then
        table.sort(
            self.cpu.actions,
            function(a, b)
                return a.estimatedCost < b.estimatedCost
            end
        )

        for i = #self.cpu.actions, 1, -1 do
            self.cpu.actions[i]:print()
            -- this is a crutch cause sometimes we can find actions that are already completed and then we choose them cause they're already...complete
            if self.cpu.actions[i].estimatedCost == 0 then
                cpuLog('actions is already completed, removing...')
                table.remove(self.cpu.actions, i)
            end
        end

        local i = 1
        while i <= #self.cpu.actions and self.cpu.actions[i].estimatedCost == self.cpu.actions[1].estimatedCost do
            self.cpu.actions[i]:calculateExecution(self.cpu.stack.cur_row, self.cpu.stack.cur_col + 0.5)
            table.insert(actions, self.cpu.actions[i])
            i = i + 1
        end

        table.sort(
            actions,
            function(a, b)
                return #a.executionPath < #b.executionPath
            end
        )

        return actions[1]
    else
        return Raise()
    end
end
