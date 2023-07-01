local sqlite3 = require("lsqlite3")
local db = sqlite3.open("PADatabase.sqlite3")
local logger = require("logger")

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
  lastLoginTime TIME TIMESTAMP DEFAULT (strftime('%s', 'now'))
);

CREATE TABLE IF NOT EXISTS Game(
  gameID INTEGER PRIMARY KEY AUTOINCREMENT,
  ranked BOOLEAN NOT NULL CHECK (ranked IN (0, 1)),
  timePlayed TIME TIMESTAMP NOT NULL DEFAULT (strftime('%s', 'now'))
);

INSERT INTO Game(gameID, ranked) VALUES (0, 1); -- Placeholder game for imported Elo history

CREATE TABLE IF NOT EXISTS PlayerGameResult(
  publicPlayerID INTEGER NOT NULL,
  gameID INTEGER NOT NULL,
  level INTEGER,
  placement INTEGER NOT NULL,
  FOREIGN KEY(publicPlayerID) REFERENCES Player(publicPlayerID),
  FOREIGN KEY(gameID) REFERENCES Game(gameID)
);

CREATE TABLE IF NOT EXISTS PlayerELOHistory(
  publicPlayerID INTEGER,
  rating REAL NOT NULL,
  gameID INTEGER NOT NULL,
  FOREIGN KEY(gameID) REFERENCES Game(gameID)
);

CREATE TABLE IF NOT EXISTS PlayerMessageList(
  messageID INTEGER PRIMARY KEY NOT NULL,
  publicPlayerID INTEGER NOT NULL,
  message TEXT NOT NULL,
  messageSeen TIME TIMESTAMP,
  FOREIGN KEY(publicPlayerID) REFERENCES Player(publicPlayerID)
);
]]

local selectPlayerRecordValuesStatement = assert(db:prepare("SELECT * FROM Player where privatePlayerID = ?"))
local function getPlayerValues(privatePlayerID)
  selectPlayerRecordValuesStatement:bind_values(privatePlayerID)
  selectPlayerRecordValuesStatement:step()
  local playerValues = selectPlayerRecordValuesStatement:get_named_values()
  if selectPlayerRecordValuesStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
  end
  return playerValues
end

local insertPlayerStatement = assert(db:prepare("INSERT OR IGNORE INTO Player(privatePlayerID, username) VALUES (?, ?)"))
function PADatabase.insertNewPlayer(self, privatePlayerID, username)
  insertPlayerStatement:bind_values(privatePlayerID, username)
  insertPlayerStatement:step()
  if insertPlayerStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return false
  end
  return true
end

local selectPublicPlayerIDStatement = assert(db:prepare("SELECT publicPlayerID FROM Player WHERE privatePlayerID = ?"))
function PADatabase.getPublicPlayerID(self, privatePlayerID)
  selectPublicPlayerIDStatement:bind_values(privatePlayerID)
  selectPublicPlayerIDStatement:step() 
  local publicPlayerID = selectPublicPlayerIDStatement:get_value(0) -- this is the row count.
  if selectPublicPlayerIDStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return nil
  end
  return publicPlayerID 
end

local updatePlayerUsernameStatement = assert(db:prepare("UPDATE Player SET username = ? WHERE privatePlayerID = ?"))
function PADatabase.updatePlayerUsername(self, privatePlayerID, username)
  updatePlayerUsernameStatement:bind_values(username, privatePlayerID)
  updatePlayerUsernameStatement:step()
  if updatePlayerUsernameStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return false
  end
  return true
end

local insertPlayerELOChangeStatement = assert(db:prepare("INSERT INTO PlayerELOHistory(publicPlayerID, rating, gameID) VALUES ((SELECT publicPlayerID FROM Player WHERE privatePlayerID = ?), ?, ?)"))
function PADatabase.insertPlayerELOChange(self, privatePlayerID, rating, gameID)
  insertPlayerELOChangeStatement:bind_values(privatePlayerID, rating or 1500, gameID)
  insertPlayerELOChangeStatement:step()
  if insertPlayerELOChangeStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return false
  end
  return true
end

local selectPlayerRecordCount = assert(db:prepare("SELECT COUNT(*) FROM Player"))
function PADatabase.getPlayerRecordCount()
  selectPlayerRecordCount:step()
  local recordCount = selectPlayerRecordCount:get_value(0) -- this is the row count.
  if selectPlayerRecordCount:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return nil
  end
  return recordCount
end

local insertGameStatement = assert(db:prepare("INSERT INTO Game(ranked) VALUES (?)"))
-- returns the gameID
function PADatabase.insertGame(self, ranked)
  insertGameStatement:bind_values(ranked and 1 or 0)
  insertGameStatement:step()
  if insertGameStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return nil
  end
  return db:last_insert_rowid()
end

local insertPlayerGameResultStatement = assert(db:prepare("INSERT INTO PlayerGameResult(publicPlayerID, gameID, level, placement) VALUES ((SELECT publicPlayerID FROM Player WHERE privatePlayerID = ?), ?, ?, ?)"))
function PADatabase.insertPlayerGameResult(self, privatePlayerID, gameID, level, placement)
  insertPlayerGameResultStatement:bind_values(privatePlayerID, gameID, level, placement)
  insertPlayerGameResultStatement:step()
  if insertPlayerGameResultStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return false
  end
  return true
end

local selectPlayerMessagesStatement = assert(db:prepare("SELECT messageID, message FROM PlayerMessageList WHERE publicPlayerID = ? AND messageSeen IS NULL"))
function PADatabase.getPlayerMessages(self, publicPlayerID)
  selectPlayerMessagesStatement:bind_values(publicPlayerID)
  local playerMessages = {}
  for row in selectPlayerMessagesStatement:nrows() do
    playerMessages[row.messageID] = row.message
  end
  if selectPlayerMessagesStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return {}
  end
  return playerMessages
end

local updatePlayerMessageSeenStatement = assert(db:prepare("UPDATE PlayerMessageList SET messageSeen = strftime('%s', 'now') WHERE messageID = ?"))
function PADatabase.playerMessageSeen(self, messageID)
  updatePlayerMessageSeenStatement:bind_values(messageID)
  updatePlayerMessageSeenStatement:step()
  if updatePlayerMessageSeenStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return false
  end
  return true
end

-- Stop statements from being committed until commitTransaction is called
function PADatabase.beginTransaction(self)
  if db:exec("BEGIN;") ~= sqlite3.OK then
    logger.error(db:errmsg())
    return false
  end
  return true
end

-- Commit all statements that were run since the start of beginTransaction
function PADatabase.commitTransaction(self)
  if db:exec("COMMIT;") ~= sqlite3.OK then
    logger.error(db:errmsg())
    return false
  end
  return true
end

return PADatabase
