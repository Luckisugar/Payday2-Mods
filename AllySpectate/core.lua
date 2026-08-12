--[[
	Ally Spectate
	Live first-person-style camera on your teammates (humans + bots).
	Client-side only. Your body stays in the world.
]]

_G.AllySpectate = _G.AllySpectate or {}
local AS = AllySpectate

AS._path = AS._path or ModPath
AS._data_path = AS._data_path or (SavePath .. "ally_spectate.txt")
AS._version = "1.0.0"

AS.settings = AS.settings or {
	enabled = true,
	freeze_local = true,
	include_bots = true,
	hide_fp_weapon = true,
	show_hint = true,
	eye_offset = 12, -- cm along look dir so we are not inside the skull
	auto_exit_on_damage = true,
	debug_log = false
}

AS.active = AS.active or false
AS.target_unit = AS.target_unit or nil
AS.target_slot = AS.target_slot or nil
AS._chat_id = "AllySpectate"

function AS:log(msg)
	if not self.settings.debug_log then
		return
	end
	log(string.format("[AllySpectate] %s", tostring(msg)))
end

function AS:Save()
	pcall(function()
		local f = io.open(self._data_path, "w+")
		if f then
			f:write(json.encode(self.settings))
			f:close()
		end
	end)
end

function AS:Load()
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
end

function AS:system_message(msg)
	if not self.settings.show_hint then
		return
	end
	pcall(function()
		if managers.chat then
			managers.chat:_receive_message(1, "SYSTEM", tostring(msg), Color(1, 0.65, 0.9, 1))
		end
	end)
end

function AS:in_heist()
	if not managers or not managers.player then
		return false
	end
	local unit = managers.player:player_unit()
	if not alive(unit) then
		return false
	end
	local state = game_state_machine and game_state_machine:current_state_name()
	if not state then
		return true
	end
	-- block menus / waiting / custody-style states
	if state == "ingame_waiting_for_players"
		or state == "ingame_lobby"
		or state == "menu_titlescreen"
		or state == "menu_main"
		or state == "ingame_waiting_for_respawn"
		or state == "ingame_waiting_for_spawn_allowed"
	then
		return false
	end
	return true
end

function AS:local_ok()
	if not self.settings.enabled then
		return false
	end
	if not self:in_heist() then
		return false
	end
	local unit = managers.player:player_unit()
	if not alive(unit) then
		return false
	end
	local dmg = unit:character_damage()
	if dmg then
		if dmg.need_revive and dmg:need_revive() then
			return false
		end
		if dmg.arrested and dmg:arrested() then
			return false
		end
		if dmg.dead and dmg:dead() then
			return false
		end
	end
	return true
end

local function unit_name_safe(unit)
	local name = "Ally"
	pcall(function()
		if managers.network and managers.network:session() then
			local peer = managers.network:session():peer_by_unit(unit)
			if peer then
				name = peer:name()
				return
			end
		end
		if managers.criminals then
			local data = managers.criminals:character_data_by_unit(unit)
			if data and data.name then
				name = managers.localization and managers.localization:text("menu_" .. data.name) or data.name
			end
			local cn = managers.criminals:character_name_by_unit(unit)
			if cn then
				local pretty = managers.localization and managers.localization:exists("menu_" .. cn)
					and managers.localization:text("menu_" .. cn)
					or cn
				name = pretty
			end
		end
	end)
	return name
end

