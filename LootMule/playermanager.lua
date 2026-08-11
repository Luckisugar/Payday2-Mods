--[[
	Loot Mule — stack set_carry / drop_carry / bank / force drop + throw distance

	Stack flow mirrors Carry Stacker Reloaded:
	set_carry → master + push stack
	drop_carry → master drop, pop stack, master set_carry next (if any)
]]

if not LootMule or not LootMule.Load then
	dofile(ModPath .. "core.lua")
end

local LM = LootMule

-- The Fixes: multi-bag visual / missing bag when throwing stack
TheFixesPreventer = TheFixesPreventer or {}
TheFixesPreventer.remove_bag_from_back_playerman = true

local master_set_carry = PlayerManager.set_carry
local master_drop_carry = PlayerManager.drop_carry
local master_can_carry = PlayerManager.can_carry
local master_force_drop = PlayerManager.force_drop_carry
local master_clear_carry = PlayerManager.clear_carry
local master_bank_carry = PlayerManager.bank_carry
local master_sync_carry_data = PlayerManager.sync_carry_data
local master_on_used_body_bag = PlayerManager.on_used_body_bag

function PlayerManager:can_carry(carry_id, ...)
	if LM:IsEnabled() then
		return true
	end
	return master_can_carry(self, carry_id, ...)
end

function PlayerManager:set_carry(...)
	if not LM:StackActive() then
		return master_set_carry(self, ...)
	end

	master_set_carry(self, ...)

	local data = self:get_my_carry_data()
	if data then
		LM:AddCarry(data)
	end

	-- CSR: short block so throw key doesn't instantly dump the bag you just grabbed
	if PlayerStandard and PlayerStandard.block_use_item then
		PlayerStandard:block_use_item()
	end
end

function PlayerManager:drop_carry(...)
	if not LM:StackActive() then
		return master_drop_carry(self, ...)
	end

	-- Even if stack is empty, still drop vanilla bag (edge case)
	master_drop_carry(self, ...)
	LM:RemoveTop()

	if LM:Count() > 0 then
		local cdata = LM.stack[LM:Count()]
		master_set_carry(
			self,
			cdata.carry_id,
			cdata.multiplier or 1,
			cdata.dye_initiated,
			cdata.has_dye_pack,
			cdata.dye_value_multiplier
		)
	end
end

function PlayerManager:bank_carry(...)
	if not LM:StackActive() then
		return master_bank_carry(self, ...)
	end

	master_bank_carry(self, ...)
	LM:RemoveTop()

	if LM:Count() > 0 then
		local cdata = LM.stack[LM:Count()]
		master_set_carry(
			self,
			cdata.carry_id,
			cdata.multiplier or 1,
			cdata.dye_initiated,
			cdata.has_dye_pack,
			cdata.dye_value_multiplier
		)
	end
end

function PlayerManager:force_drop_carry(...)
	if not LM:StackActive() or LM:Count() == 0 then
		return master_force_drop(self, ...)
	end

	local guard = 0
	while LM:Count() > 0 and guard < 200 do
		guard = guard + 1
		master_force_drop(self, ...)
		LM:RemoveTop()
		if LM:Count() > 0 then
			local cdata = LM.stack[LM:Count()]
			master_set_carry(
				self,
				cdata.carry_id,
				cdata.multiplier or 1,
				cdata.dye_initiated,
				cdata.has_dye_pack,
				cdata.dye_value_multiplier
			)
		end
	end
	LM:ClearStack()
end

function PlayerManager:clear_carry(...)
	master_clear_carry(self, ...)
	if LM then
		LM:ClearStack()
	end
end

--- Unlimited body bags: skip consumption when the option is on.
function PlayerManager:on_used_body_bag(...)
	if LM:IsEnabled() and LM:UnlimitedBodyBags() then
		return
	end
	return master_on_used_body_bag(self, ...)
end

--- Scale throw push for bags you drop.
function PlayerManager:sync_carry_data(unit, carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, position, dir, throw_distance_multiplier_upgrade_level, zipline_unit, peer_id, ...)
	local mult = LM:ThrowMult()
	if mult ~= 1 and dir and not zipline_unit then
		local session = managers.network and managers.network:session()
		local local_id = session and session:local_peer() and session:local_peer():id()
		if peer_id and local_id and peer_id == local_id then
			dir = dir * mult
		elseif not peer_id or peer_id == 0 then
			dir = dir * mult
		end
	end
	return master_sync_carry_data(
		self,
		unit,
		carry_id,
		carry_multiplier,
		dye_initiated,
		has_dye_pack,
		dye_value_multiplier,
		position,
		dir,
		throw_distance_multiplier_upgrade_level,
		zipline_unit,
		peer_id,
		...
	)
end
