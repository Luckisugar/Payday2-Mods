if not _G.AllySpectate or not AllySpectate.start_slot then
	dofile(ModPath .. "core.lua")
end
pcall(function()
	AllySpectate:start_slot(2)
end)
