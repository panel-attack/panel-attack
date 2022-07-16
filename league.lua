leagues = { {league="Newcomer",     min_rating = -1000},
            {league="Copper",       min_rating = 1},
            {league="Bronze",       min_rating = 1125},
            {league="Silver",       min_rating = 1275},
            {league="Gold",         min_rating = 1425},
            {league="Platinum",     min_rating = 1575},
            {league="Diamond",      min_rating = 1725},
            {league="Master",       min_rating = 1875},
            {league="Grandmaster",  min_rating = 2025}
          }

    
-- Stores the information for what league each rating is and conversion functions
Leagues =
class(
function(self)
  
end
)

function Leagues.leagueNameForRating(rating)
    local result = nil
    for i = 2, #leagues do
        local league = leagues[i]
        if rating > league.min_rating then
            result = league.league
        end
    end
    return result
end
