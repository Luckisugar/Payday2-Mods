--[[
	Instant Restart v1.3.0
	Host hotkey: restart heist → rebuy preplan/assets → auto-start past briefing.
	Safety-first: wait for peers/streaming, pcall everything, no crashy paths.
]]

_G.InstantRestart = _G.InstantRestart or {}
local IR = InstantRestart

IR._path = IR._path or ModPath
IR._data_path = IR._data_path or (SavePath .. "instant_restart.txt")
IR._pending_path = IR._pending_path or (SavePath .. "instant_restart_pending.flag")
IR._assets_path = IR._assets_path or (SavePath .. "instant_restart_assets.json")

IR.settings = IR.settings or {
	enabled = true,
	auto_start = true,
	start_delay = 1.0,
	require_confirm = false,
	debug_log = true,
	rebuy_preplan = true,
	rebuy_buy_all_fallback = true,
	rebuy_force = true,
	system_chat = true,
	network_system_chat = true,
	safe_peer_checks = true,
	min_restart_cooldown = 3,
	max_pending_age = 90
}

IR.pending_auto_start = IR.pending_auto_start or false
IR.starting = IR.starting or false
IR.rebuy_done = IR.rebuy_done or false
IR._asset_snapshot = IR._asset_snapshot or nil
IR._chat_id = "InstantRestart"
IR._last_try_log_t = 0
IR._try_count = 0
IR._last_restart_t = 0
IR._net_id = "IR_SYSMSG"
IR._version = "1.3.0"

if not IR.log then
	dofile((IR._path or ModPath) .. "log.lua")
end

function IR:Save()
	local ok, err = pcall(function()
		local f = io.open(self._data_path, "w+")
		if f then
			f:write(json.encode(self.settings))
			f:close()
		end
	end)
	if not ok then
		self:log("save_fail", { err = tostring(err) })
	end
end

function IR:Load()
	pcall(function()
		local f = io.open(self._data_path, "r")
		if not f then
			return
		end
		local raw = f:read("*all")
		f:close()
		if raw and raw ~= "" then
			local ok, data = pcall(json.decode, raw)
			if ok and type(data) == "table" then
				for k, v in pairs(data) do
					self.settings[k] = v
				end
			end
		end
	end)
	self._log_enabled = self.settings.debug_log ~= false
end

-- -------- SYSTEM chat (not under your Steam name) --------

function IR:system_message_local(text)
	if not text or text == "" then
		return
	end
	local ok, err = pcall(function()
		if managers.chat and managers.chat.feed_system_message then
			managers.chat:feed_system_message(ChatManager.GAME, text)
		elseif managers.chat then
			-- Fallback: still label as SYSTEM locally
			managers.chat:_receive_message(
				ChatManager.GAME or 1,
				"SYSTEM",
				text,
				(tweak_data and tweak_data.system_chat_color) or Color(1, 1, 0.5, 0)
			)
		end
	end)
	if not ok then
		self:log("system_message_local_fail", { err = tostring(err) })
	end
end

function IR:system_message_network(text)
	if not self.settings.network_system_chat then
		return
	end
	if not text or text == "" then
		return
	end
	-- Peers who also have this mod show it as SYSTEM. Vanilla peers cannot get true SYSTEM.
	pcall(function()
		if LuaNetworking and LuaNetworking.SendToPeers then
			LuaNetworking:SendToPeers(self._net_id, text)
			self:log("net_system_sent", { text = text })
		end
	end)
end

function IR:announce(text)
	if self.settings.system_chat == false then
		return
	end
	self:system_message_local(text)
	self:system_message_network(text)
end

function IR:on_network_system_message(sender_peer_id, message)
	-- Received from host (or any peer); show as SYSTEM locally — never as their name
	if type(message) ~= "string" or message == "" then
		return
	end
	self:log("net_system_recv", { from = sender_peer_id, text = message })
	self:system_message_local(message)
end

-- -------- pending flag (survives heist restart) --------

