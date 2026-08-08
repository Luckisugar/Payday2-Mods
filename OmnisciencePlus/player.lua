--[[
	Omniscience+ v3.2.0 — max diagnostics + multi-path tick

	Ticks from:
	  1) PlayerManager:update  (primary — hard to steal)
	  2) PlayerStandard:update wrap (backup)
	  3) Hooks:PostHook PlayerStandard update (backup)

	Debug sinks (all of them):
	  - BLT log via log()
	  - mods/saves/omp_debug.txt  (always)
	  - mods/saves/omp_last.txt   (single-line last status, easy to open)
]]

_G.OmnisciencePlus = _G.OmnisciencePlus or {}
OmnisciencePlus.settings = OmnisciencePlus.settings or {
	enabled = true,
	require_skill = true,
	start_t_tenths = 10,
	interval_t_tenths = 10,
	radius_m = 75,
	target_resense_t = 10,
	marks_per_tick = 0,
	mark_items = true,
	mark_cameras = true,
	permanent_marks = false,
}

if not OmnisciencePlus.StartT then
	function OmnisciencePlus:StartT()
		return (self.settings.start_t_tenths or 10) / 10
	end
	function OmnisciencePlus:IntervalT()
		return (self.settings.interval_t_tenths or 10) / 10
	end
	function OmnisciencePlus:SenseRadius()
		return (self.settings.radius_m or 75) * 100
	end
	function OmnisciencePlus:ResenseT()
		return self.settings.target_resense_t or 10
	end
	function OmnisciencePlus:Suspend()
		self._suspended = true
		self._diag = 0
	end
	function OmnisciencePlus:Resume()
		self._suspended = false
		self._diag = 0
		self._err_logged = nil
		self._hb_t = 0
	end
end

local mvec3_dis_sq = mvector3.distance_sq
local mvec3_set = mvector3.set
local PERMA_MULT = 1000000

local SKIP_INTERACTION = {
	corpse_dispose = true,
	corpse_alarm_pager = true,
	free_civ = true,
	hostage_move = true,
	hostage_stay = true,
	intimidate = true,
	require_item = true,
}

local IMPORTANT_NPC_KEYS = {
	"manager", "security", "boss", "captain", "director", "chief",
	"curator", "auctioneer", "taxman", "pilot", "locke", "ralph",
	"researcher", "scientist", "engineer", "server", "technician",
	"keycard", "key_card", "gang", "mobster", "yakuza", "biker",
	"chavez", "hector", "boris", "butler", "yufuwang", "impersonator",
	"helper", "worker_docks", "maintenance", "fbi", "agent", "marshal",
	"officer", "civilian_enemy", "vip", "senator", "banker", "dealer",
}

local function S()
	return OmnisciencePlus.settings or {}
end

local function save_dir()
	return SavePath or "mods/saves/"
end

local function dbg(msg, also_last)
	local line = string.format("[%s] %s", tostring(os.date("%H:%M:%S")), msg)
	if log then
		log("[Omniscience+] " .. msg)
	end
	local f = io.open(save_dir() .. "omp_debug.txt", "a")
	if f then
		f:write(line)
		f:write("\n")
		f:close()
	end
	if also_last ~= false then
		local f2 = io.open(save_dir() .. "omp_last.txt", "w")
		if f2 then
			f2:write(line)
			f2:write("\n")
			f2:close()
		end
	end
end

-- IMPORTANT: Do NOT check Global.load_level — it stays true for the WHOLE heist
-- and was blocking every tick (root cause of "items only / nothing works").
-- Only pause when we explicitly Suspend() or when returning to menu.
local function suspended()
	if OmnisciencePlus._suspended then
		return true, "flag"
	end
	if Global then
		if Global.load_start_menu then
			return true, "Global.load_start_menu"
		end
		if Global.load_start_menu_lobby then
			return true, "Global.load_start_menu_lobby"
		end
	end
	return false, nil
end

local function has_skill()
	local s = S()
	if s.enabled == false then
		return false, "mod_disabled"
	end
	if s.require_skill == false then
		return true, "skill_not_required"
	end
	if not managers.player then
		return false, "no_player_manager"
	end
	if managers.player:has_category_upgrade("player", "standstill_omniscience") then
		return true, "has_sixth_sense"
	end
	return false, "missing_sixth_sense_skill"
end

local function mark_budget()
	local n = tonumber(S().marks_per_tick)
	if not n or n <= 0 then
		return math.huge
	end
	return n
end

