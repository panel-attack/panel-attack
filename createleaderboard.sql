-- SQLITE
-- user_id,user_name,rating,placement_done,placement_rating,ranked_games_played,ranked_games_won,last_login_time
-- BOOLEAN NOT NULL CHECK (NAMEOFCOLUMN IN (0, 1))

DROP TABLE IF EXISTS Leaderboard;
CREATE TABLE IF NOT EXISTS Leaderboard(
  user_id INTEGER PRIMARY KEY NOT NULL, 
  user_name TEXT NOT NULL, 
  rating REAL NOT NULL DEFAULT 0,
  placement_done BOOLEAN NOT NULL CHECK (rating IN (0, 1)) DEFAULT 0,
  placement_rating REAL NOT NULL DEFAULT 0,
  ranked_games_played INTEGER NOT NULL DEFAULT 0,
  ranked_games_won INTEGER NOT NULL DEFAULT 0,
  last_login_time TIME TIMESTAMP DEFAULT (strftime('%s', 'now')));

INSERT INTO Leaderboard(user_id, user_name) VALUES (1, "ShosoulDev");
INSERT INTO Leaderboard(user_id, user_name) VALUES (2, "Shosoul");
INSERT INTO Leaderboard(user_id, user_name) VALUES (3, "Sho");
SELECT * FROM Leaderboard;