function IR:write_pending_flag(on)
	local path = self._pending_path
	if on then
		pcall(function()
			local f = io.open(path, "w")
			if f then
				f:write(string.format("%s\n", tostring(os.time() or 0)))
				f:close()
			end
		end)
		if Global then
			Global.instant_restart_pending = true
			Global.instant_restart_pending_t = os.time()
			Global.instant_restart_rebuy = self.settings.rebuy_preplan and true or false
		end
		self.pending_auto_start = true
		self.rebuy_done = false
	else
		pcall(function()
			os.remove(path)
		end)
		pcall(function()
			local f = io.open(path, "w")
			if f then
				f:write("")
				f:close()
			end
		end)
		if Global then
			Global.instant_restart_pending = nil
			Global.instant_restart_pending_t = nil
			Global.instant_restart_rebuy = nil
		end
		self.pending_auto_start = false
		self.rebuy_done = false
	end
end

function IR:read_pending_flag()
	if Global and Global.instant_restart_pending then
		return true
	end
	local ok, has = pcall(function()
		local f = io.open(self._pending_path, "r")
		if not f then
			return false
		end
		local raw = f:read("*all")
		f:close()
		return raw and raw:match("%S") and true or false
	end)
	return ok and has
end

function IR:refresh_pending_from_disk()
	local disk = self:read_pending_flag()
	if disk then
		self.pending_auto_start = true
		if Global then
			Global.instant_restart_pending = true
		end
	end
	return self.pending_auto_start
end

function IR:clear_pending(reason)
	self:log("clear_pending", { reason = reason })
	self:write_pending_flag(false)
	self.starting = false
	self.rebuy_done = false
	self._try_count = 0
end

-- -------- safety / peers --------

function IR:peers_synched()
	local session = managers.network and managers.network:session()
	if not session then
		return true
	end
	for _, peer in pairs(session:peers()) do
		if peer and not peer:synched() then
			return false, peer:name() or "?"
		end
	end
	return true
end

function IR:all_peers_ready_to_start()
	-- Stricter checks to reduce blackscreen risk for clients
	if self.settings.safe_peer_checks == false then
		return self:peers_synched()
	end

	local session = managers.network and managers.network:session()
	if not session then
		return true
	end

	local function peer_ok(peer)
		if not peer then
			return false, "nil_peer"
		end
		if peer.synched and not peer:synched() then
			return false, "not_synched"
		end
		if peer.is_outfit_loaded and not peer:is_outfit_loaded() then
			return false, "outfit"
		end
		if peer.is_streaming_complete and not peer:is_streaming_complete() then
			return false, "streaming"
		end
		return true
	end

	-- Local peer
	local lp = session:local_peer()
	local ok, why = peer_ok(lp)
	if not ok then
		return false, "local:" .. tostring(why)
	end

	-- Remote peers
	for _, peer in pairs(session:peers()) do
		ok, why = peer_ok(peer)
		if not ok then
			return false, (peer:name() or "?") .. ":" .. tostring(why)
		end
	end

	return true
end

function IR:streaming_ready()
	local ok = self:all_peers_ready_to_start()
	return ok
end

function IR:current_state()
	if not game_state_machine then
		return nil
	end
	local ok, st = pcall(function()
		return game_state_machine:current_state()
	end)
	return ok and st or nil
end

function IR:state_can_start(state)
	state = state or self:current_state()
	if not state then
		return false, "no_state"
	end
	if type(state.start_game_intro) ~= "function" then
		return false, "no_start_game_intro"
	end
	if state._starting_mission_briefing_intro then
		return false, "already_starting_intro"
	end
	return true
end

function IR:in_briefing_phase()
	local in_game, in_heist
	pcall(function()
		in_game = Utils:IsInGameState()
	end)
	pcall(function()
		in_heist = Utils:IsInHeist()
	end)

	if not in_game then
		return false, "not_in_game"
	end

	if in_heist == false then
		return true, "not_in_heist"
	end

	local state = self:current_state()
	if state and type(state.start_game_intro) == "function" then
		local name
		pcall(function()
			if state.name then
				name = state:name()
			end
		end)
		if name and tostring(name):find("waiting", 1, true) then
			return true, "state_name_waiting"
		end
		if managers.menu_component and managers.menu_component._mission_briefing_gui then
			return true, "briefing_gui_present"
		end
	end

	return false, "still_in_heist_or_unknown"
end

