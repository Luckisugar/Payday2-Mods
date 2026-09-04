--[[
	Instant Heists — ElementTimer (mission script timers: vans, cooks, vault waits, …)
	Host-authoritative. Clients see host timers.

	v1.2.1: The Diamond (mus) — default DENY speed for all ElementTimers except
	explicit time-lock whitelist. Marks linked DigitalGui units with the same
	dt mult so display and logic never desync (UI 90s / door at 5s bug).
]]

core:module("CoreElementTimer")
core:import("CoreMissionScriptElement")

ElementTimer = ElementTimer or class(CoreMissionScriptElement.MissionScriptElement)

local orig_update = ElementTimer.update_timer

function ElementTimer:update_timer(t, dt)
	local IH = _G.InstantHeists
	local mult = 1
	if IH and IH.ShouldSpeedElementTimer and IH:ShouldSpeedElementTimer(self) then
		mult = IH:SpeedMult()
		if mult > 1 then
			dt = dt * mult
		end
	end
	-- Always refresh linked digital displays with this frame's mult (1 = vanilla).
	-- Prevents "logic sped, UI slow" when only ElementTimer was accelerated.
	if IH and IH.MarkLinkedDigitalGuis then
		IH:MarkLinkedDigitalGuis(self, mult)
	end
	return orig_update(self, t, dt)
end
