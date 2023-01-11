local sqlite3 = require("lsqlite3")
local db = sqlite3.open("PADatabase.sqlite3")

PADatabase =
  class(
  function(self)
  end
)

db:exec[[
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS Player(
  publicPlayerID INTEGER PRIMARY KEY AUTOINCREMENT,
  privatePlayerID INTEGER NOT NULL UNIQUE,
  username TEXT NOT NULL,
  rating REAL NOT NULL DEFAULT 0,
  placementDone BOOLEAN NOT NULL CHECK (placementDone IN (0, 1)) DEFAULT 0,
  placementRating REAL NOT NULL DEFAULT 0,
  rankedGamesPlayed INTEGER NOT NULL DEFAULT 0,
  rankedGamesWon INTEGER NOT NULL DEFAULT 0,
  lastLoginTime TIME TIMESTAMP DEFAULT (strftime('%s', 'now'))
);

CREATE TABLE IF NOT EXISTS PlayerELOHistory(
  publicPlayerID INTEGER,
  rating REAL NOT NULL,
  updateTime TIME TIMESTAMP DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY(publicPlayerID) REFERENCES Player(publicPlayerID)
);

CREATE TRIGGER IF NOT EXISTS trig_ratingUpdate BEFORE UPDATE ON Player
WHEN (OLD.rating != NEW.rating)
BEGIN
  INSERT INTO PlayerELOHistory(publicPlayerID, rating) VALUES (NEW.publicPlayerID, NEW.rating);
END;  
]]
--[[
DROP TABLE IF EXISTS PlayerGameResult;
DROP TABLE IF EXISTS Game;

CREATE TABLE IF NOT EXISTS Game(
  gameID INTEGER PRIMARY KEY NOT NULL,
  ranked BOOLEAN NOT NULL CHECK (ranked IN (0, 1)),
  timePlayed TIME TIMESTAMP NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE TABLE IF NOT EXISTS PlayerGameResult(
  playerID INTEGER NOT NULL,
  gameID INTEGER NOT NULL,
  level INTEGER NOT NULL,
  placement INTEGER NOT NULL,
  FOREIGN KEY(playerID) REFERENCES Player(publicPlayerID),
  FOREIGN KEY(gameID) REFERENCES Game(gameID)
);
]]
--local selectLeaderboardStatement = assert(db:prepare("SELECT username, rating FROM Player"))
--local insertGameStatement = assert(db:prepare("INSERT INTO Game(gameID, ranked) VALUES (?, ?)"))

-- TODO: Make work with foreign keys
--local insertPlayerGameResultStatement = assert(db:prepare("INSERT INTO PlayerGameResult(playerID, gameID, level, placement) VALUES (?, ?, ?, ?)"))

--local selectPlayerGamesStatement = assert(db:prepare("SELECT gameID FROM PlayerGameResult WHERE playerID = ?"))


local insertPlayerStatement = assert(db:prepare("INSERT OR IGNORE INTO Player(privatePlayerID, username, rating) VALUES (?, ?, ?)"))
function PADatabase.insertNewPlayer(self, privatePlayerID, username, rating)
  insertPlayerStatement:bind_values(privatePlayerID, username, rating)
  insertPlayerStatement:step()
  if insertPlayerStatement:reset() ~= 0 then
    print(db:errmsg())
  end
end

local updatePlayerRatingStatement = assert(db:prepare("UPDATE Player SET rating = ? WHERE privatePlayerID = ?"))
function PADatabase.updatePlayerRating(self, privatePlayerID, newRating)
  updatePlayerRatingStatement:bind_values(newRating, privatePlayerID)
  updatePlayerRatingStatement:step()
  if updatePlayerRatingStatement:reset() ~= 0 then
    print(db:errmsg())
  end
end

local updatePlayerUsernameStatement = assert(db:prepare("UPDATE Player SET username = ? WHERE privatePlayerID = ?"))
function PADatabase.updatePlayerUsername(self, privatePlayerID, username)
  updatePlayerUsernameStatement:bind_values(privatePlayerID, username)
  updatePlayerUsernameStatement:step()
  if updatePlayerUsernameStatement:reset() ~= 0 then
    print(db:errmsg())
  end
end

return PADatabase
