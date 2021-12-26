require("computerPlayers.StackExtensions")

-- all StackExtensions should have an extra method that only takes the panelproperty as the parameter
-- this makes it easier to mock a stack for unit tests while maintaining convenience

function StackExtensions.rowEmpty(stack, row)
    return StackExtensions.rowEmptyByPanels(stack.panels, row)
end

function StackExtensions.rowEmptyByPanels(panels, row)
    local allBlank = true
    for col = 1, #panels[1] do
      if panels[row][col].color ~= 0 then
        allBlank = false
        break
      end
    end
    return allBlank
end

function StackExtensions.panelCount(stack)
    return StackExtensions.panelCountByPanels(stack.panels)
end

function StackExtensions.panelCountByPanels(panels)
    local panelCount = 0

    -- Endaris: why - 1 for the width? I kept this while porting this over but it seems wrong
    for column = 1, #panels[1] - 1, 1 do
        for row = 1, #panels, 1 do
        if panels[row][column].color ~= 0 then
            panelCount = panelCount + 1
        end
        end
    end
    return panelCount
end