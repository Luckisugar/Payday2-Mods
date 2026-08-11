--[[
	Instant Heists — mission element execute delays (NPC waits, staged delays, bile/van timing, …)
	Host-authoritative.
]]

core:module("CoreMissionScriptElement")
core:import("CoreXml")
core:import("CoreCode")
core:import("CoreClass")

MissionScriptElement = MissionScriptElement or class()

local orig_base = MissionScriptElement._calc_base_delay
function MissionScriptElement:_calc_base_delay(...)
	local delay = orig_base(self, ...)
	local IH = _G.InstantHeists
	if IH and IH.ScaleTime and delay and delay > 0 then
		delay = IH:ScaleTime(delay)
	end
	return delay
end

local orig_elem = MissionScriptElement._calc_element_delay
function MissionScriptElement:_calc_element_delay(params, ...)
	local delay = orig_elem(self, params, ...)
	local IH = _G.InstantHeists
	if IH and IH.ScaleTime and delay and delay > 0 then
		delay = IH:ScaleTime(delay)
	end
	return delay
end
