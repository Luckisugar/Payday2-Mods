if not _G.AllySpectate or not AllySpectate.cycle then
	dofile(ModPath .. "core.lua")
end
pcall(function()
	AllySpectate:cycle(1)
end)
