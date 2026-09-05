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
		max_minions = YAWA.DEFAULT_MINIONS,
		max_threat = false,
		insta_recruit = false,
		no_yell_cooldown = false,
		lobby_yells = false
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
	self.settings.max_threat = self.settings.max_threat == true
	self.settings.insta_recruit = self.settings.insta_recruit == true
	self.settings.no_yell_cooldown = self.settings.no_yell_cooldown == true
	self.settings.lobby_yells = self.settings.lobby_yells == true
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

function YAWA:FeatureOn()
	if not self.settings then
		self:Load()
	end
	if self.settings.enabled == false then
		return false
	end
	return self:IsHost()
end

function YAWA:SettingOn(key)
	if not self:FeatureOn() then
		return false
	end
	return self.settings[key] == true
end

function YAWA:IsPlayerUnit(unit)
	if not alive(unit) or not unit.base then
		return false
	end
	local base = unit:base()
	if not base then
		return false
	end
	return base.is_local_player == true or base.is_husk_player == true
end

function YAWA:IsLocalPlayerUnit(unit)
	if not alive(unit) or not unit.base then
		return false
	end
	local base = unit:base()
	return base and base.is_local_player == true
end

function YAWA:AggressorAllowed(aggressor_unit)
	if not alive(aggressor_unit) then
		return false
	end
	if self.settings.lobby_yells == true then
		return self:IsPlayerUnit(aggressor_unit)
	end
	return self:IsLocalPlayerUnit(aggressor_unit)
end

function YAWA:CanDominate(data)
	if not data or not alive(data.unit) then
		return false
	end
	local unit = data.unit
	local brain = unit.brain and unit:brain()
	if brain and brain.converted and brain:converted() then
		return false
	end
	local gas = managers and managers.groupai and managers.groupai:state()
	if gas and type(gas.is_enemy_special) == "function" then
		local ok, special = pcall(gas.is_enemy_special, gas, unit)
		if ok and special then
			return false
		end
	end
	local s = data.char_tweak and data.char_tweak.surrender
	if not s or s == false then
		return false
	end
	if type(s) == "table" and s.impossible then
		return false
	end
	return true
end

function YAWA:InWhisper()
	local gas = managers and managers.groupai and managers.groupai:state()
	if not gas or type(gas.whisper_mode) ~= "function" then
		return false
	end
	local ok, whisper = pcall(gas.whisper_mode, gas)
	return ok and whisper and true or false
end

function YAWA:AtConvertCap()
	local pm = managers and managers.player
	if not pm or type(pm.chk_minion_limit_reached) ~= "function" then
		return true
	end
	local ok, reached = pcall(pm.chk_minion_limit_reached, pm)
	if not ok then
		return true
	end
	return reached == true
end

function YAWA:ShouldInstantCuff(aggressor_unit)
	if not self:FeatureOn() then
		return false
	end
	if not self:AggressorAllowed(aggressor_unit) then
		return false
	end
	return self.settings.max_threat == true or self.settings.insta_recruit == true
end

function YAWA:ShouldInstaRecruit(aggressor_unit)
	if not self:SettingOn("insta_recruit") then
		return false
	end
	if not self:AggressorAllowed(aggressor_unit) then
		return false
	end
	if not self:HasJoker() then
		return false
	end
	if self:InWhisper() then
		return false
	end
	return true
end

function YAWA:NoYellCooldownOn()
	return self:SettingOn("no_yell_cooldown")
end

function YAWA:TryConvert(unit, aggressor_unit)
	if not self:ShouldInstaRecruit(aggressor_unit) then
		return false
	end
	if self:AtConvertCap() then
		return false
	end
	if not alive(unit) then
		return false
	end
	local brain = unit.brain and unit:brain()
	if brain and brain.converted and brain:converted() then
		return false
	end
	local gas = managers and managers.groupai and managers.groupai:state()
	if not gas or type(gas.convert_hostage_to_criminal) ~= "function" then
		return false
	end
	if type(gas.is_enemy_special) == "function" then
		local ok_s, special = pcall(gas.is_enemy_special, gas, unit)
		if ok_s and special then
			return false
		end
	end
	local ok, err = pcall(gas.convert_hostage_to_criminal, gas, unit, nil)
	if not ok then
		if log then
			log("[You and What Army] convert failed: " .. tostring(err))
		end
		return false
	end
	brain = unit.brain and unit:brain()
	return brain and brain.converted and brain:converted() or false
end

YAWA:Load()
