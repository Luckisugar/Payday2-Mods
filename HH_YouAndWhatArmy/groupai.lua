--[[
	You and What Army — dominate-room cap.
	Vanilla shares ~4 police hostages + converted cops. Extra jokers eat that
	room, so without this you cannot cuff the next cop to convert.
]]

if not YouAndWhatArmy or not YouAndWhatArmy.Load then
	dofile(ModPath .. "core.lua")
end

local YAWA = YouAndWhatArmy
local orig_has_room = GroupAIStateBase.has_room_for_police_hostage

function GroupAIStateBase:has_room_for_police_hostage()
	if not YAWA:LimitActive() then
		return orig_has_room(self)
	end

	local nr_hostages_allowed = YAWA.DOMINATE_SLACK + YAWA:MaxMinions()

	for _, u_data in pairs(self._player_criminals or {}) do
		local unit = u_data and u_data.unit
		if alive(unit) and unit:base() then
			if unit:base().is_local_player then
				if managers.player:has_category_upgrade("player", "intimidate_enemies") then
					nr_hostages_allowed = nr_hostages_allowed + 1
				end
			elseif unit:base().upgrade_value and unit:base():upgrade_value("player", "intimidate_enemies") then
				nr_hostages_allowed = nr_hostages_allowed + 1
			end
		end
	end

	local converted = self._converted_police and table.size(self._converted_police) or 0
	return nr_hostages_allowed > (self._police_hostage_headcount or 0) + converted
end
