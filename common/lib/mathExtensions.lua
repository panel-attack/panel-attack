function math.sign(v)
	return (v >= 0 and 1) or -1
end

function math.round(number, numberOfDecimalPlaces)
  if number == 0 then
    return number
  end
  local multiplier = 10^(numberOfDecimalPlaces or 0)
  if number > 0 then
    return math.floor(number * multiplier + 0.5) / multiplier
  else
    return math.ceil(number * multiplier - 0.5) / multiplier
  end
end

function math.integerAwayFromZero(number)
  if number == 0 then
    return number
  end
  if number > 0 then
    return math.ceil(number)
  else
    return math.floor(number)
  end
end