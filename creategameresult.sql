-- SQLITE
-- user_id,user_name,rating,placement_done,placement_rating,ranked_games_played,ranked_games_won,last_login_time
-- BOOLEAN NOT NULL CHECK (NAMEOFCOLUMN IN (0, 1))

DROP TABLE IF EXISTS GameResult;
CREATE TABLE IF NOT EXISTS GameResult(
  player1ID INTEGER NOT NULL, 
  player1Level INTEGER NOT NULL,
  player1Rating REAL NOT NULL,
  player2ID INTEGER NOT NULL,
  player2Level INTEGER NOT NULL,
  player2Rating REAL NOT NULL,
  winner INTEGER NOT NULL,
  rankedValue BOOLEAN NOT NULL CHECK (rankedValue IN (0, 1)),
  time TIME TIMESTAMP NOT NULL DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY(player1ID) REFERENCES Leaderboard(user_id),
  FOREIGN KEY(player2ID) REFERENCES Leaderboard(user_id));

INSERT INTO GameResult(player1ID, player1Level, player1Rating, player2ID, player2Level, player2Rating, player1Win, rankedValue)
VALUES (1, 8, 1500, 3, 10, 1500, 0, 0);
INSERT INTO GameResult(player1ID, player1Level, player1Rating, player2ID, player2Level, player2Rating, player1Win, rankedValue) 
VALUES (1, 10, 1500, 2, 10, 1500, 1, 1);
INSERT INTO GameResult(player1ID, player1Level, player1Rating, player2ID, player2Level, player2Rating, player1Win, rankedValue) 
VALUES (1, 10, 1500, 2, 10, 1500, 2, 1);
SELECT * From Leaderboard;
SELECT * FROM GameResult;
