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

-- Hold-to-interact duration (pick locks, bags, etc.)
local orig_get_timer = BaseInteractionExt._get_timer
function BaseInteractionExt:_get_timer()
	local t = orig_get_timer(self)
	if not t then
		return t
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
