--[[
	Instant Heists — mission element execute delays (NPC waits, staged delays, …)

	Gated by ShouldScaleMissionDelay:
	- Dialogue / radio VO elements are never scaled.
	- Cook / supply waits (Cook Off, Rats, …) scale with "Speed up timers".
	- Global "Speed mission script delays" still scales other waits (OFF by
	  default — that one can make Bain reminder lines spam).
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
	-- Do not look at the *target* element: cook waits often delay *into*
	-- Bain's next ingredient line. Skipping those would leave cook at 20–25s.
	if IH.ShouldScaleMissionDelay and not IH:ShouldScaleMissionDelay(self, delay) then
		return delay
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
