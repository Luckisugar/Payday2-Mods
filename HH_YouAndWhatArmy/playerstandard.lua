--[[
	You and What Army — skip the ~1.5s shout delay.
	Inspire / long-dis revive cooldown is untouched.
]]

if not YouAndWhatArmy or not YouAndWhatArmy.Load then
	dofile(ModPath .. "core.lua")
end

local YAWA = YouAndWhatArmy

if PlayerStandard and PlayerStandard._start_action_intimidate and not YAWA._hooked_playerstandard then
	YAWA._hooked_playerstandard = true
	local orig = PlayerStandard._start_action_intimidate
	function PlayerStandard:_start_action_intimidate(t, secondary)
		if YAWA:NoYellCooldownOn() then
			self._intimidate_t = nil
		end
		return orig(self, t, secondary)
	end
end
