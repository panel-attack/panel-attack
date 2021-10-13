
Scores = class(function(self)
    self.vsSelf = {}
    self.vsSelf["record"] = {}
    self.vsSelf["last"] = {}
    for i = 1, 11, 1 do
      self.vsSelf["record"][i] = 0
      self.vsSelf["last"][i] = 0
    end
  end)

player1Scores = Scores()