--[[
	You and What Army — raise Joker convert cap (host / solo).
	Still requires Joker. Does not convert specials.
]]

_G.YouAndWhatArmy = _G.YouAndWhatArmy or {}
local YAWA = YouAndWhatArmy

YAWA._path = YAWA._path or ModPath
YAWA._data_path = YAWA._data_path or (SavePath .. "you_and_what_army.txt")
YAWA.settings = YAWA.settings or {}

YAWA.MIN_MINIONS = 2
YAWA.MAX_MINIONS = 32
YAWA.DEFAULT_MINIONS = 8
-- Extra dominated cops allowed on top of the joker cap (vanilla base room is 4).
YAWA.DOMINATE_SLACK = 4

function YAWA:DefaultSettings()
	return {
		enabled = true,
		max_minions = YAWA.DEFAULT_MINIONS
	}
end

function YAWA:ClampMinions(v)
	v = math.floor(tonumber(v) or YAWA.DEFAULT_MINIONS)
	if v < YAWA.MIN_MINIONS then
		v = YAWA.MIN_MINIONS
	end
	if v > YAWA.MAX_MINIONS then
		v = YAWA.MAX_MINIONS
	end
	return v
end

function YAWA:Load()
	self.settings = self:DefaultSettings()
	local file = io.open(self._data_path, "r")
	if file then
		local ok, data = pcall(json.decode, file:read("*all"))
		file:close()
		if ok and type(data) == "table" then
			for k, v in pairs(data) do
				self.settings[k] = v
			end
		end
	end
	self.settings.enabled = self.settings.enabled ~= false
	self.settings.max_minions = self:ClampMinions(self.settings.max_minions)
end

function YAWA:Save()
	if not self.settings then
		self:Load()
	end
	self.settings.max_minions = self:ClampMinions(self.settings.max_minions)
	local file = io.open(self._data_path, "w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

function YAWA:MaxMinions()
	if not self.settings or self.settings.max_minions == nil then
		self:Load()
	end
	return self:ClampMinions(self.settings.max_minions)
end

function YAWA:IsHost()
	if not Network or type(Network.is_server) ~= "function" then
		return true
	end
	local ok, server = pcall(Network.is_server, Network)
	if not ok then
		return true
	end
	return server == true
end

function YAWA:HasJoker()
	local pm = managers and managers.player
	if not pm or type(pm.has_category_upgrade) ~= "function" then
		return false
	end
	local ok, has = pcall(pm.has_category_upgrade, pm, "player", "convert_enemies")
	return ok and has and true or false
end

function YAWA:LimitActive()
	if not self.settings then
		self:Load()
	end
	if self.settings.enabled == false then
		return false
	end
	if not self:IsHost() then
		return false
	end
	return self:HasJoker()
end

YAWA:Load()
