--[[ SuperBLT keybind: toggle bag stash (no weight) ]]

if not _G.LootMule or not LootMule.ToggleStash then
	dofile(ModPath .. "core.lua")
end

if not LootMule or not LootMule.ToggleStash then
	return
end

local on = LootMule:ToggleStash()
if managers.hud and managers.hud.show_hint then
	managers.hud:show_hint({
		text = on and "Loot Mule: bags stashed (no weight)" or "Loot Mule: bag weight back on",
		time = 2
	})
end
