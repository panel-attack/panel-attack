local CharacterSelect = require("scenes.CharacterSelect")

--@module training_mode_character_select
local training_mode_character_select = CharacterSelect(
  "training_mode_character_select", 
  {
    previous_scene = "training_mode_menu",
    next_scene = "training_mode_game"
  })

return training_mode_character_select