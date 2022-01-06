Defend = class(
        function(strategy, cpu, garbagePanels)
            Strategy.init(strategy, "Defend", cpu)
            CpuLog:log(1, "chose to DEFEND")
            strategy.garbagePanels = garbagePanels
        end,
        Strategy
)

function Defend.chooseAction(self)
    local actions = StackExtensions.findActions(self.cpu.stack)

    local clearActions = self:getClearActions(actions)

    if #clearActions > 0 then
        local action = Action.getCheapestAction(clearActions, self.cpu.stack)
        CpuLog:log(1, "found action to defend " .. action:toString())
        return action
    else
        return nil
    end
end

function Defend.getClearActions(self, actions)
    local clearActions = {}
    actions = self:prepareActions(actions)
    for i=#actions, 1, -1 do
        CpuLog:log(1, actions[i]:toString())
        for j=1, #actions[i].panels do
            for k=1, #self.garbagePanels do
                if actions[i].panels[j].targetVector:isAdjacent(self.garbagePanels[k].vector) then
                    table.appendIfNotExists(clearActions, actions[i])
                end
            end
        end
    end

    return clearActions
end

function Defend.prepareActions(self, actions)
    local potentialClears = {}
    for i = 1, #actions do
        if self:couldBeAClear(actions[i]) then
            table.insert(potentialClears, actions[i])
        end
    end

    for i=#potentialClears,1,-1 do
        CpuLog:log(1, "calculated cost for " .. potentialClears[i]:toString())
        potentialClears[i]:calculateExecution(self.cpu.stack.cur_row, self.cpu.stack.cur_col)
    end


    return potentialClears
end

function Defend.couldBeAClear(self, action)
    for i=1, #action.panels do
        for j=1, #self.garbagePanels do
            if action.panels[i].vector:IsInAdjacentRow(self.garbagePanels[j].vector)
             and StackExtensions.actionIsValid(self.cpu.stack, action) then
                return true
            end
        end
    end
    return false
end