StackExtensions = class(function(self) end)
-- all StackExtensions should have an extra method that only takes the panelproperty as the parameter
-- this makes it easier to mock a table for unit tests while maintaining convenience

function StackExtensions.AsAprilStack(stack)
    if stack then
        return StackExtensions.AsAprilStackByPanels(stack.panels)
    end
end

function StackExtensions.AsAprilStackByPanels(panels)
    if panels then
        local panelString = ""
        for i=#panels,1,-1 do
            for j=1,#panels[1] do
                panelString = panelString.. (tostring(panels[i][j].color))
            end
        end

        return panelString
    end
end

-- expects an aprilStack WITH whitespace! (or at least full rows)
function StackExtensions.aprilStackToPanels(aprilStack)
    local panels = {}
    local panelCount = 0
    local loops = 0
    -- chunk the aprilstack into rows:
    while #aprilStack > 0 do
        loops = loops + 1
        local rowString = string.sub(aprilStack, #aprilStack - 5, #aprilStack)
        aprilStack = string.sub(aprilStack, 1, #aprilStack - 6)
        -- copy the panels into the row
        panels[loops] = {}
        for i = 1, 6 do
            local color = string.sub(rowString, i, i)
            local panel = Panel(panelCount)
            panel.color = tonumber(color)
            panelCount = panelCount + 1
            panels[loops][i] = panel
        end
    end

    return panels
end

function StackExtensions.copyStack(stack)
    local match = deepcopy(stack.match, nil, {P1=true, P2=true, P1CPU=true, P2CPU=true})
    local stackCopy = deepcopy(stack, nil, {garbage_target=true, prev_states=true, canvas=true, match=true, telegraph=true})
    local otherStack = deepcopy(stack.garbage_target, nil, {garbage_target=true, prev_states=true, canvas=true, match=true, telegraph=true})
    otherStack.is_local = false
    stackCopy.garbage_target = otherStack
    otherStack.garbage_target = stackCopy
    if stackCopy.which == 1 then
        match.P1 = stackCopy
        match.P2 = otherStack
    else
        match.P2 = stackCopy
        match.P1 = otherStack
    end
    stackCopy.match = match
    otherStack.match = match

    return stackCopy
end