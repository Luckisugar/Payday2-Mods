if not _G.AllySpectate or not AllySpectate.toggle_return then
	dofile(ModPath .. "core.lua")
end
pcall(function()
	AllySpectate:toggle_return()
end)