function AS:collect_allies()
	local list = {}
	local my = managers.player:player_unit()
	if not alive(my) then
		return list
	end

	local function push(unit, sort_key, is_bot)
		if not alive(unit) or unit == my then
			return
		end
		for _, e in ipairs(list) do
			if e.unit == unit then
				return
			end
		end
		table.insert(list, {
			unit = unit,
			sort_key = sort_key or 99,
			is_bot = is_bot and true or false,
			name = unit_name_safe(unit)
		})
	end

	-- Human players first (by peer id)
	pcall(function()
		if not managers.groupai or not managers.groupai:state() then
			return
		end
		for _, data in pairs(managers.groupai:state():all_player_criminals() or {}) do
			if data and alive(data.unit) then
				local peer_id = 50
				if managers.network and managers.network:session() then
					local peer = managers.network:session():peer_by_unit(data.unit)
					if peer then
						peer_id = peer:id()
					end
				end
				push(data.unit, peer_id, false)
			end
		end
	end)

	if self.settings.include_bots then
		pcall(function()
			if not managers.groupai or not managers.groupai:state() then
				return
			end
			for _, data in pairs(managers.groupai:state():all_AI_criminals() or {}) do
				if data and alive(data.unit) then
					push(data.unit, 100 + (#list), true)
				end
			end
		end)
	end

	table.sort(list, function(a, b)
		return a.sort_key < b.sort_key
	end)

	return list
end

function AS:get_look_dir(unit)
	local mov = unit:movement()
	if not mov then
		return unit:rotation():y()
	end
	if mov.detect_look_dir then
		return mov:detect_look_dir()
	end
	if mov.look_dir then
		return mov:look_dir()
	end
	if mov.m_head_fwd then
		return mov:m_head_fwd()
	end
	return unit:rotation():y()
end

function AS:get_eye_pose(unit)
	local pos = nil
	local look = self:get_look_dir(unit)

	local mov = unit:movement()
	if mov and mov.m_head_pos then
		pos = mvector3.copy(mov:m_head_pos())
	else
		local head = unit:get_object(Idstring("Head"))
		if head then
			pos = head:position()
		else
			pos = unit:position() + math.UP * 140
		end
	end

	local offset = tonumber(self.settings.eye_offset) or 12
	if look and offset ~= 0 then
		pos = pos + look * offset
	end

	local rot = Rotation()
	mrotation.set_look_at(rot, look, math.UP)
	return pos, rot
end

function AS:is_target_valid(unit)
	if not alive(unit) then
		return false
	end
	-- optional: skip fully dead husks
	local dmg = unit.character_damage and unit:character_damage()
	if dmg then
		if dmg.dead and dmg:dead() then
			return false
		end
	end
	return true
end

function AS:set_fp_weapon_visible(visible)
	if not self.settings.hide_fp_weapon then
		return
	end
	pcall(function()
		local player = managers.player:player_unit()
		if not alive(player) or not player:inventory() then
			return
		end
		if visible then
			player:inventory():show_equipped_unit()
		else
			player:inventory():hide_equipped_unit()
		end
		local cam = player:camera() and player:camera():camera_unit()
		if alive(cam) then
			cam:set_visible(visible)
		end
	end)
end

function AS:apply_camera()
	if not self.active or not self:is_target_valid(self.target_unit) then
		self:stop("target lost")
		return
	end
	if not self:local_ok() then
		self:stop("local player unavailable")
		return
	end

	local player = managers.player:player_unit()
	if not alive(player) or not player:camera() then
		self:stop("no local camera")
		return
	end

	local pos, rot = self:get_eye_pose(self.target_unit)
	player:camera():set_position(pos)
	player:camera():set_rotation(rot)
end

function AS:start_on_unit(unit, slot)
	if not self:local_ok() then
		self:system_message("Ally Spectate: not available right now.")
		return false
	end
	if not self:is_target_valid(unit) then
		self:system_message("Ally Spectate: that ally is not available.")
		return false
	end

	self.active = true
	self.target_unit = unit
	self.target_slot = slot
	self:set_fp_weapon_visible(false)
	self:system_message(string.format("Spectating: %s  (return hotkey to exit)", unit_name_safe(unit)))
	self:log("start slot=" .. tostring(slot) .. " name=" .. unit_name_safe(unit))
	return true
end

function AS:start_slot(slot)
	if not self.settings.enabled then
		return
	end
	if not self:local_ok() then
		self:system_message("Ally Spectate: join a heist first.")
		return
	end

	local allies = self:collect_allies()
	local entry = allies[slot]
	if not entry then
		self:system_message(string.format("Ally Spectate: no ally in slot %d (found %d).", slot, #allies))
		return
	end

	-- Pressing the same slot again returns to self
	if self.active and self.target_slot == slot then
		self:stop("toggle off")
		return
	end

	self:start_on_unit(entry.unit, slot)
end

function AS:cycle(dir)
	if not self.settings.enabled or not self:local_ok() then
		return
	end
	local allies = self:collect_allies()
	if #allies == 0 then
		self:system_message("Ally Spectate: no allies to watch.")
		return
	end
	dir = dir or 1
	local idx = self.target_slot or 0
	idx = idx + dir
	if idx < 1 then
		idx = #allies
	elseif idx > #allies then
		idx = 1
	end
	self:start_on_unit(allies[idx].unit, idx)
end

function AS:stop(reason)
	if not self.active then
		return
	end
	self.active = false
	self.target_unit = nil
	self.target_slot = nil
	self:set_fp_weapon_visible(true)
	if reason and reason ~= "toggle off" then
		self:system_message("Ally Spectate: back to you (" .. tostring(reason) .. ").")
	else
		self:system_message("Ally Spectate: back to you.")
	end
	self:log("stop reason=" .. tostring(reason))
end

function AS:toggle_return()
	if self.active then
		self:stop("return")
	else
		self:system_message("Ally Spectate: not spectating.")
	end
end

AS:Load()
