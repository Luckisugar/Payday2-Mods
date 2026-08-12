--[[ Ally Spectate — Mod Options ]]

_G.AllySpectate = _G.AllySpectate or {}
local AS = AllySpectate

AS._path = AS._path or ModPath
AS._data_path = AS._data_path or (SavePath .. "ally_spectate.txt")

if not AS.Load then
	dofile((AS._path or ModPath) .. "core.lua")
end

if not AS.settings then
	AS:Load()
end

Hooks:Add("LocalizationManagerPostInit", "AllySpectate_loc", function(loc)
	loc:load_localization_file(AS._path .. "loc/english.txt")
end)

Hooks:Add("MenuManagerInitialize", "AllySpectate_MenuInit", function(menu_manager)
	MenuCallbackHandler.AllySpectate_Enabled = function(self, item)
		AS.settings.enabled = item:value() == "on"
		if not AS.settings.enabled and AS.active then
			AS:stop("disabled")
		end
		AS:Save()
	end
	MenuCallbackHandler.AllySpectate_Freeze = function(self, item)
		AS.settings.freeze_local = item:value() == "on"
		AS:Save()
	end
	MenuCallbackHandler.AllySpectate_Bots = function(self, item)
		AS.settings.include_bots = item:value() == "on"
		AS:Save()
	end
	MenuCallbackHandler.AllySpectate_HideFP = function(self, item)
		AS.settings.hide_fp_weapon = item:value() == "on"
		AS:Save()
	end
	MenuCallbackHandler.AllySpectate_Hint = function(self, item)
		AS.settings.show_hint = item:value() == "on"
		AS:Save()
	end
	MenuCallbackHandler.AllySpectate_AutoExit = function(self, item)
		AS.settings.auto_exit_on_damage = item:value() == "on"
		AS:Save()
	end
	MenuCallbackHandler.AllySpectate_EyeOffset = function(self, item)
		AS.settings.eye_offset = math.floor(item:value() + 0.5)
		AS:Save()
	end
	MenuCallbackHandler.AllySpectate_Debug = function(self, item)
		AS.settings.debug_log = item:value() == "on"
		AS:Save()
	end
	MenuCallbackHandler.AllySpectate_Save = function(self)
		AS:Save()
	end

	MenuHelper:LoadFromJsonFile(AS._path .. "options.txt", AS, AS.settings)
end)
