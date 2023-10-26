function dump(o, indents)
  indents = indents or 2
  local spacing = ''
  for i = 1, indents do
    spacing = spacing .. ' '
  end
  if type(o) == 'table' then
    local length = 0
    for _,_ in pairs(o) do
      length = length + 1
    end
    if length > 0 then 
      local s = string.sub(spacing, 1, indents - 2) .. '{'
      for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..tostring(k)..'"' end
        s = s .. '\n' .. spacing ..k..' = ' .. dump(v, indents + 2) .. ','
      end
      return s .. '\n' .. string.sub(spacing, 1, indents - 2) .. '}'
    else
      return '{}'
    end
  else
    return tostring(o)
  end
end