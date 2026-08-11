--[[
	Instant Heists — mission element execute delays (NPC waits, staged delays, …)

	Gated by speed_mission_delays (default OFF). Speeding these also shortens
	Bain/radio reminder loops (Car Shop C4 spam). Drills/vaults/ElementTimer
	use separate hooks and stay under "Speed up timers".
]]

core:module("CoreMissionScriptElement")
core:import("CoreXml")
core:import("CoreCode")
core:import("CoreClass")

MissionScriptElement = MissionScriptElement or class()

local function scale_delay(self, delay, params)
	local IH = _G.InstantHeists
	if not IH or not delay or delay <= 0 then
		return delay
	end
	if not IH.MissionDelaysOn or not IH:MissionDelaysOn() then
		return delay
	end
	-- Even with delays on: never rush pure dialogue / radio VO chains.
	if IH.IsDialogueElement then
		if IH:IsDialogueElement(self) then
			return delay
		end
		if params and params.id and self.get_mission_element then
			local target = self:get_mission_element(params.id)
			if IH:IsDialogueElement(target) then
				return delay
			end
		end
	end
	if IH.ScaleTime then
		return IH:ScaleTime(delay)
	end
	return delay
end

local orig_base = MissionScriptElement._calc_base_delay
function MissionScriptElement:_calc_base_delay(...)
	return scale_delay(self, orig_base(self, ...), nil)
end

local orig_elem = MissionScriptElement._calc_element_delay
function MissionScriptElement:_calc_element_delay(params, ...)
	return scale_delay(self, orig_elem(self, params, ...), params)
end