local function fade_mult(base)
	if S().permanent_marks == true then
		return PERMA_MULT
	end
	return base or 1
end

local function is_dead(unit)
	local dmg = unit.character_damage and unit:character_damage()
	return dmg and dmg.dead and dmg:dead()
end

local function is_escort(unit)
	if not alive(unit) or not unit:base() then
		return false
	end
	local ok, tw = pcall(function()
		return unit:base():char_tweak()
	end)
	return ok and tw and tw.is_escort == true
end

local function unit_pos(unit)
	if unit.movement and unit:movement() and unit:movement().m_pos then
		return unit:movement():m_pos()
	end
	return unit:position()
end

local function unit_in_range(unit, pos, r2)
	if not alive(unit) then
		return false
	end
	local upos = unit_pos(unit)
	return upos and mvec3_dis_sq(pos, upos) <= r2
end

local function unit_tweak_name(unit)
	if not alive(unit) or not unit:base() then
		return ""
	end
	local n = unit:base()._tweak_table
	return n and string.lower(tostring(n)) or ""
end

local function is_important_npc(unit)
	local n = unit_tweak_name(unit)
	if n == "" then
		return false
	end
	if string.find(n, "casual", 1, true) or string.find(n, "shopper", 1, true)
		or string.find(n, "tourist", 1, true) or string.find(n, "partygoer", 1, true)
	then
		if not string.find(n, "manager", 1, true) and not string.find(n, "security", 1, true) then
			return false
		end
	end
	for _, key in ipairs(IMPORTANT_NPC_KEYS) do
		if string.find(n, key, 1, true) then
			return true
		end
	end
	return false
end

local function clear_gpc_cd(unit)
	local gpc = managers.game_play_central
	if gpc and gpc._auto_highlighted_enemies then
		gpc._auto_highlighted_enemies[unit:key()] = nil
	end
end

local function mark_person(unit)
	if not alive(unit) or is_dead(unit) then
		return false, "dead_or_nil"
	end

	local mult = 1
	if managers.player then
		mult = managers.player:upgrade_value("player", "mark_enemy_time_multiplier", 1) or 1
	end
	mult = fade_mult(mult)

	local steps = {}

	-- NO auto_highlight_enemy — it network-syncs contours and freezes quit→menu.
	-- Local contour only (sync=false).
	if not unit.contour or not unit:contour() then
		return false, "no_contour_ext"
	end
	local cont = unit:contour()
	local ctype = "mark_enemy"
	if managers.player and unit:base() and unit:base().get_type then
		local ok_t, t = pcall(function()
			return managers.player:get_contour_for_marked_enemy(unit:base():get_type())
		end)
		if ok_t and t then
			ctype = t
		end
	end
	local ok1, s1 = pcall(function()
		return cont:add(ctype, false, mult)
	end)
	if not (ok1 and s1) then
		ok1, s1 = pcall(function()
			return cont:add("mark_enemy", false, mult)
		end)
	end
	table.insert(steps, string.format("local %s=%s", ctype, tostring(ok1 and s1 ~= nil)))
	return ok1 and s1 ~= nil, table.concat(steps, ";")
end

local function mark_camera(unit)
	if not alive(unit) or not unit:contour() then
		return false
	end
	local mult = fade_mult(1)
	pcall(function()
		unit:contour():add("mark_unit", false, mult)
	end)
	return true
end

local function mark_item(unit)
	if not alive(unit) or not unit:contour() then
		return false
	end
	local mult = fade_mult(1)
	pcall(function()
		unit:contour():add("generic_interactable", false, mult)
	end)
	pcall(function()
		unit:contour():add("highlight", false, mult)
	end)
	return true
end

