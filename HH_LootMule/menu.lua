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
		if LM.BroadcastHostState then
			LM:BroadcastHostState()
		end
		if LM.ApplyStashFeel then
			LM:ApplyStashFeel()
		end
	end
	MenuCallbackHandler.LootMule_CrouchPickup = function(self, item)
		LM.settings.crouch_pickup = item:value() == "on"
		LM:Save()
	end
	MenuCallbackHandler.LootMule_Stash = function(self, item)
		LM.settings.stash = item:value() == "on"
		LM:Save()
		if LM.ApplyStashFeel then
			LM:ApplyStashFeel()
		end
	end
	MenuCallbackHandler.LootMule_ThrowType = function(self, item)
		local id = item:name()
		local key
		if id == "lm_throw_distance" then
			key = "throw_distance"
		elseif type(id) == "string" and id:sub(1, 9) == "lm_throw_" then
			key = "throw_" .. id:sub(10)
		end
		if key then
			LM.settings[key] = LM:ClampThrow(item:value())
			LM:Save()
		end
	end
	MenuCallbackHandler.LootMule_DumpAll = function(self, item)
		LM.settings.dump_all = item:value() == "on"
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
	MenuHelper:LoadFromJsonFile(LM._path .. "throw_options.txt", LM, LM.settings)
end)
