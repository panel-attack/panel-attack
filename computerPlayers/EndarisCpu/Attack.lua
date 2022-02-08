Attack = class(
        function(strategy, cpu)
            Strategy.init(strategy, "Attack", cpu)
            CpuLog:log(1, "chose to ATTACK")
        end,
        Strategy
)

function Attack.chooseAction(self)
    if not self.cpu.actions or #self.cpu.actions == 0 then
        self.cpu.actions = StackExtensions.findActions(self.cpu.stack)
    end

    if #self.cpu.actions > 0 then
        return Action.getCheapestAction(self.cpu.actions, self.cpu.stack)
    else
        return Raise(self.cpu.stack.CLOCK)
    end
end

function Attack.getCheapestAction(self)
    if not self.cpu.actions or #self.cpu.actions == 0 then
        self.cpu.actions = StackExtensions.findActions(self.cpu.stack)
    end

    local actions = {}

    if #self.cpu.actions > 0 then
        table.sort(
            self.cpu.actions,
            function(a, b)
                return a.estimatedCost < b.estimatedCost
            end
        )

        for i = #self.cpu.actions, 1, -1 do
            CpuLog:log(6, self.cpu.actions[i]:toString())
            -- this is a crutch cause sometimes we can find actions that are already completed and then we choose them cause they're already...complete
            if self.cpu.actions[i].estimatedCost == 0 then
                CpuLog:log(6, 'action is already completed, removing...')
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
