-- Based on Squid's fuzzy search
-- https://github.com/SquidDev-CC/artist/blob/vnext/artist/lib/match.lua
--
-- not very fuzzy anymore

local SCORE_WEIGHT = 1000
local LEADING_LETTER_PENALTY = -3
local LEADING_LETTER_PENALTY_MAX = -9

local _find = string.find

return function(str_lower, ptrn_lower)
  local score = 0

  local start = _find(str_lower, ptrn_lower, 1, true)
  if start then
    -- All letters before the current one are considered leading, so add them to our penalty
    score = SCORE_WEIGHT + math.max(LEADING_LETTER_PENALTY * (start - 1), LEADING_LETTER_PENALTY_MAX)
  end

  return score
end
