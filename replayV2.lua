local ReplayV2 = {}

function ReplayV2.loadFromFile(replay)
  for i = 1, #replay.players do
    replay.players[i].settings.inputs = uncompress_input_string(replay.players[i].settings.inputs)
  end
  return replay
end

return ReplayV2