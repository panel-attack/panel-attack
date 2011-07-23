local line = io.read("*line")
local out = ""
while line do
  while string.sub(line,1,4)=="    " do
    out = out .. "  "
    line = string.sub(line,5)
  end
  print(out..line)
  line = io.read("*line")
  out = ""
end