local function collect_people(pos, radius)
	local out = {}
	local r2 = radius * radius
	local seen = {}
	local stats = { enemy_reg = 0, special = 0, sphere_e = 0, sphere_t = 0, skip_dead = 0, skip_range = 0, skip_escort = 0 }

	local function push(unit, kind)
		if not alive(unit) or seen[unit:key()] then
			return
		end
		if is_escort(unit) then
			stats.skip_escort = stats.skip_escort + 1
			return
		end
		if is_dead(unit) then
			stats.skip_dead = stats.skip_dead + 1
			return
		end
		if not unit_in_range(unit, pos, r2) then
			stats.skip_range = stats.skip_range + 1
			return
		end
		seen[unit:key()] = true
		local upos = unit_pos(unit)
		table.insert(out, {
			unit = unit,
			dist = upos and mvec3_dis_sq(pos, upos) or 0,
			kind = kind or "enemy",
			tweak = unit_tweak_name(unit),
			has_contour = unit.contour and unit:contour() and true or false,
		})
	end

	if managers.enemy then
		local enemies = managers.enemy:all_enemies()
		if enemies then
			for _, data in pairs(enemies) do
				stats.enemy_reg = stats.enemy_reg + 1
				push(data and (data.unit or data), "enemy")
			end
		end
		local civs = managers.enemy:all_civilians()
		if civs then
			for _, data in pairs(civs) do
				local unit = data and (data.unit or data)
				if alive(unit) and is_important_npc(unit) then
					stats.special = stats.special + 1
					push(unit, "special")
				end
			end
		end
	end

	local ok_m, mask = pcall(function()
		return managers.slot:get_mask("enemies")
	end)
	if ok_m and mask then
		local units = World:find_units_quick("sphere", pos, radius, mask)
		if units then
			for _, unit in ipairs(units) do
				stats.sphere_e = stats.sphere_e + 1
				push(unit, "enemy")
			end
		end
	end

	local civ_set = {}
	if managers.enemy and managers.enemy:all_civilians() then
		for _, cd in pairs(managers.enemy:all_civilians()) do
			local cu = cd and (cd.unit or cd)
			if alive(cu) then
				civ_set[cu:key()] = true
			end
		end
	end
	ok_m, mask = pcall(function()
		return managers.slot:get_mask("trip_mine_targets")
	end)
	if ok_m and mask then
		local units = World:find_units_quick("sphere", pos, radius, mask)
		if units then
			for _, unit in ipairs(units) do
				stats.sphere_t = stats.sphere_t + 1
				if alive(unit) then
					if civ_set[unit:key()] then
						if is_important_npc(unit) then
							push(unit, "special")
						end
					else
						push(unit, "enemy")
					end
				end
			end
		end
	end

	table.sort(out, function(a, b)
		return a.dist < b.dist
	end)
	return out, stats
end

local function collect_cameras(pos, radius)
	local out = {}
	if S().mark_cameras == false then
		return out
	end
	local gstate = managers.groupai and managers.groupai:state()
	local cams = gstate and gstate._security_cameras
	if not cams then
		return out
	end
	local r2 = radius * radius
	for _, unit in pairs(cams) do
		if alive(unit) and unit_in_range(unit, pos, r2) then
			local base = unit:base()
			if not (base and base.destroyed and base:destroyed()) then
				local upos = unit_pos(unit)
				table.insert(out, { unit = unit, dist = upos and mvec3_dis_sq(pos, upos) or 0 })
			end
		end
	end
	return out
end

local function collect_items(pos, radius)
	local out = {}
	if S().mark_items == false then
		return out
	end
	local interactive = managers.interaction and managers.interaction._interactive_units
	if not interactive then
		return out
	end
	local r2 = radius * radius
	local function consider(unit)
		if not alive(unit) or not unit:interaction() or not unit:contour() then
			return
		end
		local inter = unit:interaction()
		if not inter:active() then
			return
		end
		local tid = inter.tweak_data
		if type(tid) == "function" then
			tid = inter:tweak_data()
		end
		if tid and SKIP_INTERACTION[tid] then
			return
		end
		if unit_in_range(unit, pos, r2) then
			local upos = unit_pos(unit)
			table.insert(out, { unit = unit, dist = upos and mvec3_dis_sq(pos, upos) or 0 })
		end
	end
	if interactive[1] ~= nil or #interactive > 0 then
		for _, unit in ipairs(interactive) do
			consider(unit)
		end
	else
		for unit, _ in pairs(interactive) do
			if type(unit) ~= "number" then
				consider(unit)
			end
		end
	end
	return out
end

-- Get PlayerStandard state from local player (for PlayerManager tick)
local function get_player_standard_state()
	local unit = managers.player and managers.player:player_unit()
	if not alive(unit) then
		return nil, "no_player_unit"
	end
	local mov = unit:movement()
	if not mov then
		return nil, "no_movement"
	end
	local state = mov._current_state
	if not state then
		return nil, "no_current_state"
	end
	-- Prefer standard-like states that have _state_data / movement helpers
	if not state._state_data then
		return nil, "state_has_no_state_data:" .. tostring(state.NAME or state)
	end
	return state, nil
end

