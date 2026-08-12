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
		-- Never speed The Diamond floor-path lifetime (and similar short puzzle countdowns).
		-- With 5x speed a 30s path becomes 6s — shorter than the light sequence — path
		-- randomizes before you step → "wrong tile" on a still-correct-looking first plate.
		protect_puzzle_timers = true,
		speed_multiplier = 5,
		crouch_only = false,
		-- Full stealth invisibility: guards/cams never detect you.
		ghost_mode = false
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
	if self.settings.protect_puzzle_timers == nil then
		self.settings.protect_puzzle_timers = true
	end
	if self.settings.ghost_mode == nil then
		self.settings.ghost_mode = false
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
--- On The Diamond with puzzle protection: never speed script delays either
--- (path light staging / expire chains sometimes use element delays).
function IH:MissionDelaysOn()
	if not self:TimersOn() or self.settings.speed_mission_delays ~= true then
		return false
	end
	if self.settings.protect_puzzle_timers ~= false and self:LevelId() == "mus" then
		return false
	end
	return true
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

--- Ghost Mode master gate (100% undetectable to AI / cameras).
function IH:GhostOn()
	return self:IsEnabled() and self.settings and self.settings.ghost_mode == true
end

--- Level id helper (e.g. "mus" = The Diamond).
--- Uses _G.Global so this works when called from core:module scripts.
function IH:LevelId()
	local G = rawget(_G, "Global") or Global
	return G and G.game_settings and G.game_settings.level_id or nil
end

function IH:ElementEditorName(element)
	if not element then
		return nil
	end
	local name = element._editor_name
	if (not name or name == "") and element.editor_name then
		local ok, result = pcall(function()
			return element:editor_name()
		end)
		if ok then
			name = result
		end
	end
	if type(name) ~= "string" or name == "" then
		return nil
	end
	return name
end

--- Resolve ElementTimer configured duration (handles random-table values).
function IH:ElementTimerConfigured(element)
	if not element then
		return nil
	end
	local v = element._values and element._values.timer
	if v == nil then
		return nil
	end
	if type(v) == "number" then
		return v
	end
	if type(v) == "table" then
		-- Common PD2 shapes: {30,30} or {1,30} / random table
		local a, b = tonumber(v[1]), tonumber(v[2])
		if a and b then
			return (a + b) * 0.5
		end
		if a then
			return a
		end
		if v.rnd and type(v.rnd) == "table" then
			local r1, r2 = tonumber(v.rnd[1]), tonumber(v.rnd[2])
			if r1 and r2 then
				return (r1 + r2) * 0.5
			end
		end
	end
	return tonumber(v)
end

--[[
	The Diamond (mus) ElementTimer policy — v1.2.1

	Root cause of "path helper correct, first tile alarms":
	  ElementTimer is AUTHORITATIVE (gate open / path reset when _timer hits 0).
	  DigitalGui is a SEPARATE display that counts its own dt in parallel.
	  v1.2.0 blocked DigitalGui on mus (UI looked "normal") but still sped most
	  ElementTimers — name/duration heuristics never matched the path timer
	  (_values.timer is often a random table; editor names are not "path").
	  Result: logic expires the path in ~6s, UI still shows ~30–90s, first step
	  is already the NEW path → Bain "wrong tile". Same desync as the time lock
	  (UI 90s, door open at ~5s).

	Policy when protect_puzzle_timers is ON (default):
	  On mus → DENY speed for ALL ElementTimers except an explicit time-lock
	  WHITELIST. Unknown names (including the path lifetime) stay vanilla.
	  Linked DigitalGui units inherit the ElementTimer's speed mult each frame
	  so UI and logic never desync again.
]]
function IH:IsMusTimeLockTimer(element)
	local name = self:ElementEditorName(element)
	if not name then
		return false
	end
	local n = string.lower(name)
	-- Explicit time-lock / security-gate names only (speed these on mus).
	if string.find(n, "time_lock", 1, true)
		or string.find(n, "timelock", 1, true)
		or string.find(n, "time lock", 1, true)
		or string.find(n, "security_lock", 1, true)
		or string.find(n, "keycard_timer", 1, true)
		or string.find(n, "security_timer", 1, true)
	then
		return true
	end
	-- "lock" + "time" both present (e.g. lock_timer_01)
	if string.find(n, "lock", 1, true) and string.find(n, "time", 1, true) then
		return true
	end
	return false
end

function IH:ShouldSpeedElementTimer(element)
	if not self:TimersOn() then
		return false
	end

	-- Off-mus: speed everything (drills/cooks/etc. use TimerGui, not this path).
	local level_id = self:LevelId()
	if level_id ~= "mus" or self.settings.protect_puzzle_timers == false then
		return true
	end

	-- On mus with protection: whitelist time locks only.
	if self:IsMusTimeLockTimer(element) then
		self._sped_timer_logged = self._sped_timer_logged or {}
		local key = self:ElementEditorName(element) or "?"
		if not self._sped_timer_logged[key] then
			self._sped_timer_logged[key] = true
			if log then
				log(string.format(
					"[InstantHeists] mus TIME LOCK sped: name=%s t=%s mult=%s",
					tostring(key),
					tostring(self:ElementTimerConfigured(element)),
					tostring(self:SpeedMult())
				))
			end
		end
		return true
	end

	-- Everything else on mus (path lifetime, gas, unknowns) = vanilla.
	self._protected_timer_logged = self._protected_timer_logged or {}
	local key = self:ElementEditorName(element) or ("id_" .. tostring(element._id or "?"))
	if not self._protected_timer_logged[key] then
		self._protected_timer_logged[key] = true
		if log then
			log(string.format(
				"[InstantHeists] mus ElementTimer PROTECTED (no speed): name=%s t=%s remaining=%s",
				tostring(key),
				tostring(self:ElementTimerConfigured(element)),
				tostring(element._timer)
			))
		end
	end
	return false
end

--- Mark DigitalGui units linked to this ElementTimer with the same speed mult.
--- Call every ElementTimer:update_timer so UI dt matches logic dt.
function IH:MarkLinkedDigitalGuis(element, mult)
	if not element or not element._digital_gui_units then
		return
	end
	mult = tonumber(mult) or 1
	for _, unit in ipairs(element._digital_gui_units) do
		if unit and alive(unit) then
			local gui = nil
			if unit.digital_gui then
				local ok, g = pcall(function()
					return unit:digital_gui()
				end)
				if ok then
					gui = g
				end
			end
			if gui then
				gui._ih_dt_mult = mult
			end
		end
	end
end

--- DigitalGui speed: prefer per-gui mark from ElementTimer; else global policy.
function IH:DigitalGuiSpeedMult(gui)
	if not self:TimersOn() then
		return 1
	end
	-- Linked to an ElementTimer that set a mult this session
	if gui and type(gui._ih_dt_mult) == "number" and gui._ih_dt_mult >= 1 then
		return gui._ih_dt_mult
	end
	-- Unlinked DigitalGui on mus with protection: never guess — stay vanilla
	-- (path box clock must not race).
	if self.settings.protect_puzzle_timers ~= false and self:LevelId() == "mus" then
		return 1
	end
	return self:SpeedMult()
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
