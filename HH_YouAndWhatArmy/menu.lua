--[[
	You and What Army — BLT options under Heist Helper.
]]

if not YouAndWhatArmy or not YouAndWhatArmy.Load then
	dofile(ModPath .. "core.lua")
end

local YAWA = YouAndWhatArmy

YAWA._path = YAWA._path or ModPath
YAWA._data_path = YAWA._data_path or (SavePath .. "you_and_what_army.txt")

if not YAWA.settings or YAWA.settings.max_minions == nil then
	YAWA:Load()
end

Hooks:Add("LocalizationManagerPostInit", "YouAndWhatArmy_loc", function(loc)
	loc:load_localization_file(YAWA._path .. "loc/english.txt")
end)

Hooks:Add("MenuManagerInitialize", "YouAndWhatArmy_MenuInit", function(menu_manager)
	MenuCallbackHandler.YouAndWhatArmy_Enabled = function(self, item)
		YAWA.settings.enabled = item:value() == "on"
		YAWA:Save()
	end
	MenuCallbackHandler.YouAndWhatArmy_MaxMinions = function(self, item)
		YAWA.settings.max_minions = YAWA:ClampMinions(item:value())
		YAWA:Save()
	end
	MenuCallbackHandler.YouAndWhatArmy_MaxThreat = function(self, item)
		YAWA.settings.max_threat = item:value() == "on"
		YAWA:Save()
	end
	MenuCallbackHandler.YouAndWhatArmy_InstaRecruit = function(self, item)
		YAWA.settings.insta_recruit = item:value() == "on"
		YAWA:Save()
	end
	MenuCallbackHandler.YouAndWhatArmy_NoYellCooldown = function(self, item)
		YAWA.settings.no_yell_cooldown = item:value() == "on"
		YAWA:Save()
	end
	MenuCallbackHandler.YouAndWhatArmy_LobbyYells = function(self, item)
		YAWA.settings.lobby_yells = item:value() == "on"
		YAWA:Save()
	end
	MenuCallbackHandler.YouAndWhatArmy_Save = function(self)
		YAWA:Save()
	end

	MenuHelper:LoadFromJsonFile(YAWA._path .. "options.txt", YAWA, YAWA.settings)
end)
