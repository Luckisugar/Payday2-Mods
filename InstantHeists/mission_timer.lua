--[[
	Instant Heists — ElementTimer (mission script timers: vans, cooks, vault waits, …)
	Host-authoritative. Clients see host timers.
]]

core:module("CoreElementTimer")
core:import("CoreMissionScriptElement")

ElementTimer = ElementTimer or class(CoreMissionScriptElement.MissionScriptElement)

local orig_update = ElementTimer.update_timer

function ElementTimer:update_timer(t, dt)
	local IH = _G.InstantHeists
	if IH and IH.TimersOn and IH:TimersOn() then
		dt = dt * IH:SpeedMult()
	end
	return orig_update(self, t, dt)
end
