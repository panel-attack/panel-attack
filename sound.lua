--sets the volume of a single source or table of sources
function set_volume(source, new_volume)
  print("set_volume called")
  if type(source) == "table" then
    for _,v in pairs(source) do
      set_volume(v, new_volume)
    end
  else
    source:setVolume(new_volume)
  end
end