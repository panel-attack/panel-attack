local sqlite3 = require("lsqlite3")
-- This may not be it's own file, may be moved around in the future. This is just a good place to compile everything I'll need.
DBConnection =
  class(
  function(self, databaseName)
    self.database = sqlite3.open(databaseName)
  end
)


--[[

]]
