local FILENAME = "PanelAttack Localization File - Feuille 1.tsv"

local loc_map = {}
local loc_langs = {}
local loc_lang_index = 2

function localization_init()
	local first_line = true
	if love.filesystem.getInfo(FILENAME) then
			for line in love.filesystem.lines(FILENAME) do

				if first_line then
					for m in string.gmatch(line, "(	[^	]+)") do
						loc_langs[#loc_langs+1] = m
						loc_map[m] = {}
					end
					first_line = false


				else
					local i = 1
					local key = nil
					for m in string.gmatch(line, "([^	]+)") do
						if not key then
							key = m
						else
							print("key "..key)
							print("ln "..loc_langs[i])
							print("m "..m)
							loc_map[loc_langs[i]][key] = m
							i = i+1
						end

					end
				end

					for k, v in pairs(loc_map) do
						print("LANG "..k)
						for a, b in pairs(v) do
							print(a..": "..b)
						end
					end

			end
		end

end

function loc(text_key, ...)
	local ln = loc_langs[1]
	if loc_langs[loc_lang_index] and loc_map[loc_langs[loc_lang_index]] then
		ln = loc_langs[loc_lang_index]
	end

	local ret = loc_map[ln][text_key]

	if ret then

		for i = 1, select('#', ...) do
			ret = ret:gsub("%%"..i, select(i, ...))
		end

		return ret
	else
		return text_key
	end

end