DROP TABLE IF EXISTS PlayerELOHistory;
DROP TABLE IF EXISTS Player;
DROP TRIGGER IF EXISTS trig_ratingUpdate;

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

INSERT INTO Player(privatePlayerID, username) VALUES (1, 'Shosoul');
UPDATE Player SET rating = 1501 WHERE privatePlayerID = 1;
SELECT * FROM Player;

