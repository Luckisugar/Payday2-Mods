--[[
	Loot Mule — bag / body pickup while stacking; crouch required for pickup
]]

if not LootMule or not LootMule.Load then
	dofile(ModPath .. "core.lua")
end

local LM = LootMule

local master_carry_blocked = CarryInteractionExt._interact_blocked
local master_carry_select = CarryInteractionExt.can_select
local master_int_blocked = IntimitateInteractionExt and IntimitateInteractionExt._interact_blocked

function CarryInteractionExt:_interact_blocked(player)
	if not LM:IsEnabled() then
		return master_carry_blocked(self, player)
	end

	if not LM:CanPickupNow() then
		return true, false, "hint_not_crouching"
	end

	local silent_block = managers.player:carry_blocked_by_cooldown()
		or (self._unit:carry_data() and self._unit:carry_data():is_attached_to_zipline_unit and self._unit:carry_data():is_attached_to_zipline_unit())

	if silent_block then
		return true, true
	end

	-- Stacking: already carrying is OK
	return false
end

function CarryInteractionExt:can_select(player)
	if not LM:IsEnabled() then
		return master_carry_select(self, player)
	end

	if not LM:CanPickupNow() then
		return false
	end

	if managers.player:carry_blocked_by_cooldown() then
		return false
	end

	if self._unit:carry_data() and self._unit:carry_data():is_attached_to_zipline_unit and self._unit:carry_data():is_attached_to_zipline_unit() then
		return false
	end

	return CarryInteractionExt.super.can_select(self, player)
end

-- Body bags (corpse_dispose) also stack via set_carry("person")
if IntimitateInteractionExt and master_int_blocked then
	function IntimitateInteractionExt:_interact_blocked(player)
		if not LM:IsEnabled() then
			return master_int_blocked(self, player)
		end

		if self.tweak_data == "corpse_dispose" then
			if managers.player:chk_body_bags_depleted and managers.player:chk_body_bags_depleted() then
				return true, nil, "body_bag_limit_reached"
			end
			if not LM:CanPickupNow() then
				return true, false, "hint_not_crouching"
			end
			return false
		end

		return master_int_blocked(self, player)
	end
end
