--[[
	Instant Heists — shared settings + helpers
]]

_G.InstantHeists = _G.InstantHeists or {}
local IH = InstantHeists

IH._path = IH._path or ModPath
IH._data_path = IH._data_path or (SavePath .. "instant_heists.txt")

function IH:DefaultSettings()
	return {
		enabled = true,
		bypass_requirements = true,
		speed_timers = true,
		speed_multiplier = 5,
		crouch_only = false
	}
end

function IH:Load()
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
	self.settings.speed_multiplier = math.max(1, math.min(20, tonumber(self.settings.speed_multiplier) or 5))
end

function IH:Save()
	local file = io.open(self._data_path, "w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

function IH:IsEnabled()
	return self.settings and self.settings.enabled == true
end

--- Local player crouching (ducking).
function IH:IsCrouching()
	local player = managers.player and managers.player:player_unit()
	if not alive(player) then
		return false
	end
	local state = player:movement() and player:movement():current_state()
	if state and state.ducking then
		return state:ducking() == true
	end
	if state and state._state_data then
		return state._state_data.ducking == true
	end
	return false
end

--- Master gate: enabled, and crouching if crouch_only is on.
function IH:CheatsActive()
	if not self:IsEnabled() then
		return false
	end
	if self.settings.crouch_only then
		return self:IsCrouching()
	end
	return true
end

function IH:BypassOn()
	return self:CheatsActive() and self.settings.bypass_requirements == true
end

function IH:TimersOn()
	return self:CheatsActive() and self.settings.speed_timers == true
end

--- How many times faster waits should be (5 = 5x faster = 1/5 duration).
function IH:SpeedMult()
	if not self:TimersOn() then
		return 1
	end
	local m = tonumber(self.settings.speed_multiplier) or 5
	return math.max(1, math.min(20, m))
end

--- Scale a positive duration down by the speed multiplier.
function IH:ScaleTime(t)
	if not t or t <= 0 then
		return t
	end
	local m = self:SpeedMult()
	if m <= 1 then
		return t
	end
	return math.max(0.05, t / m)
end

if not IH.settings then
	IH:Load()
end
