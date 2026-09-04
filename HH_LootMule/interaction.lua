--[[
	Loot Mule — bag / body pickup while stacking

	Pattern from Carry Stacker Reloaded (learned, not copied):
	- CarryInteractionExt:_interact_blocked → only can_carry (NOT is_carrying)
	- CarryInteractionExt:can_select → super.can_select + can_carry
	- IntimitateInteractionExt corpse_dispose → skip vanilla is_carrying

	Plus: crouch gate, host-only extra bags, nil-safe carry_data (warheads).
]]

if not LootMule or not LootMule.Load then
	dofile(ModPath .. "core.lua")
end

local LM = LootMule

local master_carry_blocked = CarryInteractionExt._interact_blocked
local master_carry_select = CarryInteractionExt.can_select
local master_int_blocked = IntimitateInteractionExt._interact_blocked

local function attached_to_zipline(unit)
	if not alive(unit) or not unit.carry_data then
		return false
	end
	local cd = unit:carry_data()
	if not cd then
		return false
	end
	if cd.is_attached_to_zipline_unit then
		return cd:is_attached_to_zipline_unit()
	end
	return false
end

local function unit_carry_id(unit)
	if not alive(unit) or not unit.carry_data then
		return nil
	end
	local cd = unit:carry_data()
	if not cd or not cd.carry_id then
		return nil
	end
	local ok, id = pcall(function()
		return cd:carry_id()
	end)
	if not ok or not LM:ValidCarryId(id) then
		return nil
	end
	return id
end

local function block_hint(reason)
	if reason == "host_only" then
		return true, false, "lm_hint_host_only"
	end
	if reason == "busy" then
		return true, false, "lm_hint_busy"
	end
	if reason == "crouch" then
		return true, false, "hint_not_crouching"
	end
	if reason then
		return true, false, "hint_not_crouching"
	end
	return nil
end

function CarryInteractionExt:_interact_blocked(player)
	if not LM:IsEnabled() then
		return master_carry_blocked(self, player)
	end

	local reason = LM:PickupBlockReason()
	if reason then
		return block_hint(reason)
	end

	if managers.player:carry_blocked_by_cooldown() or attached_to_zipline(self._unit) then
		return true, true
	end

	local id = unit_carry_id(self._unit)
	if not id then
		return true, true
	end

	return not managers.player:can_carry(id)
end

function CarryInteractionExt:can_select(player)
	if not LM:IsEnabled() then
		return master_carry_select(self, player)
	end

	local reason = LM:PickupBlockReason()
	-- Host-only extra: keep selectable so the hint can fire on interact.
	if reason and reason ~= "host_only" then
		return false
	end

	if managers.player:carry_blocked_by_cooldown() or attached_to_zipline(self._unit) then
		return false
	end

	local id = unit_carry_id(self._unit)
	if not id then
		return false
	end

	return CarryInteractionExt.super.can_select(self, player)
		and managers.player:can_carry(id)
end

function IntimitateInteractionExt:_interact_blocked(player)
	if not LM:IsEnabled() then
		return master_int_blocked(self, player)
	end

	if self.tweak_data == "corpse_dispose" then
		local reason = LM:PickupBlockReason()
		if reason then
			return block_hint(reason)
		end

		if not LM:UnlimitedBodyBags() then
			if managers.player:chk_body_bags_depleted() then
				return true, nil, "body_bag_limit_reached"
			end
		end

		if not managers.player:has_category_upgrade("player", "corpse_dispose") then
			return true
		end

		return not managers.player:can_carry("person")
	end

	return master_int_blocked(self, player)
end
