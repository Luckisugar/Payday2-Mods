--[[
	Diamond Path Helper — arm capture when the chamber path box finishes hacking
]]

_G.DiamondPathHelper = _G.DiamondPathHelper or {}
local DPH = DiamondPathHelper

local function is_diamond_level()
	local level_id = Global.game_settings and Global.game_settings.level_id
	return level_id == "mus"
end

if BaseInteractionExt then
	Hooks:PostHook(BaseInteractionExt, "interact", "DiamondPathHelper_BaseInteract", function(self, player)
		if not DPH.IsEnabled or not DPH:IsEnabled() then
			return
		end
		if not is_diamond_level() then
			return
		end
		-- Only the glass-floor path box uses this tweak on mus for the path phase.
		-- Museum rewires also use hack_electric_box — those fire earlier and just
		-- re-arm empty; real path cells arrive later with setup_path / path_on.
		if self.tweak_data == "hack_electric_box" then
			-- Soft arm (no wipe). Museum rewires are the same tweak_data;
			-- chamber path_on / setup_path supply the real tiles afterward.
			if DPH.Arm then
				DPH:Arm("hack_electric_box", false)
			elseif DPH.BeginCollect then
				DPH:BeginCollect()
			end
		end
	end)
end
