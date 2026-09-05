--[[
	Instant Heists — ElementTimer (mission script timers: vans, cooks, vault waits, …)
	Host-authoritative. Clients see host timers.

	Capture the real _G BEFORE core:module(). After core:module the file env is
	the CoreElementTimer module, whose __index is a pristine snapshot from
	boot — InstantHeists is not there. Bare/module _G lookups silently nil out
	and speed becomes a no-op.
]]

local REAL_G = _G

core:module("CoreElementTimer")
core:import("CoreMissionScriptElement")

ElementTimer = ElementTimer or class(CoreMissionScriptElement.MissionScriptElement)

local orig_update = ElementTimer.update_timer
if type(orig_update) == "function" then
	function ElementTimer:update_timer(t, dt)
		local IH = REAL_G.InstantHeists
		local mult = 1
		if IH and IH.ShouldSpeedElementTimer and IH:ShouldSpeedElementTimer(self) then
			mult = IH:SpeedMult()
			if mult > 1 then
				dt = dt * mult
			end
		end
		if IH and IH.MarkLinkedDigitalGuis then
			IH:MarkLinkedDigitalGuis(self, mult)
		end
		return orig_update(self, t, dt)
	end
end
