--[[
	Loot Mule — stack set_carry / drop_carry / bank / force drop + throw distance

	Throw rules:
	  dump-all ON  → sequential drops with DUMP_GAP (bags eat each other if same-frame)
	  dump-all OFF → exactly one bag; next bag waits until G is released
	  zipline      → always one bag (zip only has one _attached_bag)
	  client       → no extra set_carry (host anticheat / ghost stack)
]]

if not LootMule or not LootMule.Load then
	dofile(ModPath .. "core.lua")
end

local LM = LootMule

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
local master_update = PlayerManager.update

-- Re-apply next stack entry without going through hooked set_carry.
local function reapply_top_carry(pm)
	if LM:Count() <= 0 then
		return
	end
	local cdata = LM.stack[LM:Count()]
	if not cdata or not LM:ValidCarryId(cdata.carry_id) then
		return
	end
	master_set_carry(
		pm,
		cdata.carry_id,
		cdata.multiplier or 1,
		cdata.dye_initiated,
		cdata.has_dye_pack,
		cdata.dye_value_multiplier
	)
end

local function stop_throw_state()
	LM:AbortThrow()
end

local function dump_step(pm)
	if not LM._dumping then
		return
	end
	if not pm:is_carrying() then
		if LM:Count() > 0 then
			reapply_top_carry(pm)
		end
	end
	if not pm:is_carrying() then
		stop_throw_state()
		if LM:Count() <= 0 then
			LM:ClearStack()
		end
		return
	end
	if LM._force_dump then
		master_force_drop(pm)
	else
		master_drop_carry(pm)
	end
	if LM:Count() > 0 then
		LM:RemoveTop()
	end
	if LM:Count() <= 0 then
		LM:ClearStack()
		stop_throw_state()
	else
		LM._dump_t = Application:time() + (LM.DUMP_GAP or 0.1)
	end
end

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

	-- Client extra pickup without host Loot Mule = ghost stack + host anticheat.
	if LM:IsMultiplayerClient() and LM:Count() > 0 and not LM:HostAllowsStack() then
		return
	end

	master_set_carry(self, ...)

	local data = self:get_my_carry_data()
	if data and data.carry_id then
		LM:AddCarry(data)
	end

	if PlayerStandard and PlayerStandard.block_use_item then
		PlayerStandard:block_use_item()
	end
end

function PlayerManager:drop_carry(zipline_unit, ...)
	if not LM:StackActive() then
		return master_drop_carry(self, zipline_unit, ...)
	end

	-- Ignore extra G while a dump / single-throw lock is running.
	if LM._dumping or LM._wait_release then
		return
	end

	local zip = zipline_unit and alive(zipline_unit)

	-- Zip only holds one bag. Never dump-all onto it (rest would float).
	if zip then
		master_drop_carry(self, zipline_unit, ...)
		if LM:Count() > 0 then
			LM:RemoveTop()
		end
		if LM:Count() > 0 then
			LM._wait_release = true
			LM._release_t = Application:time() + (LM.RELEASE_GAP or 0.05)
		end
		return
	end

	if LM:DumpAllOnThrow() and LM:Count() > 1 then
		LM._dumping = true
		LM._force_dump = false
		LM._wait_release = false
		dump_step(self)
		return
	end

	-- One bag per throw. Do NOT re-equip in this call — G is still held
	-- and PlayerCarry would throw the next bag in the same press.
	master_drop_carry(self, zipline_unit, ...)
	if LM:Count() > 0 then
		LM:RemoveTop()
	end
	if LM:Count() > 0 then
		LM._wait_release = true
		LM._release_t = Application:time() + (LM.RELEASE_GAP or 0.05)
	end
end

function PlayerManager:bank_carry(...)
	if not LM:StackActive() then
		return master_bank_carry(self, ...)
	end

	master_bank_carry(self, ...)

	if LM:Count() > 0 then
		LM:RemoveTop()
	end

	if LM:Count() > 0 then
		reapply_top_carry(self)
	end
end

function PlayerManager:force_drop_carry(...)
	if not LM:StackActive() or LM:Count() == 0 then
		return master_force_drop(self, ...)
	end

	if LM._dumping then
		LM._force_dump = true
		return
	end

	LM._dumping = true
	LM._force_dump = true
	LM._wait_release = false
	dump_step(self)
end

function PlayerManager:clear_carry(...)
	stop_throw_state()
	master_clear_carry(self, ...)
	if LM then
		LM:ClearStack()
	end
end

function PlayerManager:on_used_body_bag(...)
	if LM:IsEnabled() and LM:UnlimitedBodyBags() then
		return
	end
	return master_on_used_body_bag(self, ...)
end

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

local function lm_update(pm, t)
	if not LM then
		return
	end
	if LM._dumping then
		if t >= (LM._dump_t or 0) then
			dump_step(pm)
		end
		return
	end
	if LM._wait_release then
		local ready = t >= (LM._release_t or 0) and not LM:IsThrowHeld()
		if ready then
			LM._wait_release = false
			LM._release_t = 0
			if LM:Count() > 0 then
				reapply_top_carry(pm)
			end
		end
	end
end

if master_update then
	function PlayerManager:update(t, dt, ...)
		master_update(self, t, dt, ...)
		lm_update(self, t)
	end
else
	function PlayerManager:update(t, dt, ...)
		lm_update(self, t)
	end
end
