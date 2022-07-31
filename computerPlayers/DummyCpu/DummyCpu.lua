local dummyConfig = { ['DummyConfig'] = { Log = 4 } }

DummyCpu = class(function(self, stack)
  self.name = "DummyCpu"
  self.config = dummyConfig
  self.stack = stack
end)

function DummyCpu.getInput(self)
  return base64encode[21]
end

function DummyCpu.setConfig(self, config)
  return
end

function DummyCpu.getConfigs(self)
  return dummyConfig
end