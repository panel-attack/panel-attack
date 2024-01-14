require("class")
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

INSERT OR IGNORE INTO Game(gameID, ranked) VALUES (0, 1); -- Placeholder game for imported Elo history

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

CREATE TABLE IF NOT EXISTS IPID(
  ip TEXT NOT NULL,
  publicPlayerID INTEGER NOT NULL,
  PRIMARY KEY(ip, publicPlayerID),
  FOREIGN KEY(publicPlayerID) REFERENCES Player(publicPlayerID)
);

CREATE TABLE IF NOT EXISTS PlayerBanList(
  banID INTEGER PRIMARY KEY NOT NULL,
  ip TEXT, 
  publicPlayerID INTEGER,
  reason TEXT NOT NULL,
  completionTime INTEGER,
  banSeen TIME TIMESTAMP,
  FOREIGN KEY(publicPlayerID) REFERENCES Player(publicPlayerID)
);
]]

local insertPlayerStatement = assert(db:prepare("INSERT OR IGNORE INTO Player(privatePlayerID, username) VALUES (?, ?)"))
-- Inserts a new player into the database, ignores the statement if the ID is already used.
function PADatabase.insertNewPlayer(self, privatePlayerID, username)
  insertPlayerStatement:bind_values(privatePlayerID, username)
  insertPlayerStatement:step()
  if insertPlayerStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return false
  end
  return true
end

local selectPlayerStatement = assert(db:prepare("SELECT * FROM Player WHERE privatePlayerID = ?"))
-- Retrieves the player from the privatePlayerID
function PADatabase.getPlayerFromPrivateID(self, privatePlayerID)
  assert(privatePlayerID ~= nil)
  selectPlayerStatement:bind_values(privatePlayerID)
  local player = nil
  for row in selectPlayerStatement:nrows() do
    player = row
    break
  end
  if selectPlayerStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return nil
  end
  return player 
end

local updatePlayerUsernameStatement = assert(db:prepare("UPDATE Player SET username = ? WHERE privatePlayerID = ?"))
-- Updates the username of a player in the database based on their privatePlayerID.
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
-- Inserts a change of a Player's elo.
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
-- Returns the amount of players in the Player database.
function PADatabase.getPlayerRecordCount()
  local result = nil
  for row in selectPlayerRecordCount:rows() do
    result = row[1]
    break
  end
  if selectPlayerRecordCount:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return nil
  end
  return result
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
-- Inserts the results of a game.
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
-- Retrieves player messages that the player has not seen yet.
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
-- Marks a message as seen by a player.
function PADatabase.playerMessageSeen(self, messageID)
  updatePlayerMessageSeenStatement:bind_values(messageID)
  updatePlayerMessageSeenStatement:step()
  if updatePlayerMessageSeenStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return false
  end
  return true
end
 
local insertBanStatement = assert(db:prepare("INSERT INTO PlayerBanList(ip, reason, completionTime) VALUES (?, ?, ?)"))
-- Bans an IP address
function PADatabase.insertBan(self, ip, reason, completionTime)
  insertBanStatement:bind_values(ip, reason, completionTime)
  insertBanStatement:step()
  if insertBanStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return false
  end
  return {banID = db:last_insert_rowid(), reason = reason, completionTime = completionTime}
end

local insertIPIDStatement = assert(db:prepare("INSERT OR IGNORE INTO IPID(ip, publicPlayerID) VALUES (?, ?)"))
-- Maps an IP address to a publicPlayerID.
function PADatabase.insertIPID(self, ip, publicPlayerID)
  insertIPIDStatement:bind_values(ip, publicPlayerID)
  insertIPIDStatement:step()
  if insertIPIDStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return false
  end
  return true
end

local selectIPIDStatement = assert(db:prepare("SELECT publicPlayerID FROM IPID WHERE ip = ?"))
-- Selects all publicPlayerIDs that have been used with the given IP address.
function PADatabase.getIPIDS(self, ip)
  selectIPIDStatement:bind_values(ip)
  local publicPlayerIDs = {}
  for row in selectIPIDStatement:nrows() do
    publicPlayerIDs[#publicPlayerIDs+1] = row.publicPlayerID
  end
  if selectIPIDStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return {}
  end
  return publicPlayerIDs
end

local selectIPBansStatement = assert(db:prepare("SELECT banID, reason, completionTime FROM PlayerBanList WHERE ip = ?"))
-- Selects all bans associated with the ip given.
function PADatabase.getIPBans(self, ip)
  selectIPBansStatement:bind_values(ip)
  local bans = {}
  for row in selectIPBansStatement:nrows() do
    bans[#bans+1] = {banID = row.banID, reason = row.reason, completionTime = row.completionTime}
  end
  if selectIPBansStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return {}
  end
  return bans
end

local selectIDBansStatement = assert(db:prepare("SELECT banID, reason, completionTime FROM PlayerBanList WHERE publicPlayerID = ?"))
-- Selects all bans associated with the publicPlayerID given.
function PADatabase.getIDBans(self, publicPlayerID)
  selectIDBansStatement:bind_values(publicPlayerID)
  local bans = {}
  for row in selectIDBansStatement:nrows() do
    bans[#bans+1] = {banID = row.banID, reason = row.reason, completionTime = row.completionTime}
  end
  if selectIDBansStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return {}
  end
  return bans
end

-- Checks if a logging in player is banned based off their IP.
function PADatabase.isPlayerBanned(self, ip)
  -- all ids associated with the information given
  local publicPlayerIDs = {}
  if ip then
    publicPlayerIDs = self:getIPIDS(ip)
  end

  local bans = {}
  local ipBans = self:getIPBans(ip)
  for banID, ban in ipairs(ipBans) do
    bans[banID] = ban
  end

  for _, id in pairs(publicPlayerIDs) do
    for banID, ban in ipairs(self:getIDBans(id)) do
      bans[banID] = ban
    end
  end

  local longestBan = nil
  for _, ban in pairs(bans) do
    if (os.time() < ban.completionTime) and ((not longestBan) or (ban.completionTime > longestBan.completionTime)) then
      longestBan = ban
    end
  end
  return longestBan
end

local selectPlayerUnseenBansStatement = assert(db:prepare("SELECT banID, reason FROM PlayerBanList WHERE publicPlayerID = ? AND banSeen IS NULL"))
-- Retrieves player messages that the player has not seen yet.
function PADatabase.getPlayerUnseenBans(self, publicPlayerID)
  selectPlayerUnseenBansStatement:bind_values(publicPlayerID)
  local banReasons = {}
  for row in selectPlayerUnseenBansStatement:nrows() do
    banReasons[row.banID] = row.reason
  end
  if selectPlayerUnseenBansStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return {}
  end
  return banReasons
end

local updatePlayerBanSeenStatement = assert(db:prepare("UPDATE PlayerBanList SET banSeen = strftime('%s', 'now') WHERE banID = ?"))
-- Marks a ban as seen by a player.
function PADatabase.playerBanSeen(self, banID)
  updatePlayerBanSeenStatement:bind_values(banID)
  updatePlayerBanSeenStatement:step()
  if updatePlayerBanSeenStatement:reset() ~= sqlite3.OK then
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
