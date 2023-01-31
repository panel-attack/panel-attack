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

CREATE TABLE IF NOT EXISTS Game(
  gameID INTEGER PRIMARY KEY AUTOINCREMENT,
  ranked BOOLEAN NOT NULL CHECK (ranked IN (0, 1)),
  timePlayed TIME TIMESTAMP NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE TABLE IF NOT EXISTS PlayerGameResult(
  playerID INTEGER NOT NULL,
  gameID INTEGER NOT NULL,
  level INTEGER,
  placement INTEGER NOT NULL,
  FOREIGN KEY(playerID) REFERENCES Player(publicPlayerID),
  FOREIGN KEY(gameID) REFERENCES Game(gameID)
);
]]
--[[

CREATE TRIGGER IF NOT EXISTS trig_ratingUpdate BEFORE UPDATE ON Player
WHEN (OLD.rating != NEW.rating)
BEGIN
  INSERT INTO PlayerELOHistory(publicPlayerID, rating) VALUES (NEW.publicPlayerID, NEW.rating);
END;  

DROP TABLE IF EXISTS PlayerGameResult;
DROP TABLE IF EXISTS Game;

--local selectLeaderboardStatement = assert(db:prepare("SELECT username, rating FROM Player"))
--local insertGameStatement = assert(db:prepare("INSERT INTO Game(gameID, ranked) VALUES (?, ?)"))

-- TODO: Make work with foreign keys
--local insertPlayerGameResultStatement = assert(db:prepare("INSERT INTO PlayerGameResult(playerID, gameID, level, placement) VALUES (?, ?, ?, ?)"))

--local selectPlayerGamesStatement = assert(db:prepare("SELECT gameID FROM PlayerGameResult WHERE playerID = ?"))
--[[local updatePlayerRatingStatement = assert(db:prepare("UPDATE Player SET rating = ? WHERE privatePlayerID = ?"))
function PADatabase.updatePlayerRating(self, privatePlayerID, newRating)
  updatePlayerRatingStatement:bind_values(newRating, privatePlayerID)
  updatePlayerRatingStatement:step()
  if updatePlayerRatingStatement:reset() ~= 0 then
    print(db:errmsg())
  end
end]]

local selectPlayerRecordValuesStatement = assert(db:prepare("SELECT * FROM Player where privatePlayerID = ?"))
local function getPlayerValues(privatePlayerID)
  selectPlayerRecordValuesStatement:bind_values(privatePlayerID)
  selectPlayerRecordValuesStatement:step()
  local playerValues = selectPlayerRecordValuesStatement:get_named_values()
  if selectPlayerRecordValuesStatement:reset() ~= 0 then
    print(db:errmsg())
  end
  return playerValues
end

local insertPlayerStatement = assert(db:prepare("INSERT OR IGNORE INTO Player(privatePlayerID, username) VALUES (?, ?)"))
function PADatabase.insertNewPlayer(self, privatePlayerID, username)
  insertPlayerStatement:bind_values(privatePlayerID, username)
  insertPlayerStatement:step()
  if insertPlayerStatement:reset() ~= 0 then
    print(db:errmsg())
    return false
  end
  return true
end

local updatePlayerUsernameStatement = assert(db:prepare("UPDATE Player SET username = ? WHERE privatePlayerID = ?"))
function PADatabase.updatePlayerUsername(self, privatePlayerID, username)
  updatePlayerUsernameStatement:bind_values(privatePlayerID, username)
  updatePlayerUsernameStatement:step()
  if updatePlayerUsernameStatement:reset() ~= 0 then
    print(db:errmsg())
    return false
  end
  return true
end

local insertPlayerELOChangeStatement = assert(db:prepare("INSERT INTO PlayerELOHistory(publicPlayerID, rating) VALUES ((SELECT publicPlayerID FROM Player WHERE privatePlayerID = ?), ?)"))
function PADatabase.insertPlayerELOChange(self, privatePlayerID, rating)
  insertPlayerELOChangeStatement:bind_values(privatePlayerID, rating or 1500)
  insertPlayerELOChangeStatement:step()
  if insertPlayerELOChangeStatement:reset() ~= 0 then
    print(db:errmsg())
    return false
  end
  return true
end

local selectPlayerRecordCount = assert(db:prepare("SELECT COUNT(*) FROM Player"))
function PADatabase.getPlayerRecordCount()
  selectPlayerRecordCount:step()
  local recordCount = selectPlayerRecordCount:get_value(0) -- this is the row count.
  if selectPlayerRecordCount:reset() ~= 0 then
    print(db:errmsg())
    return -1
  end
  return recordCount
end

local insertGameStatement = assert(db:prepare("INSERT INTO Game(ranked) VALUES (?)"))
-- returns the gameID
function PADatabase.insertGame(self, ranked)
  insertGameStatement:bind_values(ranked and 1 or 0)
  insertGameStatement:step()
  if insertGameStatement:reset() ~= 0 then
    print(db:errmsg())
    return false
  end
  return db:last_insert_rowid()
end

local insertPlayerGameResultStatement = assert(db:prepare("INSERT INTO PlayerGameResult(playerID, gameID, level, placement) VALUES ((SELECT publicPlayerID FROM Player WHERE privatePlayerID = ?), ?, ?, ?)"))
function PADatabase.insertPlayerGameResult(self, privatePlayerID, gameID, level, placement)
  insertPlayerGameResultStatement:bind_values(privatePlayerID, gameID, level, placement)
  insertPlayerGameResultStatement:step()
  if insertPlayerGameResultStatement:reset() ~= 0 then
    print(db:errmsg())
    return false
  end
  return true
end

-- Stop statements from being committed
function PADatabase.beginTransaction(self)
  db:exec("BEGIN")
end

-- Commit all statements that were run since the start of beginTransaction
function PADatabase.commitTransaction(self)
  db:exec("COMMIT")
end

return PADatabase
