--[[
	Instant Heists — interaction requirement bypass

	Rules:
	- If the player HAS the required special equipment / deployable → normal interact (consume when equipment_consume).
	- If they do NOT → still allow the interaction (no free items spawned).
]]

if not InstantHeists or not InstantHeists.Load then
	dofile(ModPath .. "core.lua")
end

local IH = InstantHeists

local function movement_state(player)
	if alive(player) and player.movement and player:movement() and player:movement().current_state_name then
		return player:movement():current_state_name()
	end
	return nil
end

--- Soft checks that still apply under bypass (host/disabled/state/blockers). Skips equipment + deployable gates.
local function soft_can_interact(self, player)
	if self._host_only and not Network:is_server() then
		return false
	end
	if self._disabled then
		return false
	end
	local state = movement_state(player)
	if not self:_has_required_upgrade(state) then
		return false
	end
	if not self:_is_in_required_state(state) then
		return false
	end
	if self._tweak_data and self._tweak_data.special_equipment_block then
		local blockers = self._tweak_data.special_equipment_block
		if type(blockers) == "string" then
			if managers.player:has_special_equipment(blockers) then
				return false
			end
		elseif type(blockers) == "table" then
			for _, blocker in pairs(blockers) do
				if managers.player:has_special_equipment(blocker) then
					return false
				end
			end
		end
	end
	return true
end

-- BaseInteractionExt --------------------------------------------------------

local orig_can_interact = BaseInteractionExt.can_interact
function BaseInteractionExt:can_interact(player)
	local ok = orig_can_interact(self, player)
	if ok then
		return true
	end
	if not IH:BypassOn() then
		return false
	end
	return soft_can_interact(self, player)
end

local orig_can_select = BaseInteractionExt.can_select
function BaseInteractionExt:can_select(player, locator)
	local ok = orig_can_select(self, player, locator)
	if ok then
		return true
	end
	if not IH:BypassOn() then
		return false
	end
	-- can_select also gates on required_deployable; allow select so prompt appears
	if self._host_only and not Network:is_server() then
		return false
	end
	local state = movement_state(player)
	if not self:_has_required_upgrade(state) then
		return false
	end
	if not self:_is_in_required_state(state) then
		return false
	end
	if self._tweak_data and self._tweak_data.special_equipment_block then
		local blockers = self._tweak_data.special_equipment_block
		if type(blockers) == "string" then
			if managers.player:has_special_equipment(blockers) then
				return false
			end
		elseif type(blockers) == "table" then
			for _, blocker in pairs(blockers) do
				if managers.player:has_special_equipment(blocker) then
					return false
				end
			end
		end
	end
	if self._tweak_data and self._tweak_data.verify_owner and not self:is_owner() then
		return false
	end
	return true
end

--[[
	Hold-to-interact duration (pick locks, bags, etc.)

	VHUD+ (and similar) auto-hold when timer >= MIN_TIMER_DURATION and remap
	drop-bag/G to cancel with an alarm warning. Blind ScaleTime() made pagers
	and long holds fall under that threshold → lock/cancel UI never armed.
	ScaleInteractTime() skips dangerous IDs and clamps for VHUD when present.
]]
local orig_get_timer = BaseInteractionExt._get_timer
function BaseInteractionExt:_get_timer()
	local t = orig_get_timer(self)
	if not t then
		return t
	end
	if IH.ScaleInteractTime then
		return IH:ScaleInteractTime(self, t)
	end
	return IH:ScaleTime(t)
end

-- MultipleChoiceInteractionExt (cook ingredients, multi-equipment stations) --

