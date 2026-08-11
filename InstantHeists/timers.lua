--[[
	Instant Heists — drill / vault / digital countdown speed

	TimerGui: smaller get_timer_multiplier() → faster drills/saws/hacks.
	DigitalGui: scale dt on countdown/count-up so display + logic match.
]]

if not InstantHeists or not InstantHeists.Load then
	dofile(ModPath .. "core.lua")
end

local IH = InstantHeists

if TimerGui then
	local orig_mult = TimerGui.get_timer_multiplier
	function TimerGui:get_timer_multiplier()
		local m = orig_mult(self)
		if not IH:TimersOn() then
			return m
		end
		-- Vanilla: larger multiplier = slower. We want SpeedMult()x faster.
		return math.max(0.01, m / IH:SpeedMult())
	end
end

if DigitalGui then
	local orig_update = DigitalGui.update
	function DigitalGui:update(unit, t, dt)
		if IH:TimersOn() and self.TYPE == "timer" and not self._timer_paused then
			dt = dt * IH:SpeedMult()
		end
		return orig_update(self, unit, t, dt)
	end
end
