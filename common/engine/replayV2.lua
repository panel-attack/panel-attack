local GameModes = require("common.engine.GameModes")

local ReplayV2 = {}

function ReplayV2.transform(replay)
  for i = 1, #replay.players do
    if replay.players[i].settings.inputs then
      replay.players[i].settings.inputs = uncompress_input_string(replay.players[i].settings.inputs)
    end

    if replay.players[i].settings.level then
      replay.players[i].settings.style = GameModes.Styles.MODERN
    else
      replay.players[i].settings.style = GameModes.Styles.CLASSIC
    end
  end
  return replay
end

return ReplayV2