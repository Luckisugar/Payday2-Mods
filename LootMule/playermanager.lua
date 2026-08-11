--[[
	Loot Mule — stack set_carry / drop_carry / bank / force drop + throw distance
]]

if not LootMule or not LootMule.Load then
	dofile(ModPath .. "core.lua")
end

local LM = LootMule

-- Avoid The Fixes "remove bag from back" fighting multi-bag visuals
TheFixesPreventer = TheFixesPreventer or {}
TheFixesPreventer.remove_bag_from_back_playerman = true

local master_set_carry = PlayerManager.set_carry
local master_drop_carry = PlayerManager.drop_carry
local master_can_carry = PlayerManager.can_carry
local master_force_drop = PlayerManager.force_drop_carry
local master_clear_carry = PlayerManager.clear_carry
local master_bank_carry = PlayerManager.bank_carry
local master_sync_carry_data = PlayerManager.sync_carry_data

function PlayerManager:can_carry(carry_id, ...)
	if LM:IsEnabled() then
		return true
	end
	return master_can_carry(self, carry_id, ...)
end

function PlayerManager:set_carry(carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, ...)
	if not LM:StackActive() then
		return master_set_carry(self, carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, ...)
	end

	master_set_carry(self, carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, ...)
	local data = self:get_my_carry_data()
	if data then
		LM:AddCarry(data)
	else
		LM:AddCarry({
			carry_id = carry_id,
			multiplier = carry_multiplier or 1,
			dye_initiated = dye_initiated,
			has_dye_pack = has_dye_pack,
			dye_value_multiplier = dye_value_multiplier
		})
	end
end

function PlayerManager:drop_carry(zipline_unit, ...)
	if not LM:StackActive() or LM:Count() == 0 then
		-- May still be carrying vanilla single bag without stack entry
		return master_drop_carry(self, zipline_unit, ...)
	end

	master_drop_carry(self, zipline_unit, ...)
	LM:RemoveTop()

	if LM:Count() > 0 then
		local cdata = LM.stack[LM:Count()]
		master_set_carry(self, cdata.carry_id, cdata.multiplier or 1, cdata.dye_initiated, cdata.has_dye_pack, cdata.dye_value_multiplier)
	end
end

function PlayerManager:bank_carry(...)
	if not LM:StackActive() or LM:Count() == 0 then
		return master_bank_carry(self, ...)
	end

	master_bank_carry(self, ...)
	LM:RemoveTop()

	if LM:Count() > 0 then
		local cdata = LM.stack[LM:Count()]
		master_set_carry(self, cdata.carry_id, cdata.multiplier or 1, cdata.dye_initiated, cdata.has_dye_pack, cdata.dye_value_multiplier)
	end
end

function PlayerManager:force_drop_carry(...)
	if not LM:StackActive() or LM:Count() == 0 then
		return master_force_drop(self, ...)
	end

	-- Drop entire stack (custody / scripted force drop)
	local guard = 0
	while LM:Count() > 0 and guard < 200 do
		guard = guard + 1
		master_force_drop(self, ...)
		LM:RemoveTop()
		if LM:Count() > 0 then
			local cdata = LM.stack[LM:Count()]
			master_set_carry(self, cdata.carry_id, cdata.multiplier or 1, cdata.dye_initiated, cdata.has_dye_pack, cdata.dye_value_multiplier)
		end
	end
	LM:ClearStack()
end

function PlayerManager:clear_carry(soft_reset, ...)
	master_clear_carry(self, soft_reset, ...)
	if LM then
		LM:ClearStack()
	end
end

--- Scale throw push for bags you drop (peer_id match). Works best when host has the mod for client throws.
function PlayerManager:sync_carry_data(unit, carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, position, dir, throw_distance_multiplier_upgrade_level, zipline_unit, peer_id, ...)
	local mult = LM:ThrowMult()
	if mult ~= 1 and dir and not zipline_unit then
		local session = managers.network and managers.network:session()
		local local_id = session and session:local_peer() and session:local_peer():id()
		if peer_id and local_id and peer_id == local_id then
			dir = dir * mult
		elseif not peer_id or peer_id == 0 then
			-- solo / no peer id
			dir = dir * mult
		end
	end
	return master_sync_carry_data(self, unit, carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, position, dir, throw_distance_multiplier_upgrade_level, zipline_unit, peer_id, ...)
end
