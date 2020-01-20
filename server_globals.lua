panel_color_number_to_upper = {"A", "B", "C", "D", "E", "F", "G", "H",[0]="0"}
panel_color_number_to_lower = {"a", "b", "c", "d", "e", "f", "g", "h",[0]="0"}
panel_color_to_number = { ["A"]=1, ["B"]=2, ["C"]=3, ["D"]=4, ["E"]=5, ["F"]=6, ["G"]=7, ["H"]=8,
                          ["a"]=1, ["b"]=2, ["c"]=3, ["d"]=4, ["e"]=5, ["f"]=6, ["g"]=7, ["h"]=8,
                          ["1"]=1, ["2"]=2, ["3"]=3, ["4"]=4, ["5"]=5, ["6"]=6, ["7"]=7, ["8"]=8,
                          ["0"]=0}
leagues = { {league="Newcomer",     min_rating = -1000},
            {league="Bronze",       min_rating = 1},
            {league="Silver",       min_rating = 1176},
            {league="Gold",         min_rating = 1376},
            {league="Platinum",     min_rating = 1519},
            {league="Diamond",      min_rating = 1670},
            {league="Master",       min_rating = 1926},
            {league="Grandmaster",  min_rating = 2139}
          }
--[[leagues = { {league="Newcomer",     min_rating = -1000},
            {league="Bronze",       min_rating = 1},
            {league="Silver",       min_rating = 1225},
            {league="Gold",         min_rating = 1475},
            {league="Platinum",     min_rating = 1725},
            {league="Diamond",      min_rating = 1975},
            {league="Master",       min_rating = 2225},
            {league="Grandmaster",  min_rating = 2475}
          }]]
PLACEMENT_MATCH_COUNT_REQUIREMENT = 50
DEFAULT_RATING = 1500
RATING_SPREAD_MODIFIER = 400
ALLOWABLE_RATING_SPREAD_MULITPLIER = .9 --set this to a huge number like 100 if you want everyone to be able to play with anyone, regardless of rating gap
PLACEMENT_MATCH_K = 50
NAME_LENGTH_LIMIT = 16
PLACEMENT_MATCHES_ENABLED = false
MIN_LEVEL_FOR_RANKED = 1
MAX_LEVEL_FOR_RANKED = 10
SERVER_PORT = 49569 -- default: 49569