StackExtensions = {}

function StackExtensions.copyStack(stack)
  local match = selectiveDeepCopy(stack.match, nil, {P1=true, P2=true, P1CPU=true, P2CPU=true})
  local stackCopy =  selectiveDeepCopy(stack,                nil, {garbage_target=true, prev_states=true, canvas=true, match=true, telegraph=true})
  local otherStack = selectiveDeepCopy(stack.garbage_target, nil, {garbage_target=true, prev_states=true, canvas=true, match=true, telegraph=true})

  if stackCopy.which == 1 then
    match.P1 = stackCopy
  else
    match.P2 = stackCopy
  end

  if otherStack then
    if otherStack.which == 2 then
      match.P2 = otherStack
    else
      match.P1 = otherStack
    end
    otherStack.match = match
  end

  stackCopy.match = match

  return stackCopy
end

function StackExtensions.copyStackWithTelegraph(stack)
  local stackCopy = StackExtensions.copyStack(stack)
  local otherStack

  if stackCopy.which == 1 then
    otherStack = stackCopy.match.P2
  else
    otherStack = stackCopy.match.P1
  end

  if otherStack then
    local stackTelegraph = selectiveDeepCopy(stack.telegraph, nil, {sender=true, owner=true})
    if stackTelegraph then
      stackTelegraph.sender = otherStack
      stackTelegraph.owner = stackCopy
      stackCopy.telegraph = stackTelegraph
    end
    
    local otherTelegraph = selectiveDeepCopy(stack.garbage_target.telegraph, nil, {sender=true, owner=true})
    if otherTelegraph then
      otherTelegraph.sender = stackCopy
      otherTelegraph.owner = otherStack
      otherStack.telegraph = otherTelegraph
    end
    stackCopy.garbage_target = otherStack
    otherStack.garbage_target = stackCopy
  end

  return stackCopy
end