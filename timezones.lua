-- Compute the difference in seconds between local time and UTC.
function get_timezone()
  local now = os.time()
  return os.difftime(now, os.time(os.date("!*t", now)))
end
timezone = get_timezone()

-- Return a timezone string in ISO 8601:2000 standard form (+hhmm or -hhmm)
function get_tzoffset(timezone)
  local h, m = math.modf(timezone / 3600)
  return string.format("%+.4d", 100 * h + 60 * m)
end



--[[ debugging
for _, tz in ipairs(arg) do
  if tz == '-' then
    tz = timezone
  else
    tz = 0 + tz
  end
  print(tz, get_tzoffset(tz))
end
--]]

-- return the timezone offset in seconds, as it was on the time given by ts
-- Eric Feliksik
function get_timezone_offset(ts)
	local utcdate   = os.date("!*t", ts)
	local localdate = os.date("*t", ts)
	localdate.isdst = false -- this is the trick
	return os.difftime(os.time(localdate), os.time(utcdate))
end
tzoffset = get_timezone_offset(os.time())

function to_UTC(time_to_convert)
  return time_to_convert+-1*tzoffset
end