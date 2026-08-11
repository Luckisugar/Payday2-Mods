--[[
	Loot Mule — BLT Mod Options
]]

_G.LootMule = _G.LootMule or {}
local LM = LootMule

LM._path = LM._path or ModPath
LM._data_path = LM._data_path or (SavePath .. "loot_mule.txt")

if not LM.Load then
	dofile((LM._path or ModPath) .. "core.lua")
end

if not LM.settings then
	LM:Load()
end

Hooks:Add("LocalizationManagerPostInit", "LootMule_loc", function(loc)
	loc:load_localization_file(LM._path .. "loc/english.txt")
end)

Hooks:Add("MenuManagerInitialize", "LootMule_MenuInit", function(menu_manager)
	MenuCallbackHandler.LootMule_Enabled = function(self, item)
		LM.settings.enabled = item:value() == "on"
		LM:Save()
	end
	MenuCallbackHandler.LootMule_CrouchPickup = function(self, item)
		LM.settings.crouch_pickup = item:value() == "on"
		LM:Save()
	end
	MenuCallbackHandler.LootMule_ThrowDistance = function(self, item)
		LM.settings.throw_distance = math.floor(item:value() * 100 + 0.5) / 100
		LM:Save()
	end
	MenuCallbackHandler.LootMule_StackHint = function(self, item)
		LM.settings.show_stack_hint = item:value() == "on"
		LM:Save()
	end
	MenuCallbackHandler.LootMule_UnlimitedBodyBags = function(self, item)
		LM.settings.unlimited_body_bags = item:value() == "on"
		LM:Save()
	end
	MenuCallbackHandler.LootMule_Save = function(self)
		LM:Save()
	end

	MenuHelper:LoadFromJsonFile(LM._path .. "options.txt", LM, LM.settings)
end)
