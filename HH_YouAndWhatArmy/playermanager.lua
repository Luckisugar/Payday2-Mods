--[[
	You and What Army — convert_enemies_max_minions getter.
	Host convert, local minion counter, and the convert interaction all read this.
]]

if not YouAndWhatArmy or not YouAndWhatArmy.Load then
	dofile(ModPath .. "core.lua")
end

local YAWA = YouAndWhatArmy
local orig_upgrade_value = PlayerManager.upgrade_value

function PlayerManager:upgrade_value(category, upgrade, default)
	local v = orig_upgrade_value(self, category, upgrade, default)
	if category == "player" and upgrade == "convert_enemies_max_minions" and YAWA:LimitActive() then
		local cap = YAWA:MaxMinions()
		if type(v) == "number" then
			return math.max(v, cap)
		end
		return cap
	end
	return v
end
