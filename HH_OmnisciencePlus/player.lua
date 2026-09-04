--[[
	Omniscience+ v3.4.3
	Sixth Sense only. Stand still to pulse.
	Contour first; HUD icon only if contour fails.
	Per-category mark checkboxes.
	Cameras: refresh every pulse, fade matches re-mark window (no blink).
	Circuit boxes: active open-panel OR rewire, not dummy slots, not already-used.
	Dropped bags / body bags / computers default OFF.
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
	mark_circuit_boxes = true,
	mark_people = true,
	mark_pickups = true,
	mark_loot = true,
	mark_loose_loot = true,
	mark_atms = true,
	mark_crates = true,
	mark_safes = true,
	mark_computers = false,
	mark_body_bags = false,
	mark_dropped_bags = false,
	permanent_marks = false,
	debug_log = false,
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
		if self.ClearQuestWaypoints then
			pcall(function()
				self:ClearQuestWaypoints()
			end)
		end
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
local WP_PREFIX = "omp_q_"

local SKIP_INTERACTION = {
	corpse_dispose = true,
	corpse_alarm_pager = true,
	free_civ = true,
	hostage_move = true,
	hostage_stay = true,
	intimidate = true,
	intimidate_and_search = true,
	require_item = true,
	ammo_bag = true,
	doctor_bag = true,
	first_aid_kit = true,
	bodybags_bag = true,
	grenade_crate = true,
	ecm_jammer = true,
	sentry_gun = true,
	sentry_gun_fire_mode = true,
	sentry_gun_refill = true,
	sentry_gun_revive = true,
	trip_mine = true,
	revive = true,
	free = true,
	melee_weapon_panel = true,
	mask_off = true,
	mask_on = true,
	gage_assignment = true,
	cash_desk = true,
	driving_drive = true,
	sewer_manhole = true,
	carry_drop = true,
	painting_carry_drop = true,
	safe_carry_drop = true,
	goat_carry_drop = true,
}

local SKIP_CAMERA_TID = {
	access_camera = true,
	access_camera_x_axis = true,
	camera_access = true,
	security_camera = true,
	tape_loop = true,
	activate_camera = true,
}

-- Not used as a skip list anymore (loose loot is in MISSION_TID).
local SKIP_SMALL_LOOT = {
}

local CASUAL_CIV_KEYS = {
	"casual", "shopper", "tourist", "partygoer", "striper", "stripper",
	"civilian_female", "civilian_male", "civ_female", "civ_male",
}

local IMPORTANT_NPC_KEYS = {
	"manager", "boss", "captain", "director", "chief",
	"curator", "auctioneer", "taxman", "pilot", "locke", "ralph",
	"researcher", "scientist", "engineer", "technician",
	"keycard", "key_card",
	"chavez", "hector", "boris", "butler", "yufuwang", "impersonator",
	"helper", "worker_docks", "maintenance",
	"civilian_enemy", "vip", "senator", "banker", "dealer",
	"mayor", "governor", "president", "secretary",
}

local PROTECT_NPC_KEYS = {
	"escort", "hostage_mission", "vip", "mayor", "senator", "taxman",
	"chavez", "almir", "butler", "yufu", "yufuwang", "roman", "keegan",
	"pilot", "boat", "hector", "bain", "locke", "gangster_boss_friend",
	"civilian_mrs", "old_man", "matt", "cuba", "norman",
	"scientist_friend", "protected", "keep_alive", "no_kill",
}

local KILL_NPC_KEYS = {
	"tank", "bulldozer", "shield", "taser", "tazer", "spooc", "cloaker",
	"sniper", "medic", "phalanx", "winters", "dozer", "minigun",
	"marshal_marksman", "marshal_shield", "heavy_swat_sniper",
	"hector_boss", "chavez_boss", "biker_boss", "mobster_boss", "drug_lord",
	"yakuza_boss", "gangster_boss", "captain_team",
}

local MANAGER_KEYS = {
	"manager", "bank_manager", "director", "chief", "curator", "auctioneer",
	"taxman", "banker", "secretary", "boss_office", "office_manager",
}

local KEYCARD_NAME_KEYS = {
	"keycard", "key_card", "bank_manager", "manager_key", "security_key",
}

-- Exact interaction ids only. No unit-path / substring ghosts.
local MISSION_TID = {
	pickup_keycard = "pickup",
	pickup_hotel_room_keycard = "pickup",
	lrm_keycard = "pickup",
	corp_key_fob = "pickup",
	trai_usb_key = "pickup",
	gen_pku_crowbar = "pickup",
	pickup_boards = "pickup",
	stash_planks_pickup = "pickup",
	muriatic_acid = "pickup",
	hydrogen_chloride = "pickup",
	caustic_soda = "pickup",
	gen_pku_blow_torch = "pickup",
	drk_pku_blow_torch = "pickup",
	hold_born_receive_item_blow_torch = "pickup",
	gen_pku_thermite = "pickup",
	gen_pku_thermite_paste = "pickup",
	gen_pku_thermite_paste_z_axis = "pickup",
	hold_take_gas_can = "pickup",
	saw_blade = "pickup",
	stash_server_pickup = "pickup",
	pickup_case = "pickup",
	pickup_keys = "pickup",
	hold_take_mask = "pickup",
	press_pick_up = "pickup",
	hold_take_missing_animal_poster = "pickup",
	hold_pick_up_turtle = "pickup",
	glc_hold_take_handcuffs = "pickup",
	pickup_tablet = "pickup",
	pickup_phone = "pickup",
	press_take_folder = "pickup",
	take_jfr_briefcase = "pickup",
	take_confidential_folder_icc = "pickup",
	mex_pickup_murky_uniforms = "pickup",
	ranc_hold_take_stock = "pickup",
	ranc_hold_take_receiver = "pickup",
	ranc_hold_take_barrel = "pickup",
	corp_achi_blueprint = "pickup",
	hold_take_vault_blueprint = "pickup",
	pku_scubagear_vest = "pickup",
	pku_scubagear_tank = "pickup",
	hospital_veil = "pickup",
	hospital_veil_take = "pickup",
	paper_pickup = "clue",
	gen_pku_fusion_reactor = "clue",
	hack_electric_box = "box",
	rewire_electric_box = "box",
	rewire_friend_fuse_box = "box",
	circuit_breaker = "box",
	circuit_breaker_off = "box",
	hold_circuit_breaker = "box",
	hold_hlm_open_circuitbreaker = "box",
	transformer_box = "box",
	cas_open_powerbox = "box",
	open_slash_close_sec_box = "box",
	crate_loot = "crate",
	crate_loot_crowbar = "crate",
	crate_weapon_crowbar = "crate",
	weapon_case = "crate",
	weapon_case_axis_z = "crate",
	hold_open_xmas_present = "crate",
	hold_open_case = "crate",
	take_weapons = "crate",
	take_weapons_axis_z = "crate",
	take_weapons_not_active = "crate",
	gen_pku_warhead_box = "crate",
	drill = "safe",
	lance = "safe",
	lance_bbv = "safe",
	apartment_drill = "safe",
	suburbia_drill = "safe",
	goldheist_drill = "safe",
	safety_deposit = "safe",
	hack_ipad = "computer",
	hack_ipad_bp1 = "computer",
	hack_suburbia = "computer",
	hack_suburbia_outline = "computer",
	hack_suburbia_axis = "computer",
	use_computer = "computer",
	laptop_objective = "computer",
	big_computer_hackable = "computer",
	big_computer_hackable_axis = "computer",
	big_computer_server = "computer",
	security_station = "computer",
	security_station_keyboard = "computer",
	tear_painting = "art",
	hold_take_painting = "art",
	cut_painting = "art",
	mus_take_diamond = "art",
	mus_hold_open_display = "art",
	cut_glass = "art",
	money_wrap = "loot",
	gold_pile = "loot",
	gen_pku_cocaine = "loot",
	gen_pku_cocaine_pure = "loot",
	gen_pku_artifact_statue = "loot",
	diamonds_pickup = "loot",
	red_diamond_pickup = "loot",
	red_diamond_pickup_no_axis = "loot",
	samurai_armor = "loot",
	hold_open_shopping_bag = "loot",
	money_wrap_single_bundle = "loose",
	money_wrap_single_bundle_active = "loose",
	money_wrap_single_bundle_dyn = "loose",
	diamond_pickup = "loose",
	diamond_pickup_pal = "loose",
	diamond_pickup_axis = "loose",
	diamond_single_pickup_axis = "loose",
	cas_chips_pile = "loose",
	safe_loot_pickup = "loose",
	ring_band = "loose",
	cash_register = "loose",
	atm_interaction = "atm",
	requires_ecm_jammer_atm = "atm",
	hold_take_toy = "loose",
	hold_take_wine = "loose",
	hold_take_expensive_wine = "loose",
	hold_take_diamond_necklace = "loose",
	hold_take_vr_headset = "loose",
	hold_take_shoes = "loose",
	hold_take_old_wine = "loose",
}

local CARRY_DROP_TID = {
	carry_drop = true,
	painting_carry_drop = true,
	safe_carry_drop = true,
	goat_carry_drop = true,
}

local KIND_SETTING = {
	pickup = { "mark_pickups", true },
	loot = { "mark_loot", true },
	loose = { "mark_loose_loot", true },
	atm = { "mark_atms", true },
	crate = { "mark_crates", true },
	safe = { "mark_safes", true },
	box = { "mark_circuit_boxes", true },
	computer = { "mark_computers", false },
	clue = { "mark_items", true },
	art = { "mark_items", true },
	use = { "mark_items", true },
	body = { "mark_body_bags", false },
	dropped = { "mark_dropped_bags", false },
}

local FALLBACK_ICONS = {
	pickup = { "pd2_lootdrop", "wp_c4", "wp_standard" },
	box = { "wp_powerbutton", "wp_standard" },
	crate = { "pd2_lootdrop", "wp_standard" },
	loot = { "pd2_lootdrop", "wp_standard" },
	loose = { "pd2_lootdrop", "wp_standard" },
	atm = { "pd2_lootdrop", "wp_powerbutton", "wp_standard" },
	clue = { "pd2_question", "wp_standard" },
	safe = { "wp_drill", "wp_powerbutton", "wp_standard" },
	use = { "wp_target", "wp_standard" },
	computer = { "wp_target", "wp_standard" },
	art = { "pd2_lootdrop", "wp_standard" },
	body = { "pd2_lootdrop", "wp_standard" },
	dropped = { "pd2_lootdrop", "wp_standard" },
	mission = { "wp_standard" },
}

local function S()
	return OmnisciencePlus.settings or {}
end

local function opt(key, default_on)
	local v = S()[key]
	if v == nil then
		return default_on ~= false
	end
	return v and true or false
end

local function kind_allowed(kind)
	local spec = KIND_SETTING[kind]
	if not spec then
		return true
	end
	return opt(spec[1], spec[2])
end

local function save_dir()
	return SavePath or "mods/saves/"
end

local function dbg(msg, also_last)
	if S().debug_log ~= true then
		return
	end
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

local function name_has_any(n, keys)
	if not n or n == "" then
		return false
	end
	for _, key in ipairs(keys) do
		if string.find(n, key, 1, true) then
			return true
		end
	end
	return false
end

local function is_casual_civ_name(n)
	if not n or n == "" then
		return false
	end
	if name_has_any(n, MANAGER_KEYS) or name_has_any(n, KEYCARD_NAME_KEYS) or name_has_any(n, PROTECT_NPC_KEYS) then
		return false
	end
	return name_has_any(n, CASUAL_CIV_KEYS)
end

local function is_important_npc(unit)
	local n = unit_tweak_name(unit)
	if n == "" then
		return false
	end
	if is_casual_civ_name(n) then
		return false
	end
	return name_has_any(n, IMPORTANT_NPC_KEYS)
end

local function interaction_tid(inter)
	if not inter then
		return nil
	end
	local tid = inter.tweak_data
	if type(tid) == "function" then
		local ok, r = pcall(function()
			return inter:tweak_data()
		end)
		if ok then
			tid = r
		end
	end
	if type(tid) == "string" then
		return tid
	end
	return nil
end

local function interaction_tweak(tid)
	if not tid or not tweak_data or not tweak_data.interaction then
		return nil
	end
	return tweak_data.interaction[tid]
end

local function npc_has_keycard(unit)
	if not alive(unit) then
		return false
	end
	local n = unit_tweak_name(unit)
	if name_has_any(n, KEYCARD_NAME_KEYS) then
		return true
	end
	if unit.interaction and unit:interaction() then
		local tid = interaction_tid(unit:interaction())
		if tid then
			local low = string.lower(tid)
			if low == "pickup_keycard" or string.find(low, "keycard", 1, true) or string.find(low, "key_card", 1, true) then
				return true
			end
		end
	end
	local dmg = unit.character_damage and unit:character_damage()
	if dmg then
		local pickup = dmg._pickup or dmg.pickup
		if pickup then
			local p = string.lower(tostring(pickup))
			if string.find(p, "key", 1, true) or string.find(p, "card", 1, true) then
				return true
			end
		end
	end
	if unit.unit_data and unit:unit_data() then
		local ud = unit:unit_data()
		if ud.has_keycard or ud.keycard then
			return true
		end
	end
	if string.find(n, "bank_manager", 1, true) then
		return true
	end
	return false
end

local function npc_is_protect(unit)
	if not alive(unit) then
		return false
	end
	if is_escort(unit) then
		return true
	end
	local n = unit_tweak_name(unit)
	if name_has_any(n, PROTECT_NPC_KEYS) then
		return true
	end
	local ok, tw = pcall(function()
		return unit:base() and unit:base():char_tweak()
	end)
	if ok and tw then
		if tw.is_escort then
			return true
		end
		if tw.tags then
			for _, tag in pairs(tw.tags) do
				local t = string.lower(tostring(tag))
				if t == "escort" or t == "vip" or t == "protect" or t == "no_damage" then
					return true
				end
			end
		end
	end
	return false
end

local function npc_is_manager(unit)
	local n = unit_tweak_name(unit)
	return name_has_any(n, MANAGER_KEYS)
end

local function npc_is_priority_kill(unit)
	if not alive(unit) or is_dead(unit) then
		return false
	end
	if npc_is_protect(unit) then
		return false
	end
	local n = unit_tweak_name(unit)
	if n == "" then
		return false
	end
	if name_has_any(n, KILL_NPC_KEYS) then
		return true
	end
	local ok, is_special = pcall(function()
		return unit:base() and unit:base().has_tag and unit:base():has_tag("special")
	end)
	if ok and is_special then
		return true
	end
	ok, is_special = pcall(function()
		local tw = unit:base() and unit:base():char_tweak()
		return tw and tw.is_special == true
	end)
	if ok and is_special then
		return true
	end
	return false
end

local function npc_is_enemy_unit(unit)
	if not alive(unit) or not managers.enemy then
		return false
	end
	local enemies = managers.enemy:all_enemies()
	if enemies then
		for _, data in pairs(enemies) do
			local u = data and (data.unit or data)
			if u == unit then
				return true
			end
		end
	end
	local ok, team = pcall(function()
		return unit:movement() and unit:movement():team()
	end)
	if ok and team and team.id then
		local id = tostring(team.id)
		if id == "law1" or id == "mobster1" or id == "converted_enemy" then
			return id ~= "converted_enemy"
		end
	end
	return false
end

local function npc_is_civilian_unit(unit)
	if not alive(unit) or not managers.enemy then
		return false
	end
	local civs = managers.enemy:all_civilians()
	if civs then
		for _, data in pairs(civs) do
			local u = data and (data.unit or data)
			if u == unit then
				return true
			end
		end
	end
	return false
end

local function classify_npc(unit)
	if not alive(unit) or is_dead(unit) then
		if alive(unit) and npc_has_keycard(unit) then
			return "keycard", 130, "KEYCARD"
		end
		return nil, 0, nil
	end

	local protect = npc_is_protect(unit)
	local keycard = npc_has_keycard(unit)
	local manager = npc_is_manager(unit)
	local pkill = npc_is_priority_kill(unit)
	local enemy = npc_is_enemy_unit(unit)
	local important = is_important_npc(unit)

	if protect then
		return "protect", 150, "PROTECT"
	end
	if keycard then
		return "keycard", 140, "KEYCARD"
	end
	if manager then
		return "manager", 125, "MANAGER"
	end
	if pkill then
		return "kill", 110, "KILL"
	end
	if important and not enemy then
		return "manager", 95, "NPC"
	end
	if enemy then
		return "enemy", 40, "GUARD"
	end
	return nil, 0, nil
end

local function clear_gpc_cd(unit)
	if not alive(unit) then
		return
	end
	local gpc = managers.game_play_central
	if gpc and gpc._auto_highlighted_enemies then
		pcall(function()
			gpc._auto_highlighted_enemies[unit:key()] = nil
		end)
	end
end

local function is_heister_unit(unit)
	if not alive(unit) then
		return true
	end
	if managers.player then
		local pu = managers.player:player_unit()
		if pu and pu == unit then
			return true
		end
	end
	if managers.criminals then
		local ok, data = pcall(function()
			return managers.criminals:character_data_by_unit(unit)
		end)
		if ok and data then
			return true
		end
		local ok2, name = pcall(function()
			return managers.criminals:character_name_by_unit(unit)
		end)
		if ok2 and name then
			return true
		end
	end
	local base = unit.base and unit:base()
	if base then
		local ok, v = pcall(function()
			return base.is_local_player and base:is_local_player()
		end)
		if ok and v then
			return true
		end
		ok, v = pcall(function()
			return base.is_husk_player and base:is_husk_player()
		end)
		if ok and v then
			return true
		end
		ok, v = pcall(function()
			return base.is_crew_ai and base:is_crew_ai()
		end)
		if ok and v then
			return true
		end
	end
	return false
end

local function contour_unit_ok(unit)
	if not alive(unit) then
		return false, "dead"
	end
	if is_heister_unit(unit) then
		return false, "heister"
	end
	local ok_slot, slot = pcall(function()
		return unit:slot()
	end)
	if ok_slot and (not slot or slot == 0) then
		return false, "slot0"
	end
	if not unit.contour then
		return false, "no_contour_fn"
	end
	local ok_c, cont = pcall(function()
		return unit:contour()
	end)
	if not ok_c or not cont then
		return false, "no_contour_ext"
	end
	if cont.enabled ~= nil then
		local ok_e, en = pcall(function()
			return cont:enabled()
		end)
		if ok_e and en == false then
			return false, "contour_disabled"
		end
	end
	return true, cont
end

local function contour_type_exists(ctype)
	if not ctype or ctype == "" then
		return false
	end
	if ContourExt and ContourExt._types and ContourExt._types[ctype] then
		return true
	end
	return true
end

local function safe_contour_add(unit, ctype, mult)
	local ok_u, cont_or_why = contour_unit_ok(unit)
	if not ok_u then
		return false, cont_or_why
	end
	if not contour_type_exists(ctype) then
		return false, "bad_type"
	end
	mult = mult or 1
	local ok, result = pcall(function()
		if not alive(unit) then
			return nil
		end
		local c = unit:contour()
		if not c then
			return nil
		end
		return c:add(ctype, false, mult)
	end)
	if not ok then
		return false, "lua_err"
	end
	if result == nil or result == false then
		return false, "add_nil"
	end
	return true, ctype
end

local function mark_person(unit, role)
	if not alive(unit) or is_dead(unit) then
		return false, "dead_or_nil"
	end
	if is_heister_unit(unit) then
		return false, "heister"
	end

	local mult = 1
	if managers.player then
		mult = managers.player:upgrade_value("player", "mark_enemy_time_multiplier", 1) or 1
	end
	mult = fade_mult(mult)

	local ok_u = contour_unit_ok(unit)
	if not ok_u then
		return false, "no_contour_ext"
	end

	local ctype = "mark_enemy"
	if role == "protect" then
		ctype = "mark_unit_friendly"
	end

	if role ~= "protect" and managers.player and unit:base() and unit:base().get_type then
		local ok_t, t = pcall(function()
			return managers.player:get_contour_for_marked_enemy(unit:base():get_type())
		end)
		if ok_t and t then
			ctype = t
		end
	end

	clear_gpc_cd(unit)

	local ok1, detail = safe_contour_add(unit, ctype, mult)
	if ok1 then
		return true, detail
	end
	if ctype ~= "mark_enemy" then
		ok1, detail = safe_contour_add(unit, "mark_enemy", mult)
		if ok1 then
			return true, detail
		end
	end
	if role == "protect" then
		ok1, detail = safe_contour_add(unit, "highlight", mult)
		if ok1 then
			return true, detail
		end
	end
	return false, detail or "add_failed"
end

local function camera_is_destroyed(unit)
	if not alive(unit) then
		return true
	end
	local base = unit.base and unit:base() or nil
	if not base then
		return false
	end
	if base._destroyed then
		return true
	end
	if type(base.destroyed) == "function" then
		local ok, dead = pcall(function()
			return base:destroyed()
		end)
		if ok and dead then
			return true
		end
	end
	return false
end

local function camera_fade_mult()
	if S().permanent_marks == true then
		return PERMA_MULT
	end
	-- mark_unit vanilla fade is 4.5s. Stretch to re-mark window + a little so it does not blink.
	local resense = OmnisciencePlus:ResenseT() or 10
	return math.max(2.5, (resense + 2) / 4.5)
end

local function mark_camera(unit)
	if not alive(unit) or is_heister_unit(unit) or camera_is_destroyed(unit) then
		return false
	end
	clear_gpc_cd(unit)
	local mult = camera_fade_mult()
	if managers.game_play_central and managers.game_play_central.auto_highlight_enemy then
		pcall(function()
			managers.game_play_central:auto_highlight_enemy(unit, true)
		end)
	end
	local ok = safe_contour_add(unit, "mark_unit", mult)
	if not ok then
		ok = safe_contour_add(unit, "mark_unit_dangerous", mult)
	end
	if not ok then
		ok = safe_contour_add(unit, "highlight", mult)
	end
	return ok and true or false
end

local function carry_id_of(unit)
	if not alive(unit) then
		return nil
	end
	local ok, cid = pcall(function()
		local cd = unit.carry_data and unit:carry_data()
		if not cd then
			return nil
		end
		if type(cd.carry_id) == "function" then
			return cd:carry_id()
		end
		return cd._carry_id
	end)
	if ok and cid and cid ~= "" then
		return cid
	end
	return nil
end

local function bag_kind_from_unit(unit)
	local cid = carry_id_of(unit)
	if cid == "person" or cid == "special_person" then
		return "body"
	end
	return "dropped"
end

local function unit_has_contour(unit)
	if not alive(unit) then
		return false
	end
	local ok, has = pcall(function()
		local c = unit:contour()
		if not c then
			return false
		end
		if c._contour_list and next(c._contour_list) then
			return true
		end
		return false
	end)
	return ok and has and true or false
end

local function mark_item(unit, high_prio)
	if not alive(unit) or is_heister_unit(unit) then
		return false
	end
	local has_char = false
	pcall(function()
		if unit:character_damage() then
			has_char = true
		end
	end)
	if has_char then
		return false
	end
	local ok_u = contour_unit_ok(unit)
	if not ok_u then
		return false
	end

	local mult = fade_mult(1)
	local primary = high_prio and "deployable_mission" or "generic_interactable"
	local ok = safe_contour_add(unit, primary, mult)
	if not ok then
		ok = safe_contour_add(unit, "generic_interactable", mult)
	end
	if not ok then
		ok = safe_contour_add(unit, "highlight", mult)
	elseif high_prio then
		safe_contour_add(unit, "highlight", mult)
	end
	return ok and true or false
end

local function ingame_active()
	if not game_state_machine then
		return false
	end
	local ok, name = pcall(function()
		return game_state_machine:current_state_name()
	end)
	if not ok or type(name) ~= "string" then
		return false
	end
	if string.find(name, "ingame", 1, true) then
		return true
	end
	return false
end

local function collect_people(pos, radius)
	local out = {}
	local stats = {
		enemy_reg = 0,
		special = 0,
		skip_dead = 0,
		skip_range = 0,
		keycard = 0,
		protect = 0,
		manager = 0,
		kill = 0,
	}
	if not opt("mark_people", true) then
		return out, stats
	end
	local r2 = radius * radius
	local seen = {}

	local function push(unit, kind_hint)
		if not alive(unit) or seen[unit:key()] then
			return
		end
		if is_heister_unit(unit) then
			return
		end
		if is_dead(unit) then
			if not npc_has_keycard(unit) then
				stats.skip_dead = stats.skip_dead + 1
				return
			end
		end
		if not unit_in_range(unit, pos, r2) then
			stats.skip_range = stats.skip_range + 1
			return
		end
		local role, score, label = classify_npc(unit)
		if not role and npc_is_civilian_unit(unit) and not is_important_npc(unit) then
			return
		end
		if not role and not npc_is_enemy_unit(unit) then
			return
		end
		role = role or kind_hint or "enemy"
		score = score > 0 and score or 40
		seen[unit:key()] = true
		if role == "keycard" then
			stats.keycard = stats.keycard + 1
		elseif role == "protect" then
			stats.protect = stats.protect + 1
		elseif role == "manager" then
			stats.manager = stats.manager + 1
		elseif role == "kill" then
			stats.kill = stats.kill + 1
		end
		local upos = unit_pos(unit)
		table.insert(out, {
			unit = unit,
			dist = upos and mvec3_dis_sq(pos, upos) or 0,
			kind = role,
			role = role,
			score = score,
			label = label,
			tweak = unit_tweak_name(unit),
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
				if alive(unit) then
					local role = classify_npc(unit)
					if role or is_important_npc(unit) or npc_has_keycard(unit) or npc_is_protect(unit) or npc_is_manager(unit) then
						stats.special = stats.special + 1
						push(unit, role or "special")
					end
				end
			end
		end
	end

	table.sort(out, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.dist < b.dist
	end)
	return out, stats
end

local function collect_cameras(pos, radius)
	local out = {}
	if S().mark_cameras == false then
		return out
	end
	local r2 = radius * radius
	local seen = {}

	local function push(unit)
		if not alive(unit) or seen[unit:key()] then
			return
		end
		if camera_is_destroyed(unit) then
			return
		end
		local en = true
		pcall(function()
			if type(unit.enabled) == "function" then
				en = unit:enabled() and true or false
			end
		end)
		if not en then
			return
		end
		if not unit_in_range(unit, pos, r2) then
			return
		end
		seen[unit:key()] = true
		local upos = unit_pos(unit)
		table.insert(out, { unit = unit, dist = upos and mvec3_dis_sq(pos, upos) or 0 })
	end

	if SecurityCamera and SecurityCamera.cameras then
		for i = 1, #SecurityCamera.cameras do
			push(SecurityCamera.cameras[i])
		end
	end

	local gstate = managers.groupai and managers.groupai:state()
	local cams = gstate and gstate._security_cameras
	if cams then
		for k, v in pairs(cams) do
			if alive(v) then
				push(v)
			elseif alive(k) then
				push(k)
			end
		end
	end

	pcall(function()
		if not World or not World.find_units_quick or not managers.slot then
			return
		end
		local mask = managers.slot:get_mask("trip_mine_targets")
		if not mask then
			return
		end
		local units = World:find_units_quick("sphere", pos, radius, mask)
		if not units then
			return
		end
		for _, unit in ipairs(units) do
			local base = unit and unit.base and unit:base()
			if base and base.is_security_camera then
				push(unit)
			end
		end
	end)

	return out
end

local POWER_BOX_TID = {
	hack_electric_box = true,
	rewire_electric_box = true,
	rewire_friend_fuse_box = true,
	circuit_breaker = true,
	circuit_breaker_off = true,
	hold_circuit_breaker = true,
	hold_hlm_open_circuitbreaker = true,
	transformer_box = true,
	cas_open_powerbox = true,
	open_slash_close_sec_box = true,
}

OmnisciencePlus._box_units = OmnisciencePlus._box_units or {}
OmnisciencePlus._box_ever_active = OmnisciencePlus._box_ever_active or {}
OmnisciencePlus._box_done = OmnisciencePlus._box_done or {}

local function is_power_box_tid(tid)
	if not tid then
		return false
	end
	local t = string.lower(tostring(tid))
	if POWER_BOX_TID[t] or POWER_BOX_TID[tid] then
		return true
	end
	if string.find(t, "electric_box", 1, true) or string.find(t, "fuse_box", 1, true)
		or string.find(t, "circuit_breaker", 1, true) or string.find(t, "transformer_box", 1, true)
		or string.find(t, "powerbox", 1, true) or string.find(t, "power_box", 1, true)
		or string.find(t, "open_powerbox", 1, true) or string.find(t, "open_circuitbreaker", 1, true)
		or string.find(t, "open_circuit_breaker", 1, true)
		or string.find(t, "open_slash_close_sec_box", 1, true)
		or (string.find(t, "rewire", 1, true) and (string.find(t, "box", 1, true) or string.find(t, "fuse", 1, true))) then
		return true
	end
	return false
end

local function is_power_box_tweak(tw)
	if not tw then
		return false
	end
	local icon = tw.icon and tostring(tw.icon) or ""
	if icon ~= "interaction_powerbox" then
		return false
	end
	local text = tw.text_id and string.lower(tostring(tw.text_id)) or ""
	if text == "" then
		return true
	end
	return string.find(text, "circuit", 1, true) or string.find(text, "fuse", 1, true)
		or string.find(text, "rewire", 1, true) or string.find(text, "electric", 1, true)
		or string.find(text, "powerbox", 1, true) or string.find(text, "power_box", 1, true)
		or string.find(text, "transformer", 1, true) or string.find(text, "breaker", 1, true)
end

local function inter_is_active(inter)
	if not inter then
		return false
	end
	local ok, result = pcall(function()
		if type(inter.active) == "function" then
			return inter:active() and true or false
		end
		if inter._active ~= nil then
			return inter._active and true or false
		end
		return false
	end)
	if ok then
		return result
	end
	return false
end

local function unit_is_enabled(unit)
	if not alive(unit) then
		return false
	end
	local en = true
	pcall(function()
		if type(unit.enabled) == "function" then
			en = unit:enabled() and true or false
		end
	end)
	return en
end

local function unit_is_visible(unit)
	if not alive(unit) then
		return false
	end
	local vis = true
	pcall(function()
		if type(unit.visible) == "function" then
			vis = unit:visible() and true or false
		end
	end)
	return vis
end

local function unit_on_interactive_list(unit)
	local interactive = managers.interaction and managers.interaction._interactive_units
	if not interactive or not alive(unit) then
		return false
	end
	local key = unit:key()
	if interactive[1] ~= nil or (type(#interactive) == "number" and #interactive > 0) then
		for _, u in ipairs(interactive) do
			if u == unit or (alive(u) and u:key() == key) then
				return true
			end
		end
	end
	if interactive[unit] then
		return true
	end
	for u, _ in pairs(interactive) do
		if type(u) ~= "number" and alive(u) and u:key() == key then
			return true
		end
	end
	return false
end

local function interact_marker_pos(unit, inter)
	local pos = nil
	pcall(function()
		if unit and unit.oobb then
			local oobb = unit:oobb()
			if oobb and oobb.center then
				pos = oobb:center()
			end
		end
	end)
	if pos then
		return pos
	end
	inter = inter or (unit and unit.interaction and unit:interaction()) or nil
	if inter then
		pcall(function()
			if type(inter.interact_position) == "function" then
				pos = inter:interact_position()
			end
		end)
		if not pos then
			pcall(function()
				local obj = inter._interact_object
				if obj and type(obj.position) == "function" then
					pos = obj:position()
				end
			end)
		end
		if not pos then
			pcall(function()
				if inter.m_pos then
					pos = inter.m_pos
				end
			end)
		end
	end
	if pos then
		return pos
	end
	return unit_pos(unit)
end

local function box_still_pending(unit)
	if not alive(unit) or not unit_is_enabled(unit) or not unit_is_visible(unit) then
		return false
	end
	local key = nil
	pcall(function()
		key = unit:key()
	end)
	if not key or OmnisciencePlus._box_done[key] then
		return false
	end
	local inter = unit.interaction and unit:interaction() or nil
	if not inter then
		OmnisciencePlus._box_done[key] = true
		OmnisciencePlus._box_units[key] = nil
		return false
	end
	local tid = interaction_tid(inter)
	local tw = tid and interaction_tweak(tid) or nil
	if not is_power_box_tid(tid) and not is_power_box_tweak(tw) then
		OmnisciencePlus._box_units[key] = nil
		return false
	end

	local active = inter_is_active(inter)

	if active then
		OmnisciencePlus._box_ever_active[key] = true
		OmnisciencePlus._box_units[key] = unit
		return true
	end

	-- Inactive and never usable this run = dummy spawn slot. Drop it.
	-- Was usable then turned off = already used. Drop it.
	if OmnisciencePlus._box_ever_active[key] then
		OmnisciencePlus._box_done[key] = true
	end
	OmnisciencePlus._box_units[key] = nil
	return false
end

local function foreach_tracked_boxes(fn)
	local drop = {}
	for key, unit in pairs(OmnisciencePlus._box_units) do
		if alive(unit) and box_still_pending(unit) then
			fn(unit)
		else
			drop[key] = true
		end
	end
	for key in pairs(drop) do
		OmnisciencePlus._box_units[key] = nil
	end
end

local function classify_item(tid, tw)
	if not tid or SKIP_INTERACTION[tid] or SKIP_CAMERA_TID[tid] or SKIP_SMALL_LOOT[tid] then
		return nil
	end
	if MISSION_TID[tid] then
		return MISSION_TID[tid]
	end
	if is_power_box_tid(tid) or is_power_box_tweak(tw) then
		return "box"
	end
	-- Unique pickups only (keycard, crowbar, planks…). Not every keycard reader.
	if tw and tw.special_equipment_block then
		return "pickup"
	end
	if tw and tw.icon then
		local icon = tostring(tw.icon)
		if icon == "interaction_diamond" or icon == "equipment_money_bag" then
			return "loot"
		end
	end
	return nil
end

local function foreach_interactive(fn)
	local interactive = managers.interaction and managers.interaction._interactive_units
	if not interactive then
		return
	end
	if interactive[1] ~= nil or #interactive > 0 then
		for _, unit in ipairs(interactive) do
			fn(unit)
		end
	else
		for unit, _ in pairs(interactive) do
			if type(unit) ~= "number" then
				fn(unit)
			end
		end
	end
end

local function collect_items(pos, radius)
	local out = {}
	local r2 = radius * radius
	local seen = {}

	local function push(unit, force_box)
		if not alive(unit) or is_heister_unit(unit) or seen[unit:key()] then
			return
		end
		if not unit_is_enabled(unit) or not unit_is_visible(unit) then
			return
		end
		local is_char = false
		pcall(function()
			if unit:character_damage() then
				is_char = true
			end
		end)
		if is_char then
			return
		end
		if not unit_in_range(unit, pos, r2) then
			return
		end
		local inter = unit.interaction and unit:interaction() or nil
		local tid = inter and interaction_tid(inter) or nil
		local kind = nil
		if tid and CARRY_DROP_TID[tid] then
			kind = bag_kind_from_unit(unit)
		elseif tid and SKIP_INTERACTION[tid] and not force_box then
			return
		end
		local tw = tid and interaction_tweak(tid) or nil
		local looks_box = force_box or is_power_box_tid(tid) or is_power_box_tweak(tw) or classify_item(tid, tw) == "box"
		if looks_box then
			if not opt("mark_circuit_boxes", true) then
				return
			end
			if not box_still_pending(unit) then
				return
			end
			kind = "box"
		elseif not kind then
			kind = classify_item(tid, tw)
		end
		if not kind then
			return
		end
		if not kind_allowed(kind) then
			return
		end
		local active = inter_is_active(inter)
		if not active then
			return
		end
		seen[unit:key()] = true
		local upos = looks_box and interact_marker_pos(unit, inter) or unit_pos(unit)
		table.insert(out, {
			unit = unit,
			dist = upos and mvec3_dis_sq(pos, upos) or 0,
			tid = tid or (looks_box and "power_box" or nil),
			kind = kind,
			pos = upos,
		})
	end

	foreach_interactive(function(unit)
		push(unit, false)
	end)
	foreach_tracked_boxes(function(unit)
		push(unit, true)
	end)

	table.sort(out, function(a, b)
		return a.dist < b.dist
	end)
	return out
end

---------------------------------------------------------------------------
-- Fallback HUD icons: only when contour fails. Linger until resense / gone.
---------------------------------------------------------------------------

function OmnisciencePlus:ClearQuestWaypoints()
	if not self._quest_wps then
		self._quest_wps = {}
		return
	end
	if managers.hud then
		for id, _ in pairs(self._quest_wps) do
			pcall(function()
				managers.hud:remove_waypoint(id)
			end)
		end
	end
	self._quest_wps = {}
end

local function resolve_fallback_icon(kind)
	local list = FALLBACK_ICONS[kind] or FALLBACK_ICONS.mission
	if tweak_data and tweak_data.hud_icons then
		for _, icon in ipairs(list) do
			if tweak_data.hud_icons[icon] then
				return icon
			end
		end
	end
	return list[1] or "wp_standard"
end

local function fallback_color(kind)
	if kind == "pickup" then
		return Color(1, 0.25, 0.85, 1.00)
	end
	if kind == "box" then
		return Color(1, 1.00, 0.85, 0.05)
	end
	if kind == "crate" or kind == "loot" or kind == "loose" or kind == "dropped" then
		return Color(1, 0.85, 0.30, 1.00)
	end
	if kind == "atm" then
		return Color(1, 0.95, 0.75, 0.15)
	end
	if kind == "body" then
		return Color(1, 0.55, 0.55, 0.55)
	end
	if kind == "clue" then
		return Color(1, 0.55, 1.00, 0.35)
	end
	if kind == "safe" then
		return Color(1, 0.72, 0.35, 1.00)
	end
	if kind == "art" then
		return Color(1, 0.95, 0.35, 0.85)
	end
	if kind == "use" or kind == "computer" then
		return Color(1, 1.00, 0.50, 0.05)
	end
	return Color(1, 1.00, 1.00, 0.40)
end

local function remove_fallback_wp(id)
	if managers.hud then
		pcall(function()
			managers.hud:remove_waypoint(id)
		end)
	end
	if OmnisciencePlus._quest_wps then
		OmnisciencePlus._quest_wps[id] = nil
	end
end

local function add_fallback_wp(unit, pos, kind, expire_t)
	if not managers.hud or not managers.hud.add_waypoint or not pos or not alive(unit) then
		return
	end
	OmnisciencePlus._quest_wps = OmnisciencePlus._quest_wps or {}
	local id = WP_PREFIX .. tostring(unit:key())
	local icon = resolve_fallback_icon(kind)
	local col = fallback_color(kind)
	if OmnisciencePlus._quest_wps[id] then
		pcall(function()
			if managers.hud.change_waypoint_position then
				managers.hud:change_waypoint_position(id, pos)
			end
		end)
		OmnisciencePlus._quest_wps[id].expire = expire_t
		OmnisciencePlus._quest_wps[id].pos = pos
		return
	end
	local ok = pcall(function()
		managers.hud:add_waypoint(id, {
			icon = icon,
			position = pos,
			distance = false,
			present_timer = 0,
			state = "sneak_present",
			no_sync = true,
			color = col,
			radius = 160,
		})
	end)
	if not ok then
		pcall(function()
			managers.hud:add_waypoint(id, {
				icon = "wp_standard",
				position = pos,
				distance = false,
				present_timer = 0,
				state = "sneak_present",
				no_sync = true,
				color = col,
				radius = 160,
			})
		end)
	end
	OmnisciencePlus._quest_wps[id] = {
		expire = expire_t,
		kind = kind,
		pos = pos,
		ukey = unit:key(),
		unit = unit,
	}
end

local function cull_fallback_waypoints(t)
	if not OmnisciencePlus._quest_wps or not next(OmnisciencePlus._quest_wps) then
		return
	end
	if not ingame_active() then
		OmnisciencePlus:ClearQuestWaypoints()
		return
	end
	local drop = {}
	for id, meta in pairs(OmnisciencePlus._quest_wps) do
		local dead = false
		if type(meta) ~= "table" then
			dead = true
		elseif meta.unit and not alive(meta.unit) then
			dead = true
		elseif t and meta.expire and t >= meta.expire and S().permanent_marks ~= true then
			dead = true
		end
		if dead then
			drop[id] = true
		end
	end
	for id in pairs(drop) do
		remove_fallback_wp(id)
	end
end

---------------------------------------------------------------------------
-- Sixth Sense pulse (stand-still only)
---------------------------------------------------------------------------

local function do_sense(self, t, dt, source)
	source = source or "?"
	if OmnisciencePlus._suspended then
		return
	end
	OmnisciencePlus._tick_n = (OmnisciencePlus._tick_n or 0) + 1

	local sus = suspended()
	if sus then
		if OmnisciencePlus._quest_wps and next(OmnisciencePlus._quest_wps) then
			pcall(function()
				OmnisciencePlus:ClearQuestWaypoints()
			end)
		end
		return
	end

	if not ingame_active() then
		if OmnisciencePlus._quest_wps and next(OmnisciencePlus._quest_wps) then
			pcall(function()
				OmnisciencePlus:ClearQuestWaypoints()
			end)
		end
		return
	end

	if not managers or not managers.player or not managers.groupai then
		return
	end

	if not self or not alive(self._unit) then
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
		return
	end

	OmnisciencePlus._hb_t = OmnisciencePlus._hb_t or 0
	if t >= OmnisciencePlus._hb_t then
		OmnisciencePlus._hb_t = t + 10
		dbg(string.format("HB src=%s skill=%s(%s) blocked=%s moving=%s",
			source, tostring(skill_ok), tostring(skill_why), tostring(blocked or "none"), tostring(self._moving and true or false)))
	end

	if blocked then
		sd.omp_t = nil
		sd.omp_pos = nil
		return
	end

	local player_m_pos = self._unit:movement() and self._unit:movement():m_pos()
	if not player_m_pos then
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

	local resense = (S().permanent_marks == true) and 999999 or resense_base
	local budget = mark_budget()
	sd.omp_detected = sd.omp_detected or {}
	local detected = sd.omp_detected

	local people, cstats = collect_people(player_m_pos, radius)
	local cams = collect_cameras(player_m_pos, radius)
	local items = collect_items(player_m_pos, radius)

	local new_p, new_c, new_i, new_wp = 0, 0, 0, 0
	local expire_t = t + resense

	for _, entry in ipairs(people) do
		if new_p >= budget then
			break
		end
		local key = entry.unit:key()
		local until_t = detected[key]
		if not until_t or until_t <= t then
			local okm = mark_person(entry.unit, entry.role)
			if okm then
				detected[key] = t + resense
				new_p = new_p + 1
			end
		end
	end

	for _, entry in ipairs(cams) do
		-- Refresh every pulse so the 4.5s vanilla fade never drops between marks.
		if mark_camera(entry.unit) then
			detected[entry.unit:key()] = t + resense
			new_c = new_c + 1
		end
	end

	local item_budget = 36
	if budget ~= math.huge then
		item_budget = math.max(12, math.min(36, budget * 2))
	end
	for _, entry in ipairs(items) do
		if new_i >= item_budget then
			break
		end
		if alive(entry.unit) then
			local key = entry.unit:key()
			local until_t = detected[key]
			if not until_t or until_t <= t then
				local hi = entry.kind == "box" or entry.kind == "pickup" or entry.kind == "clue"
					or entry.kind == "safe" or entry.kind == "crate" or entry.kind == "art"
					or entry.kind == "atm"
				local id = WP_PREFIX .. tostring(key)
				if (entry.kind == "use" or entry.kind == "computer") and unit_has_contour(entry.unit) then
					detected[key] = t + resense
					new_i = new_i + 1
					if OmnisciencePlus._quest_wps and OmnisciencePlus._quest_wps[id] then
						remove_fallback_wp(id)
					end
				elseif mark_item(entry.unit, hi) then
					detected[key] = t + resense
					new_i = new_i + 1
					if OmnisciencePlus._quest_wps and OmnisciencePlus._quest_wps[id] then
						remove_fallback_wp(id)
					end
				elseif entry.kind == "use" or entry.kind == "computer" or unit_has_contour(entry.unit) then
					-- Computers, or vanilla already outlined it (dropped bags, ATMs, etc.).
					detected[key] = t + resense
					new_i = new_i + 1
					if OmnisciencePlus._quest_wps and OmnisciencePlus._quest_wps[id] then
						remove_fallback_wp(id)
					end
				else
					local pos = entry.pos or interact_marker_pos(entry.unit) or unit_pos(entry.unit)
					add_fallback_wp(entry.unit, pos, entry.kind, expire_t)
					detected[key] = t + resense
					new_i = new_i + 1
					new_wp = new_wp + 1
				end
			end
		end
	end

	OmnisciencePlus._diag = (OmnisciencePlus._diag or 0) + 1
	dbg(string.format(
		"PULSE #%d src=%s people=%d new_p=%d cam=%d new_c=%d item=%d new_i=%d wp=%d range=%.0fm | coll enemy_reg=%d special=%d",
		OmnisciencePlus._diag,
		source,
		#people,
		new_p,
		#cams,
		new_c,
		#items,
		new_i,
		new_wp,
		radius / 100,
		cstats.enemy_reg,
		cstats.special
	))

	sd.omp_t = t + interval_t
	mvec3_set(sd.omp_pos, player_m_pos)
end

local function sense_update_hook(self, t, dt, source)
	if OmnisciencePlus._suspended then
		return
	end
	pcall(cull_fallback_waypoints, t)
	if not self._unit or not alive(self._unit) then
		return
	end
	pcall(do_sense, self, t, dt, source)
end

if not OmnisciencePlus._posthook_ps then
	OmnisciencePlus._posthook_ps = true
	Hooks:PostHook(PlayerStandard, "update", "OmnisciencePlus_PostUpdate341", function(self, t, dt)
		sense_update_hook(self, t, dt, "PostHook")
	end)
	dbg("INSTALLED PostHook v3.4.2")
end

Hooks:PostHook(PlayerStandard, "init", "OmnisciencePlus_Init341", function()
	OmnisciencePlus:Resume()
end)

Hooks:PostHook(PlayerStandard, "enter", "OmnisciencePlus_Enter341", function()
	OmnisciencePlus:Resume()
end)

Hooks:PostHook(PlayerStandard, "exit", "OmnisciencePlus_Exit341", function(self)
	if self._state_data then
		self._state_data.omp_t = nil
		self._state_data.omp_pos = nil
		self._state_data.omp_detected = nil
	end
	pcall(function()
		OmnisciencePlus:ClearQuestWaypoints()
	end)
end)

dbg("player.lua v3.4.2 LOADED")
