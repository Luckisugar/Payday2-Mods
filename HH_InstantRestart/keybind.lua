--[[ SuperBLT keybind: Instant Restart ]]

if not _G.InstantRestart or not InstantRestart.request_restart then
	dofile(ModPath .. "core.lua")
end

pcall(function()
	InstantRestart:request_restart()
end)