if MultipleChoiceInteractionExt then
	local orig_mc_can = MultipleChoiceInteractionExt.can_interact
	function MultipleChoiceInteractionExt:can_interact(player)
		local ok = orig_mc_can(self, player)
		if ok then
			return true
		end
		if not IH:BypassOn() then
			return false
		end
		return soft_can_interact(self, player)
	end

	local orig_mc_interact = MultipleChoiceInteractionExt.interact
	function MultipleChoiceInteractionExt:interact(player)
		if not IH:BypassOn() then
			return orig_mc_interact(self, player)
		end

		if self._tweak_data.dont_need_equipment then
			return orig_mc_interact(self, player)
		end

		-- Has the correct item → vanilla path (consumes).
		if self._tweak_data.special_equipment and managers.player:has_special_equipment(self._tweak_data.special_equipment) then
			return orig_mc_interact(self, player)
		end

		-- Has any of the possible alternatives → vanilla path.
		if self._tweak_data.possible_special_equipment then
			for _, special_equipment in ipairs(self._tweak_data.possible_special_equipment) do
				if managers.player:has_special_equipment(special_equipment) then
					return orig_mc_interact(self, player)
				end
			end
		end

		-- Missing item: force the success path without consuming / without "wrong" sequence.
		if not self:can_interact(player) then
			return
		end
		UseInteractionExt.super.interact(self, player)
		if self._tweak_data.sound_event and alive(player) and player.sound then
			player:sound():play(self._tweak_data.sound_event)
		end
		self:remove_interact()
		if self._unit:damage() then
			self._unit:damage():run_sequence_simple("interact", { unit = player })
		end
		if self._unit:id() ~= -1 or self._unit:unit_data() and self._unit:unit_data().unit_id then
			managers.network:session():send_to_peers_synched("sync_interacted", self._unit, -2, self.tweak_data, 1)
		end
		if self._global_event then
			managers.mission:call_global_event(self._global_event, player)
		end
		if self._check_achievements then
			self:_check_achievements()
		end
		if not self.keep_active_after_interaction then
			self:set_active(false)
		end
		return true
	end
end

--[[
	Shaped charges / drills / saws on mission doors:
	MissionDoorDeviceInteractionExt:result_place_mission_door_device always
	calls remove_equipment / remove_special. Vanilla never reaches that without
	the deployable; with bypass we do → nil equipment crash in PlayerManager.
	Consume only if owned.
]]
if MissionDoorDeviceInteractionExt then
	local orig_result_place = MissionDoorDeviceInteractionExt.result_place_mission_door_device
	function MissionDoorDeviceInteractionExt:result_place_mission_door_device(placed)
		if not IH:BypassOn() then
			return orig_result_place(self, placed)
		end
		if not placed then
			return
		end
		local td = self._tweak_data
		if not td then
			return
		end
		if td.equipment_consume and td.special_equipment then
			if managers.player:has_special_equipment(td.special_equipment) then
				managers.player:remove_special(td.special_equipment)
			end
		end
		if td.deployable_consume and td.required_deployable then
			local slot = td.slot or 1
			if managers.player:has_deployable_left(td.required_deployable, slot) then
				managers.player:remove_equipment(td.required_deployable, slot)
			end
			if not managers.player:selected_equipment() then
				managers.player:switch_equipment()
			end
		end
	end
end

-- UseInteractionExt also remove_equipment / remove_special on consume flags.
-- Safe path when bypass allowed the interact without owning the item.
if UseInteractionExt then
	local orig_use_interact = UseInteractionExt.interact
	function UseInteractionExt:interact(player)
		if not IH:BypassOn() then
			return orig_use_interact(self, player)
		end
		if not self:can_interact(player) then
			return
		end

		local td = self._tweak_data
		local has_special = not td.special_equipment
			or td.dont_need_equipment
			or managers.player:has_special_equipment(td.special_equipment)
		local has_deployable = not td.required_deployable
			or managers.player:has_deployable_left(td.required_deployable, td.slot or 1)

		-- Owned everything → vanilla (consumes correctly).
		if has_special and has_deployable then
			return orig_use_interact(self, player)
		end

		-- Missing gear: success without crashing on remove_*.
		UseInteractionExt.super.interact(self, player)

		if td.equipment_consume and td.special_equipment and managers.player:has_special_equipment(td.special_equipment) then
			managers.player:remove_special(td.special_equipment)
		end
		if td.deployable_consume and td.required_deployable and managers.player:has_deployable_left(td.required_deployable, td.slot or 1) then
			managers.player:remove_equipment(td.required_deployable, td.slot or 1)
		end
		if td.sound_event and alive(player) and player.sound then
			player:sound():play(td.sound_event)
		end
		self:remove_interact()
		if self._unit:damage() then
			self._unit:damage():run_sequence_simple("interact", { unit = player })
		end
		if managers.network and managers.network:session() then
			managers.network:session():send_to_peers_synched("sync_interacted", self._unit, -2, self.tweak_data, 1)
		end
		if self._global_event then
			managers.mission:call_global_event(self._global_event, player)
		end
		if self._achievement_stat then
			managers.achievment:award_progress(self._achievement_stat)
		elseif self._achievement_id then
			managers.achievment:award(self._achievement_id)
		end
		if not self.keep_active_after_interaction then
			self:set_active(false)
		end
		return true
	end
end