function IR:cooldown_ok()
	local cd = tonumber(self.settings.min_restart_cooldown) or 3
	if cd <= 0 then
		return true
	end
	local now = 0
	pcall(function()
		now = TimerManager:game():time()
	end)
	if now <= 0 then
		pcall(function()
			now = Application:time()
		end)
	end
	if (now - (self._last_restart_t or 0)) < cd then
		return false, cd - (now - (self._last_restart_t or 0))
	end
	return true
end

function IR:can_restart()
	if not self.settings.enabled then
		return false, "disabled"
	end
	if not Network or not Network:is_server() then
		return false, "host_only"
	end
	if not Utils or not Utils:IsInGameState() or not Utils:IsInHeist() then
		return false, "not_in_heist"
	end

	local cd_ok, left = self:cooldown_ok()
	if not cd_ok then
		return false, "cooldown", left
	end

	if managers.game_play_central and managers.game_play_central.is_restarting then
		local ok_rs, restarting = pcall(function()
			return managers.game_play_central:is_restarting()
		end)
		if ok_rs and restarting then
			return false, "already_restarting"
		end
	end

	-- Session must exist
	if not managers.network or not managers.network:session() then
		return false, "no_session"
	end

	local sync_ok, peer_info = self:peers_synched()
	if not sync_ok then
		return false, "peer_loading", peer_info
	end

	-- Avoid restart while someone is mid-join loadout stream if we can detect it
	if self.settings.safe_peer_checks then
		local ready, why = self:all_peers_ready_to_start()
		if not ready then
			return false, "peer_not_ready", why
		end
	end

	return true
end

-- -------- asset / preplan snapshot (survives restart wipe) --------

function IR:current_level_id()
	local id
	pcall(function()
		if managers.job and managers.job.current_level_id then
			id = managers.job:current_level_id()
		end
	end)
	return id
end

function IR:write_asset_snapshot(snap)
	self._asset_snapshot = snap
	pcall(function()
		local f = io.open(self._assets_path, "w+")
		if f then
			f:write(json.encode(snap or {}))
			f:close()
		end
	end)
	if Global then
		Global.instant_restart_asset_snap = snap
	end
end

function IR:load_asset_snapshot()
	if self._asset_snapshot and type(self._asset_snapshot) == "table" then
		return self._asset_snapshot
	end
	if Global and type(Global.instant_restart_asset_snap) == "table" then
		self._asset_snapshot = Global.instant_restart_asset_snap
		return self._asset_snapshot
	end
	local snap
	pcall(function()
		local f = io.open(self._assets_path, "r")
		if not f then
			return
		end
		local raw = f:read("*all")
		f:close()
		if raw and raw ~= "" then
			local ok, data = pcall(json.decode, raw)
			if ok and type(data) == "table" then
				snap = data
			end
		end
	end)
	self._asset_snapshot = snap
	if Global and snap then
		Global.instant_restart_asset_snap = snap
	end
	return snap
end

function IR:clear_asset_snapshot()
	self._asset_snapshot = nil
	if Global then
		Global.instant_restart_asset_snap = nil
	end
	pcall(function()
		os.remove(self._assets_path)
	end)
end