local function do_sense(self, t, dt, source)
	source = source or "?"
	-- Fast path: zero work / zero disk when leaving heist
	if OmnisciencePlus._suspended then
		return
	end
	OmnisciencePlus._tick_n = (OmnisciencePlus._tick_n or 0) + 1

	local sus, sus_why = suspended()
	if sus then
		return
	end

	if not managers or not managers.player or not managers.groupai then
		if (OmnisciencePlus._tick_n % 180) == 1 then
			dbg("tick#" .. OmnisciencePlus._tick_n .. " source=" .. source .. " no managers")
		end
		return
	end

	if not self or not alive(self._unit) then
		if (OmnisciencePlus._tick_n % 180) == 1 then
			dbg("tick#" .. OmnisciencePlus._tick_n .. " source=" .. source .. " bad self/unit")
		end
		return
	end

	local start_t = OmnisciencePlus:StartT()
	local interval_t = OmnisciencePlus:IntervalT()
	local radius = OmnisciencePlus:SenseRadius()
	local resense_base = OmnisciencePlus:ResenseT()
	local sense_exit_sq = 4900

	if tweak_data and tweak_data.player then
		tweak_data.player.omniscience = tweak_data.player.omniscience or {}
		local o = tweak_data.player.omniscience
		o.start_t = start_t
		o.interval_t = interval_t
		o.sense_radius = radius
		o.target_resense_t = resense_base
		o.sense_exit_sq = sense_exit_sq
	end

	-- Works in stealth AND loud (no whisper_mode gate).
	local gstate = managers.groupai:state()
	local whisper = gstate and gstate.whisper_mode and gstate:whisper_mode()
	local skill_ok, skill_why = has_skill()

	local blocked = nil
	if not skill_ok then
		blocked = skill_why
	elseif managers.player:current_state() == "civilian" then
		blocked = "civilian_state"
	elseif self._interacting and self:_interacting() then
		blocked = "interacting"
	elseif self._ext_movement and self._ext_movement:has_carry_restriction() then
		blocked = "carry_restriction"
	elseif self.is_deploying and self:is_deploying() then
		blocked = "deploying"
	elseif self._is_throwing_projectile and self:_is_throwing_projectile() then
		blocked = "projectile"
	elseif self._is_meleeing and self:_is_meleeing() then
		blocked = "melee"
	elseif self._on_zipline and self:_on_zipline() then
		blocked = "zipline"
	elseif self.running and self:running() then
		blocked = "running"
	elseif self.in_air and self:in_air() then
		blocked = "in_air"
	elseif self.shooting and self:shooting() then
		blocked = "shooting"
	end

	local sd = self._state_data
	if not sd then
		dbg("source=" .. source .. " NO _state_data on state")
		return
	end

	-- Heartbeat every 10s (was 2s — disk spam during leave frames)
	OmnisciencePlus._hb_t = OmnisciencePlus._hb_t or 0
	if t >= OmnisciencePlus._hb_t then
		OmnisciencePlus._hb_t = t + 10
		local reg = 0
		if managers.enemy and managers.enemy:all_enemies() then
			for _ in pairs(managers.enemy:all_enemies()) do
				reg = reg + 1
			end
		end
		local st_name = "?"
		pcall(function()
			if game_state_machine then
				st_name = tostring(game_state_machine:current_state_name())
			end
		end)
		dbg(string.format(
			"HB src=%s skill=%s(%s) whisper=%s blocked=%s moving=%s reg_enemies=%d state=%s omp_t=%s t=%.1f",
			source,
			tostring(skill_ok),
			tostring(skill_why),
			tostring(whisper),
			tostring(blocked or "none"),
			tostring(self._moving and true or false),
			reg,
			st_name,
			tostring(sd.omp_t),
			t
		))
	end

	if blocked then
		sd.omp_t = nil
		sd.omp_pos = nil
		return
	end

	local player_m_pos = self._unit:movement() and self._unit:movement():m_pos()
	if not player_m_pos then
		dbg("no m_pos src=" .. source)
		return
	end

	if self._moving then
		if sd.omp_pos and mvec3_dis_sq(player_m_pos, sd.omp_pos) > sense_exit_sq then
			sd.omp_t = nil
			sd.omp_pos = nil
			return
		end
		if not sd.omp_pos then
			return
		end
	end

	if not self._moving and not sd.omp_pos then
		sd.omp_pos = Vector3()
		mvec3_set(sd.omp_pos, player_m_pos)
	end

	if not sd.omp_t then
		sd.omp_t = t + start_t
		dbg(string.format("ARMED stand-still %.1fs src=%s", start_t, source))
	end

	if not sd.omp_pos or t < sd.omp_t then
		return
	end

	-- PULSE
	local resense = (S().permanent_marks == true) and 999999 or resense_base
	local budget = mark_budget()
	sd.omp_detected = sd.omp_detected or {}
	local detected = sd.omp_detected

	local people, cstats = collect_people(player_m_pos, radius)
	local cams = collect_cameras(player_m_pos, radius)
	local items = collect_items(player_m_pos, radius)

	local new_p, new_c, new_i = 0, 0, 0
	local samples = {}
	local mark_details = {}

	for _, entry in ipairs(people) do
		if new_p >= budget then
			break
		end
		local key = entry.unit:key()
		local until_t = detected[key]
		if not until_t or until_t <= t then
			local okm, detail = mark_person(entry.unit)
			if okm then
				detected[key] = t + resense
				new_p = new_p + 1
				if #samples < 6 then
					table.insert(samples, string.format("%s(c=%s)", entry.tweak or "?", tostring(entry.has_contour)))
				end
				if #mark_details < 3 then
					table.insert(mark_details, tostring(detail))
				end
			end
		end
	end

	for _, entry in ipairs(cams) do
		local key = entry.unit:key()
		local until_t = detected[key]
		if not until_t or until_t <= t then
			if mark_camera(entry.unit) then
				detected[key] = t + resense
				new_c = new_c + 1
			end
		end
	end

	for _, entry in ipairs(items) do
		local key = entry.unit:key()
		local until_t = detected[key]
		if not until_t or until_t <= t then
			if mark_item(entry.unit) then
				detected[key] = t + resense
				new_i = new_i + 1
			end
		end
	end

	OmnisciencePlus._diag = (OmnisciencePlus._diag or 0) + 1
	dbg(string.format(
		"PULSE #%d src=%s people=%d new_p=%d cam=%d new_c=%d item=%d new_i=%d budget=%s range=%.0fm | coll enemy_reg=%d special=%d sph_e=%d sph_t=%d skip_rng=%d skip_dead=%d | sample=[%s] | mark=[%s]",
		OmnisciencePlus._diag,
		source,
		#people,
		new_p,
		#cams,
		new_c,
		#items,
		new_i,
		budget == math.huge and "all" or tostring(budget),
		radius / 100,
		cstats.enemy_reg,
		cstats.special,
		cstats.sphere_e,
		cstats.sphere_t,
		cstats.skip_range,
		cstats.skip_dead,
		table.concat(samples, ","),
		table.concat(mark_details, " || ")
	))

	sd.omp_t = t + interval_t
	mvec3_set(sd.omp_pos, player_m_pos)
