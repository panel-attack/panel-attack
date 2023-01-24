local UiElement = require("ui.UIElement")

local orientations = {vertical = 1, horizontal = 2}

-- a wrapper element for selectScreen to dynamically display select options

local MultiplayerSelectionWrapper = class(
  -- mandatory options:
  -- orientation: vertical or horizontal; the direction in which the element will grow
  -- width or heigh - the opposite options to the scaling orientation
  -- UiElement we wish to wrap
  -- playerCount
  -- padding inbetween repetitions of the userElement
  -- who is the local player (nil if spectating)
  function(self, options)
    self.orientation = options.orientation
    self.uiElement = options.uiElement
    self.playerCount = options.playerCount
    self.padding = options.padding
    self.localPlayer = options.localPlayer

    self.children = {}
    -- create the elements
    for i = 1, self.playerCount do
      self.children[i] = self.uiElement()
      self.children[i].owner = i
    end
    -- make sure the local player is first
    if self.localPlayer and self.localPlayer ~= 1 then
      self.children[self.localPlayer].owner = self.localPlayer
      self.children[1].owner = self.localPlayer
    end
    -- assign positions
    

  end
)

function MultiplayerSelectionWrapper:draw()

end

function MultiplayerSelectionWrapper:onSelect()
  -- set focus to the local player's uiElement

end