--[[
	Loot Mule — bag / body pickup while stacking

	Pattern from Carry Stacker Reloaded (learned, not copied):
	- CarryInteractionExt:_interact_blocked → only can_carry (NOT is_carrying)
	- CarryInteractionExt:can_select → super.can_select + can_carry
	  (super skips the vanilla is_carrying gate on CarryInteractionExt)
	- IntimitateInteractionExt corpse_dispose → body bags + can_carry("person")
	  (vanilla also blocks is_carrying; we drop that check)

	Plus Loot Mule: optional crouch-only pickup.
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

function CarryInteractionExt:_interact_blocked(player)
	if not LM:IsEnabled() then
		return master_carry_blocked(self, player)
	end

	if not LM:CanPickupNow() then
		return true, false, "hint_not_crouching"
	end

	if managers.player:carry_blocked_by_cooldown() or attached_to_zipline(self._unit) then
		return true, true
	end

	-- CSR style: do NOT block on is_carrying — only can_carry
	return not managers.player:can_carry(self._unit:carry_data():carry_id())
end

function CarryInteractionExt:can_select(player)
	if not LM:IsEnabled() then
		return master_carry_select(self, player)
	end

	if not LM:CanPickupNow() then
		return false
	end

	if managers.player:carry_blocked_by_cooldown() or attached_to_zipline(self._unit) then
		return false
	end

	-- CSR: UseInteractionExt.super path (no is_carrying), then can_carry
	return CarryInteractionExt.super.can_select(self, player)
		and managers.player:can_carry(self._unit:carry_data():carry_id())
end

function IntimitateInteractionExt:_interact_blocked(player)
	if not LM:IsEnabled() then
		return master_int_blocked(self, player)
	end

	if self.tweak_data == "corpse_dispose" then
		if not LM:CanPickupNow() then
			return true, false, "hint_not_crouching"
		end

		-- Optional free body bags (cheat). CSR still checks deplete; we offer skip.
		if not LM:UnlimitedBodyBags() then
			if managers.player:chk_body_bags_depleted() then
				return true, nil, "body_bag_limit_reached"
			end
		end

		-- Still need the skill upgrade if the game requires it
		if not managers.player:has_category_upgrade("player", "corpse_dispose") then
			return true
		end

		-- CSR: skip vanilla is_carrying block; only can_carry("person")
		return not managers.player:can_carry("person")
	end

	return master_int_blocked(self, player)
end