end

-- ---------- INSTALL (minimal, unload-safe) ----------
-- ONLY SuperBLT PostHook — no PlayerManager wrap, no raw update replace.
-- (PM wrap + nested re-wraps caused infinite load on quit.)

if not OmnisciencePlus._posthook_ps then
	OmnisciencePlus._posthook_ps = true
	Hooks:PostHook(PlayerStandard, "update", "OmnisciencePlus_PostUpdate323", function(self, t, dt)
		if OmnisciencePlus._suspended then
			return
		end
		-- If player unit is dying, skip (leave heist frames)
		if not self._unit or not alive(self._unit) then
			return
		end
		pcall(do_sense, self, t, dt, "PostHook")
	end)
	dbg("INSTALLED PostHook only (no PM wrap)")
end

Hooks:PostHook(PlayerStandard, "init", "OmnisciencePlus_Init323", function()
	OmnisciencePlus:Resume()
end)

Hooks:PostHook(PlayerStandard, "enter", "OmnisciencePlus_Enter323", function()
	OmnisciencePlus:Resume()
end)

Hooks:PostHook(PlayerStandard, "exit", "OmnisciencePlus_Exit323", function(self)
	-- Do NOT suspend here — exit also fires for normal state swaps mid-heist.
	-- Suspend only via setup.lua leave/menu hooks.
	if self._state_data then
		self._state_data.omp_t = nil
		self._state_data.omp_pos = nil
		-- keep omp_detected so permanent/resense survives state swap
	end
end)

do
	local f = io.open(save_dir() .. "omp_debug.txt", "w")
	if f then
		f:write("--- Omniscience+ v3.2.3 (no PM wrap, no auto_highlight, suspend on exit) ---\n")
		f:close()
	end
	local f2 = io.open(save_dir() .. "omp_last.txt", "w")
	if f2 then
		f2:write("v3.2.3 ready — quit should not hang\n")
		f2:close()
	end
end

dbg("player.lua v3.2.3 LOADED — unload hardened")
