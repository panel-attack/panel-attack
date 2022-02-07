-- well shit
require("computerPlayers.EndarisCpu.StackExtensions")

PathFinder = class(function(self) end)

function PathFinder.FindExecutionPath(panels, action)

end

-- returns a row/column panels array that displays the expected state of the stack
-- returns all other panels that changed their position
function PathFinder.SimulateSwap(panels, panelToSwap, directionVector)
    local otherPanel = StackExtensions.getPanelByVectorByPanels(panels, panelToSwap.vector:Subtract(directionVector))
    
end

-- returns whether there was a match in the vicinity of the swapped panels
function PathFinder.DetectMatches(panels, swappedPanels)
    local matches = {}
    for _, value in pairs(swappedPanels) do
        local matchesForPanel = PathFinder.DetectMatchesForSingle(panels, value)
        table.appendToList(matches,  matchesForPanel)
    end
    return matches
end

-- returns whether there was a match in the vicinity of the swapped panel
function PathFinder.DetectMatchesForSingle(panels, swappedPanel)
    -- fetch panels 
end