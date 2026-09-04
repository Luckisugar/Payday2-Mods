--[[
	Loot Mule — nil-safe carry type lookups (warheads / explosives bags).

	Vanilla can_explode / can_poof index tweak_data.carry[id].type with no
	guard. A bag whose carry_id is not synced yet (or is garbage) crashes.
]]

if not LootMule or not LootMule.Load then
	dofile(ModPath .. "core.lua")
end

if not CarryData then
	return
end

local function carry_type_tweak(carry)
	local id = carry and carry._carry_id
	local td = tweak_data and tweak_data.carry
	if not id or not td or type(td[id]) ~= "table" then
		return nil
	end
	local typ = td[id].type
	if not typ or not td.types then
		return nil
	end
	return td.types[typ]
end

local master_explode = CarryData.can_explode
if master_explode then
	function CarryData:can_explode(...)
		if not carry_type_tweak(self) then
			return false
		end
		return master_explode(self, ...)
	end
end

local master_poof = CarryData.can_poof
if master_poof then
	function CarryData:can_poof(...)
		if not carry_type_tweak(self) then
			return false
		end
		return master_poof(self, ...)
	end
end
