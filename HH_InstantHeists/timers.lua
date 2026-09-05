--[[
	Instant Heists — drill / vault / digital countdown speed

	TimerGui: smaller get_timer_multiplier() → faster drills/saws/hacks
	(vanilla: current_timer -= dt / multiplier). Fallback: scale dt in update
	if get_timer_multiplier is missing.

	DigitalGui: scale dt on countdown/count-up so display + logic match.

	This file is hooked on both timergui and digitalgui — guard against
	double wrapping.
]]

if not InstantHeists or not InstantHeists.Load then
	dofile(ModPath .. "core.lua")
end

local IH = InstantHeists

if TimerGui and not TimerGui._ih_speed_hooked then
	TimerGui._ih_speed_hooked = true
	if type(TimerGui.get_timer_multiplier) == "function" then
		local orig_mult = TimerGui.get_timer_multiplier
		function TimerGui:get_timer_multiplier(...)
			local m = orig_mult(self, ...)
			if not IH:TimersOn() then
				return m
			end
			m = tonumber(m) or 1
			return math.max(0.01, m / IH:SpeedMult())
		end
	elseif type(TimerGui.update) == "function" then
		local orig_update = TimerGui.update
		function TimerGui:update(unit, t, dt, ...)
			if IH:TimersOn() then
				dt = dt * IH:SpeedMult()
			end
			return orig_update(self, unit, t, dt, ...)
		end
	end
end

if DigitalGui and not DigitalGui._ih_speed_hooked then
	DigitalGui._ih_speed_hooked = true
	local orig_update = DigitalGui.update
	function DigitalGui:update(unit, t, dt)
		if self.TYPE == "timer" and not self._timer_paused then
			local mult = 1
			if IH.DigitalGuiSpeedMult then
				mult = IH:DigitalGuiSpeedMult(self)
			elseif IH:TimersOn() then
				mult = IH:SpeedMult()
			end
			if mult and mult > 1 then
				dt = dt * mult
			end
		end
		return orig_update(self, unit, t, dt)
	end
end
