DROP TABLE IF EXISTS PlayerGameResult;
DROP TABLE IF EXISTS Game;
DROP TABLE IF EXISTS Player;

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS Player(
  privatePlayerID INTEGER PRIMARY KEY NOT NULL,
  publicPlayerID INTEGER,
  username TEXT NOT NULL,
  rating REAL NOT NULL DEFAULT 0,
  placementDone BOOLEAN NOT NULL CHECK (rating IN (0, 1)) DEFAULT 0,
  placementRating REAL NOT NULL DEFAULT 0,
  rankedGamesPlayed INTEGER NOT NULL DEFAULT 0,
  rankedGamesWon INTEGER NOT NULL DEFAULT 0,
  lastLoginTime TIME TIMESTAMP DEFAULT (strftime('%s', 'now')),
  developer BOOLEAN CHECK (developer IN (0, 1)),
  youtuber BOOLEAN CHECK (youtuber IN (0, 1)),
  twitchStreamer BOOLEAN CHECK (twitchStreamer IN (0, 1))
);

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
