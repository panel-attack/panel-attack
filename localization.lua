local FILENAME = "localization.tsv"

Localization = class(function(self)
	self.map = {}
	self.langs = {}
	self.codes = {}
	self.lang_index = 1
	self.init = false
end)

localization = Localization()

function Localization.get_list_codes_langs(self)
	return self.codes, self.langs
end

function Localization.get_language(self)
	return self.codes[self.lang_index]
end

function Localization.set_language(self, lang_code)
	for i, v in ipairs(self.codes) do
		if v == lang_code then
			self.lang_index = i
			break
		end
	end
	config.language_code = self.codes[self.lang_index]
end

function Localization.init(self)
	self.init = true
	local num_line = 1
	if love.filesystem.getInfo(FILENAME) then
		for line in love.filesystem.lines(FILENAME) do

			if num_line == 1 then
				for m in string.gmatch(line, "	([^	 ]+)") do
					self.codes[#self.codes+1] = m
					self.map[m] = {}
				end

			elseif num_line == 2 then
				for m in string.gmatch(line, "	([^	 ]+)") do
					self.langs[#self.langs+1] = m
				end

			else
				local i = 1
				local key = nil
				for m in string.gmatch(line, "([^	]+)") do
					if not key then
						key = m
					else
						self.map[self.codes[i]][key] = m
						i = i+1
					end
					if i > #self.codes then
						break
					end
				end
			end

			num_line = num_line + 1
		end

--[[		for k, v in pairs(self.map) do
			print("LANG "..k)
			for a, b in pairs(v) do
				print(a..": "..b)
			end
		end--]]

	end

	self:set_language(config.language_code)
end

function loc(text_key, ...)
	local self = localization
	local code = self.codes[1]
	if self.codes[self.lang_index] and self.map[self.codes[self.lang_index]] then
		code = self.codes[self.lang_index]
	end

	local ret = nil
	if self.init then
		ret = self.map[code][text_key]
	end

	if ret then
		for i = 1, select('#', ...) do
			local tmp = select(i, ...)
			ret = ret:gsub("%%"..i, tmp)
		end
	else
		ret = "#"..text_key
		for i = 1, select('#', ...) do
			ret = ret.." "..select(i, ...)
		end
	end

	return ret
end