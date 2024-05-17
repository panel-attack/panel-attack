RichPresence =
  class(
  function(self)
    self.discordRPC = nil
    self.rich_presence = {}
    self.largeImageKey = "panel_attack_main" -- This can change, but only one is possible right now.
  end
)

function RichPresence.initialize(self, applicationId)
  pcall(
    function()
      self.discordRPC = require("client.lib.rich_presence.discordRPC")
      self.discordRPC.initialize(applicationId --[["902897593049301004"]], true)
    end
  )
end

-- Overwrites the presence to whatever is given.
function RichPresence.setPresence(self, details, state, doStartTimestamp)
  self.rich_presence = {
    details = details,
    state = state,
    largeImageKey = self.largeImageKey
  }
  if doStartTimestamp then
    self.rich_presence.startTimestamp = os.time(os.date("*t"))
  else
    self.rich_presence.startTimestamp = nil
  end
  if self.discordRPC then
    self.discordRPC.updatePresence(self.rich_presence)
  end
end

function RichPresence.runCallbacks(self)
  if self.discordRPC then
    self.discordRPC.runCallbacks()
  end
end

return RichPresence