--- Capture what was bought so we can restore after restart_the_game.
function IR:capture_rebuy_snapshot()
	local snap = {
		t = os.time and os.time() or 0,
		level_id = self:current_level_id(),
		job_id = nil,
		mission_assets = {},
		preplan = nil
	}

	pcall(function()
		if managers.job and managers.job.current_job_id then
			snap.job_id = managers.job:current_job_id()
		end
	end)

	-- Mission assets ("Buy All Assets" system) — Nightclub, etc.
	pcall(function()
		if not managers.assets then
			return
		end
		local ids = {}
		if managers.assets.get_unlocked_asset_ids then
			ids = managers.assets:get_unlocked_asset_ids(false) or {}
		elseif managers.assets._global and managers.assets._global.assets then
			for _, a in ipairs(managers.assets._global.assets) do
				if a.unlocked and a.id and a.id ~= "none" then
					table.insert(ids, a.id)
				end
			end
		end
		local cleaned = {}
		for _, id in ipairs(ids) do
			if id and id ~= "none" and id ~= "" then
				table.insert(cleaned, id)
			end
		end
		snap.mission_assets = cleaned
	end)

	-- Pre-planning rebuy cache (same data stock "Rebuy?" dialog uses)
	pcall(function()
		local g = Global and Global.preplanning_manager and Global.preplanning_manager.rebuy_assets
		if not g then
			return
		end
		local assets = g.assets or {}
		local votes = g.votes or {}
		if (assets and #assets > 0) or (votes and #votes > 0) then
			snap.preplan = {
				level_id = g.level_id or snap.level_id,
				assets = assets,
				votes = votes
			}
		end
	end)

	-- If mid-heist preplan cache empty, try reserved elements still in manager
	if not snap.preplan then
		pcall(function()
			if not managers.preplanning or not managers.preplanning.has_current_level_preplanning then
				return
			end
			if not managers.preplanning:has_current_level_preplanning() then
				return
			end
			local reserved = managers.preplanning._reserved_mission_elements
			if not reserved or not next(reserved) then
				return
			end
			local assets = {}
			for id, asset in pairs(reserved) do
				if asset and asset.pack then
					table.insert(assets, {
						id = id,
						type = asset.pack[1],
						index = asset.pack[2]
					})
				end
			end
			if #assets > 0 then
				snap.preplan = {
					level_id = snap.level_id,
					assets = assets,
					votes = {}
				}
			end
		end)
	end

	self:write_asset_snapshot(snap)
	self:log("asset_snapshot_captured", {
		level_id = snap.level_id,
		mission_n = snap.mission_assets and #snap.mission_assets or 0,
		preplan_n = snap.preplan and snap.preplan.assets and #snap.preplan.assets or 0,
		vote_n = snap.preplan and snap.preplan.votes and #snap.preplan.votes or 0
	})
	return snap
end

function IR:restore_preplan_cache_from_snapshot(snap)
	snap = snap or self:load_asset_snapshot()
	if not snap or not snap.preplan then
		return false
	end
	local pp = snap.preplan
	pcall(function()
		Global.preplanning_manager = Global.preplanning_manager or {}
		Global.preplanning_manager.rebuy_assets = {
			level_id = pp.level_id,
			assets = pp.assets or {},
			votes = pp.votes or {},
			reminder_active = false
		}
		if managers.preplanning then
			managers.preplanning._rebuy_assets = Global.preplanning_manager.rebuy_assets
		end
	end)
	self:log("preplan_cache_restored", {
		level_id = pp.level_id,
		assets = pp.assets and #pp.assets or 0,
		votes = pp.votes and #pp.votes or 0
	})
	return true
end

--- Force-reserve one preplan point (bypass money / soft can_reserve fails when host).
function IR:force_reserve_preplan(type_id, element_id)
	if not managers.preplanning or not type_id or not element_id then
		return false
	end
	local ok = false
	pcall(function()
		local peer_id = managers.network:session():local_peer():id()
		-- Try stock path first
		managers.preplanning:reserve_mission_element(type_id, element_id)
		if managers.preplanning:get_reserved_mission_element(element_id) then
			ok = true
			return
		end
		if not self.settings.rebuy_force then
			return
		end
		if not Network:is_server() then
			return
		end
		-- Temporarily allow reserve (money/budget/DLC soft blocks)
		local ppm = managers.preplanning
		local orig = ppm.can_reserve_mission_element
		ppm.can_reserve_mission_element = function()
			return true, 0
		end
		local ok2, err = pcall(function()
			ppm:_server_reserve_mission_element(type_id, element_id, peer_id)
		end)
		ppm.can_reserve_mission_element = orig
		if not ok2 then
			self:log("force_reserve_err", { err = tostring(err), type = type_id, id = element_id })
		end
		ok = not not ppm:get_reserved_mission_element(element_id)
	end)
	return ok
end

function IR:try_rebuy_preplanning_only()
	-- Returns: done(bool), result(string), count(number)
	if not managers.preplanning then
		return false, "no_manager", 0
	end

	local snap = self:load_asset_snapshot()
	self:restore_preplan_cache_from_snapshot(snap)

	local has_level = false
	pcall(function()
		has_level = managers.preplanning:has_current_level_preplanning()
	end)
	if not has_level then
		return true, "no_preplan_level", 0
	end

	local can_edit = true
	pcall(function()
		can_edit = managers.preplanning:can_edit_preplan()
	end)
	if not can_edit then
		return false, "cannot_edit", 0
	end

	local level_id = self:current_level_id()
	local rebuy = managers.preplanning._rebuy_assets or (Global and Global.preplanning_manager and Global.preplanning_manager.rebuy_assets)
	local assets = rebuy and rebuy.assets or {}
	local votes = rebuy and rebuy.votes or {}
	local level_ok = rebuy and rebuy.level_id and rebuy.level_id == level_id

	if not level_ok or ((not assets or #assets == 0) and (not votes or #votes == 0)) then
		-- No cache for this level — nothing to place
		return true, "nothing_to_rebuy", 0
	end

	-- Wait until mission elements are registered (briefing map ready)
	local elements_ready = false
	pcall(function()
		if managers.preplanning._mission_elements_by_type and next(managers.preplanning._mission_elements_by_type) then
			elements_ready = true
		end
	end)
	if not elements_ready then
		return false, "elements_not_ready", 0
	end

	local reserved_n = 0
	local ok, err = pcall(function()
		-- Stock path (respects money/DLC when not forcing)
		if managers.preplanning.get_can_rebuy_assets and managers.preplanning:get_can_rebuy_assets() then
			managers.preplanning:reserve_rebuy_mission_elements()
		end

		-- Ensure each snapshot asset is reserved (force if setting on)
		for _, asset in ipairs(assets) do
			if asset and asset.id and asset.type then
				local already = managers.preplanning:get_reserved_mission_element(asset.id)
				if not already then
					if self:force_reserve_preplan(asset.type, asset.id) then
						reserved_n = reserved_n + 1
					end
				else
					reserved_n = reserved_n + 1
				end
			end
		end

		for _, plan in ipairs(votes or {}) do
			if plan and plan.type and plan.id then
				pcall(function()
					if managers.preplanning:can_vote_on_plan(plan.type, managers.network:session():local_peer():id()) then
						managers.preplanning:mass_vote_on_plan(plan.type, plan.id)
					elseif self.settings.rebuy_force and Network:is_server() then
						local orig = managers.preplanning.can_vote_on_plan
						managers.preplanning.can_vote_on_plan = function()
							return true
						end
						pcall(function()
							managers.preplanning:mass_vote_on_plan(plan.type, plan.id)
						end)
						managers.preplanning.can_vote_on_plan = orig
					end
				end)
			end
		end
	end)

	if not ok then
		self:log("preplan_rebuy_error", { err = tostring(err) })
		return true, "error", reserved_n
	end

	return true, reserved_n > 0 and "rebought" or "nothing_placed", reserved_n
end

function IR:try_rebuy_mission_assets_only()
	-- Returns: done(bool), result(string), unlocked_n(number)
	if not managers.assets then
		return false, "no_manager", 0
	end

	-- Stock unlock only allowed in waiting-for-players, not drop-in
	local allowed = true
	pcall(function()
		if managers.assets.is_unlock_asset_allowed then
			allowed = managers.assets:is_unlock_asset_allowed()
		end
	end)
	if not allowed then
		return false, "not_allowed_yet", 0
	end

	local list_ready = false
	local total = 0
	pcall(function()
		if managers.assets._global and managers.assets._global.assets then
			total = #managers.assets._global.assets
			list_ready = total > 0
		end
	end)

	local snap = self:load_asset_snapshot()
	local want_ids = (snap and snap.mission_assets) or {}
	local level_id = self:current_level_id()
	if snap and snap.level_id and level_id and snap.level_id ~= level_id then
		self:log("mission_asset_level_mismatch", { snap = snap.level_id, now = level_id })
		-- Still try buy-all for current level rather than wrong IDs
		want_ids = {}
	end

	-- Assets table may not be built on first tick
	if not list_ready and #want_ids > 0 then
		return false, "assets_not_ready", 0
	end
	if not list_ready then
		-- No assets on this heist
		return true, "no_assets", 0
	end

	local unlocked_n = 0
	local tried = 0
	local ok, err = pcall(function()
		for _, id in ipairs(want_ids) do
			if id and id ~= "none" then
				tried = tried + 1
				if not managers.assets:get_asset_unlocked_by_id(id) then
					-- Host unlock_asset does not re-check skill locks (stock path)
					local uok, uerr = pcall(function()
						managers.assets:unlock_asset(id, false)
					end)
					if not uok then
						self:log("unlock_asset_err", { id = id, err = tostring(uerr) })
					end
					if managers.assets:get_asset_unlocked_by_id(id) then
						unlocked_n = unlocked_n + 1
					elseif self.settings.rebuy_force then
						-- Last resort: mark + sync if host and asset exists
						pcall(function()
							if not Network:is_server() then
								return
							end
							local asset = managers.assets:_get_asset_by_id(id)
							if asset and not asset.unlocked then
								managers.assets:server_unlock_asset(id, false)
							end
						end)
						if managers.assets:get_asset_unlocked_by_id(id) then
							unlocked_n = unlocked_n + 1
						end
					end
				else
					unlocked_n = unlocked_n + 1
				end
			end
		end

		-- Fallback: stock "Buy All Assets" for anything still locked + unlockable
		if self.settings.rebuy_buy_all_fallback ~= false then
			local need_all = (#want_ids == 0) or (unlocked_n < tried)
			-- Always run buy-all when no snapshot so at least free/available get bought
			if need_all or #want_ids == 0 then
				if managers.assets.unlock_all_availible_assets then
					managers.assets:unlock_all_availible_assets()
					self:log("mission_buy_all_fallback", { had_snapshot = #want_ids > 0 })
				end
			end
		end
	end)

	if not ok then
		self:log("mission_rebuy_error", { err = tostring(err) })
		return true, "error", unlocked_n
	end

	local result = "none"
	if unlocked_n > 0 then
		result = "rebought"
	elseif #want_ids == 0 then
		result = "buy_all_or_empty"
	else
		result = "failed_or_already"
	end
	return true, result, unlocked_n
end

-- -------- unified rebuy (preplan map + mission assets) --------

function IR:try_rebuy_preplan()
	if self.rebuy_done then
		return true, "already"
	end

	local want = self.settings.rebuy_preplan
	if Global and Global.instant_restart_rebuy ~= nil then
		want = Global.instant_restart_rebuy
	end
	if not want then
		self.rebuy_done = true
		return true, "disabled"
	end

	self:load_asset_snapshot()

	local pp_done, pp_res, pp_n = false, "skip", 0
	local ma_done, ma_res, ma_n = false, "skip", 0

	local ok1, a, b, c = pcall(function()
		return self:try_rebuy_preplanning_only()
	end)
	if ok1 then
		pp_done, pp_res, pp_n = a, b, c or 0
	else
		self:log("preplan_rebuy_pcall_fail", { err = tostring(a) })
		pp_done, pp_res = true, "error"
	end

	local ok2, d, e, f = pcall(function()
		return self:try_rebuy_mission_assets_only()
	end)
	if ok2 then
		ma_done, ma_res, ma_n = d, e, f or 0
	else
		self:log("mission_rebuy_pcall_fail", { err = tostring(d) })
		ma_done, ma_res = true, "error"
	end

	self:log("rebuy_result", {
		preplan_done = pp_done,
		preplan = pp_res,
		preplan_n = pp_n,
		mission_done = ma_done,
		mission = ma_res,
		mission_n = ma_n
	})

	-- Retry later if managers/UI not ready
	if not pp_done or not ma_done then
		return false, (not pp_done and pp_res) or ma_res
	end

	self.rebuy_done = true
	local parts = {}
	if pp_n and pp_n > 0 then
		table.insert(parts, string.format("preplan×%d", pp_n))
	elseif pp_res == "rebought" then
		table.insert(parts, "preplan")
	end
	if ma_n and ma_n > 0 then
		table.insert(parts, string.format("assets×%d", ma_n))
	elseif ma_res == "buy_all_or_empty" then
		table.insert(parts, "assets (buy all)")
	end
	if #parts > 0 then
		self:system_message_local("Re-applied " .. table.concat(parts, " + ") .. ".")
	elseif pp_res == "no_preplan_level" and (ma_res == "no_assets" or ma_res == "buy_all_or_empty") then
		-- Quiet: heist has nothing to rebuy
	else
		self:log("rebuy_nothing_applied", { preplan = pp_res, mission = ma_res })
	end

	return true, "done"
end

-- -------- restart / auto-start --------

function IR:do_restart()
	self:log("do_restart_begin")
	self:log_snapshot("do_restart_precheck")

	local ok, reason, extra = self:can_restart()
	if not ok then
		self:log("do_restart_blocked", { reason = reason, extra = extra })
		if reason == "host_only" then
			self:system_message_local("Instant Restart: host only.")
		elseif reason == "not_in_heist" then
			self:system_message_local("Instant Restart: only works mid-heist.")
		elseif reason == "peer_loading" or reason == "peer_not_ready" then
			self:system_message_local("Instant Restart: blocked — a player is still loading (" .. tostring(extra or "?") .. ").")
		elseif reason == "already_restarting" then
			self:system_message_local("Instant Restart: already restarting.")
		elseif reason == "cooldown" then
			self:system_message_local(string.format("Instant Restart: wait %.1fs.", tonumber(extra) or 0))
		elseif reason == "disabled" then
			self:system_message_local("Instant Restart is disabled in Mod Options.")
		else
			self:system_message_local("Instant Restart: blocked (" .. tostring(reason) .. ").")
		end
		return false
	end

	self.starting = false
	self.rebuy_done = false
	self._try_count = 0

	pcall(function()
		self._last_restart_t = TimerManager:game():time()
	end)

	-- Snapshot purchased preplan + mission assets BEFORE Lua state reloads
	pcall(function()
		self:capture_rebuy_snapshot()
	end)

	if self.settings.auto_start then
		self:write_pending_flag(true)
		self:log("pending_flag_set_true")
	else
		self:write_pending_flag(false)
		self:log("auto_start_off_no_pending")
	end

	self:announce("Host has force-restarted the session.")

	if managers.hud and self.pending_auto_start then
		pcall(function()
			managers.hud:show_hint({ text = "Restarting → rebuy assets → auto-start…" })
		end)
	end

	local ok_call, err = pcall(function()
		managers.game_play_central:restart_the_game()
	end)
	self:log("restart_the_game_called", { ok = ok_call, err = err and tostring(err) or nil })
	if not ok_call then
		self:clear_pending("restart_call_failed")
		self:system_message_local("Instant Restart failed safely (see log).")
	end
	return ok_call
end

function IR:request_restart()
	self:log("request_restart")
	local ok, err = pcall(function()
		if self.settings.require_confirm then
			local title = managers.localization and managers.localization:text("dialog_warning_title") or "Restart"
			local message = "Force-restart heist, rebuy preplanning, and auto-load?"
			local menu = QuickMenu:new(title, message, {
				{ text = managers.localization and managers.localization:text("dialog_no") or "No", is_cancel_button = true },
				{
					text = managers.localization and managers.localization:text("dialog_yes") or "Yes",
					callback = function()
						IR:do_restart()
					end
				}
			})
			menu:Show()
			return
		end
		self:do_restart()
	end)
	if not ok then
		self:log("request_restart_error", { err = tostring(err) })
	end
end

function IR:fire_start_game_intro(reason)
	local state = self:current_state()
	local can, why = self:state_can_start(state)
	self:log("fire_start_game_intro", { reason = reason, can = can, why = why })
	if not can then
		return false, why
	end

	-- Final peer safety gate
	local ready, rwhy = self:all_peers_ready_to_start()
	if not ready then
		self:log("fire_aborted_peers", { why = rwhy })
		return false, "peers:" .. tostring(rwhy)
	end

	local ok, err = pcall(function()
		state:start_game_intro()
	end)
	self:log("start_game_intro_result", { ok = ok, err = err and tostring(err) or nil })
	if ok then
		self:system_message_local("Session auto-started past pre-planning.")
		self:clear_pending("started_ok")
		return true
	end
	return false, err
end

function IR:try_auto_start(from)
	local ok_outer, err_outer = pcall(function()
		self:refresh_pending_from_disk()

		if not self.settings.enabled or not self.settings.auto_start then
			return
		end
		if not self.pending_auto_start then
			return
		end
		if self.starting then
			return
		end

		self._try_count = (self._try_count or 0) + 1

		local now = 0
		pcall(function()
			now = Application:time() or 0
		end)
		local should_snap = self._try_count <= 5 or (now - (self._last_try_log_t or 0)) >= 1.0
		if should_snap then
			self._last_try_log_t = now
			self:log_snapshot("try_auto_start#" .. tostring(self._try_count) .. " from=" .. tostring(from or "?"))
		end

		if not Network:is_server() then
			self:log("try_abort_not_server")
			self:clear_pending("not_server")
			return
		end

		-- Timeout
		local max_age = tonumber(self.settings.max_pending_age) or 90
		local t0 = Global and Global.instant_restart_pending_t
		if t0 and os.time and (os.time() - t0) > max_age then
			self:clear_pending("timeout")
			self:system_message_local("Instant Restart: auto-start timed out (safe abort).")
			return
		end

		local in_brief, brief_why = self:in_briefing_phase()
		if not in_brief then
			if should_snap then
				self:log("try_wait_not_briefing", { why = brief_why })
			end
			return
		end

		-- Rebuy before starting (preplan map + mission assets)
		if not self.rebuy_done then
			local rb_ok, rb_why = self:try_rebuy_preplan()
			if not rb_ok then
				-- Managers / element registration not ready yet — wait, do not start empty
				if should_snap then
					self:log("try_wait_rebuy_not_ready", { why = rb_why })
				end
				return
			end
		end

		local ready, rwhy = self:all_peers_ready_to_start()
		if not ready then
			if should_snap then
				self:log("try_wait_peers", { why = rwhy })
			end
			return
		end

		local can, why = self:state_can_start()
		if not can then
			if should_snap then
				self:log("try_wait_state", { why = why })
			end
			return
		end

		self.starting = true
		local delay = tonumber(self.settings.start_delay) or 1.0
		-- Multiplayer: never go below 0.75s if safe checks on
		local session = managers.network and managers.network:session()
		local peer_count = 0
		if session then
			for _ in pairs(session:peers()) do
				peer_count = peer_count + 1
			end
		end
		if peer_count > 0 and self.settings.safe_peer_checks ~= false and delay < 0.75 then
			delay = 0.75
		end
		if delay < 0 then
			delay = 0
		end
		if delay > 5 then
			delay = 5
		end

		self:log("scheduling_start", { delay = delay, brief_why = brief_why, peers = peer_count })

		local function fire()
			pcall(function()
				IR.starting = false
				IR:refresh_pending_from_disk()
				if not IR.pending_auto_start then
					IR:log("fire_aborted_no_pending")
					return
				end
				if not Network:is_server() then
					IR:clear_pending("fire_not_server")
					return
				end
				local in_b, w = IR:in_briefing_phase()
				if not in_b then
					IR:log("fire_aborted_not_briefing", { why = w })
					IR:write_pending_flag(true)
					return
				end
				-- One more rebuy attempt if first was early
				if not IR.rebuy_done then
					IR:try_rebuy_preplan()
				end
				local fired, fwhy = IR:fire_start_game_intro("delayed_fire")
				if not fired then
					-- Re-arm for another try (peer not ready, etc.)
					IR:log("fire_failed_rearm", { why = fwhy })
					IR.starting = false
					IR.pending_auto_start = true
					if Global then
						Global.instant_restart_pending = true
					end
				end
			end)
		end

		if delay <= 0 then
			fire()
		elseif DelayedCalls then
			DelayedCalls:Add("InstantRestart_auto_start", delay, fire)
		else
			fire()
		end
	end)

	if not ok_outer then
		self:log("try_auto_start_crash_guard", { err = tostring(err_outer) })
		self.starting = false
	end
end

function IR:on_left_game()
	self:clear_pending("left_game")
end

-- Boot
IR:Load()
IR:refresh_pending_from_disk()
IR:load_asset_snapshot()
IR:log("core_loaded", {
	version = IR._version or "1.3.0",
	path = IR._path,
	pending = IR.pending_auto_start,
	log_save = IR._log_save,
	log_mod = IR._log_mod,
	pending_path = IR._pending_path
})
