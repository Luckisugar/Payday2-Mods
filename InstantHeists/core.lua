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
		-- MissionScriptElement base/element delays (dialogue reminder loops, staged waits).
		-- Off by default: speeding these makes Bain/radio lines spam (e.g. Car Shop C4).
		speed_mission_delays = false,
		-- Hold-to-interact bar (locks, bags, …). Separate so VHUD+ lock-mode can stay sane.
		speed_interact = true,
		-- Never scale pagers / other "dangerous cancel = alarm" holds (VHUD+ auto-hold).
		protect_dangerous_interact = true,
		-- When VanillaHUD Plus is present, keep scaled timers >= its lock threshold.
		vhud_compat = true,
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
	if self.settings.speed_mission_delays == nil then
		self.settings.speed_mission_delays = false
	end
	if self.settings.speed_interact == nil then
		self.settings.speed_interact = true
	end
	if self.settings.protect_dangerous_interact == nil then
		self.settings.protect_dangerous_interact = true
	end
	if self.settings.vhud_compat == nil then
		self.settings.vhud_compat = true
	end
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

--- Separate gate for MissionScriptElement delays (not drills / ElementTimer).
function IH:MissionDelaysOn()
	return self:TimersOn() and self.settings.speed_mission_delays == true
end

--- Hold-to-interact bar speed (BaseInteractionExt:_get_timer).
function IH:InteractSpeedOn()
	return self:TimersOn() and self.settings.speed_interact == true
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

--- Scale mission script delays only when that option is on.
function IH:ScaleMissionDelay(t)
	if not self:MissionDelaysOn() then
		return t
	end
	return self:ScaleTime(t)
end

--[[
	Dangerous holds: interrupt/cancel can raise alarm or fail stealth.
	VanillaHUD Plus (and similar) auto-hold these and map G/drop-bag to cancel
	with a warning. Speeding them below VHUD's MIN_TIMER_DURATION disables that.
]]
IH.DANGEROUS_INTERACT = {
	corpse_alarm_pager = true,
	-- revive/free are long holds; keep vanilla so lock + cancel UX stays intact
	revive = true,
	free = true
}

function IH:IsDangerousInteract(interaction)
	if not interaction then
		return false
	end
	local id = interaction.tweak_data
	if type(id) == "string" and self.DANGEROUS_INTERACT[id] then
		return true
	end
	if type(id) == "string" and string.find(id, "pager", 1, true) then
		return true
	end
	return false
end

--- VanillaHUD Plus lock threshold (default 5s). Falls back if VHUD missing/API differs.
function IH:VHUDMinTimerDuration()
	if not self.settings or self.settings.vhud_compat == false then
		return nil
	end
	if not _G.VHUDPlus or not VHUDPlus.getSetting then
		return nil
	end
	local ok, val = pcall(function()
		return VHUDPlus:getSetting({ "INTERACTION", "MIN_TIMER_DURATION" }, 5)
	end)
	if ok and type(val) == "number" and val > 0 then
		return val
	end
	-- VHUD present but setting unread — still use common default so lock mode works
	if _G.VHUDPlus then
		return 5
	end
	return nil
end

--- Scale hold-to-interact duration with VHUD / pager safety.
--- original_t = vanilla timer before any Instant Heists scaling.
function IH:ScaleInteractTime(interaction, original_t)
	if not original_t or original_t <= 0 then
		return original_t
	end
	if not self:InteractSpeedOn() then
		return original_t
	end
	if self.settings.protect_dangerous_interact ~= false and self:IsDangerousInteract(interaction) then
		return original_t
	end

	local scaled = self:ScaleTime(original_t)

	-- Keep long holds eligible for VHUD lock-mode (timer >= MIN_TIMER_DURATION).
	local min_lock = self:VHUDMinTimerDuration()
	if min_lock and original_t >= min_lock and scaled < min_lock then
		scaled = min_lock
	end

	return scaled
end

--- True if this mission element is (or targets) dialogue / radio VO.
function IH:IsDialogueElement(element)
	if not element then
		return false
	end
	local values = element._values
	if values then
		if values.dialogue and values.dialogue ~= "none" then
			return true
		end
		if values.can_not_be_muted ~= nil and values.dialogue then
			return true
		end
	end
	local name = element._editor_name
	if (not name or name == "") and element.editor_name then
		name = element:editor_name()
	end
	if not name then
		return false
	end
	name = string.lower(tostring(name))
	return string.find(name, "dialog", 1, true)
		or string.find(name, "dialogue", 1, true)
		or string.find(name, "bain", 1, true)
		or string.find(name, "narrator", 1, true)
		or string.find(name, "radio", 1, true)
		or string.find(name, "vo_", 1, true)
		or string.find(name, "_vo", 1, true)
end

if not IH.settings then
	IH:Load()
end
