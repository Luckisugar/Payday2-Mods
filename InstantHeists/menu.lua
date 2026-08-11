--[[
	Instant Heists — BLT Mod Options
]]

_G.InstantHeists = _G.InstantHeists or {}
local IH = InstantHeists

IH._path = IH._path or ModPath
IH._data_path = IH._data_path or (SavePath .. "instant_heists.txt")

if not IH.Load then
	dofile((IH._path or ModPath) .. "core.lua")
end

if not IH.settings then
	IH:Load()
end

Hooks:Add("LocalizationManagerPostInit", "InstantHeists_loc", function(loc)
	loc:load_localization_file(IH._path .. "loc/english.txt")
end)

Hooks:Add("MenuManagerInitialize", "InstantHeists_MenuInit", function(menu_manager)
	MenuCallbackHandler.InstantHeists_Enabled = function(self, item)
		IH.settings.enabled = item:value() == "on"
		IH:Save()
	end
	MenuCallbackHandler.InstantHeists_Bypass = function(self, item)
		IH.settings.bypass_requirements = item:value() == "on"
		IH:Save()
	end
	MenuCallbackHandler.InstantHeists_SpeedTimers = function(self, item)
		IH.settings.speed_timers = item:value() == "on"
		IH:Save()
	end
	MenuCallbackHandler.InstantHeists_SpeedMissionDelays = function(self, item)
		IH.settings.speed_mission_delays = item:value() == "on"
		IH:Save()
	end
	MenuCallbackHandler.InstantHeists_SpeedInteract = function(self, item)
		IH.settings.speed_interact = item:value() == "on"
		IH:Save()
	end
	MenuCallbackHandler.InstantHeists_ProtectDangerous = function(self, item)
		IH.settings.protect_dangerous_interact = item:value() == "on"
		IH:Save()
	end
	MenuCallbackHandler.InstantHeists_VHUDCompat = function(self, item)
		IH.settings.vhud_compat = item:value() == "on"
		IH:Save()
	end
	MenuCallbackHandler.InstantHeists_SpeedMult = function(self, item)
		IH.settings.speed_multiplier = math.floor(item:value() + 0.5)
		IH:Save()
	end
	MenuCallbackHandler.InstantHeists_CrouchOnly = function(self, item)
		IH.settings.crouch_only = item:value() == "on"
		IH:Save()
	end
	MenuCallbackHandler.InstantHeists_Save = function(self)
		IH:Save()
	end

	MenuHelper:LoadFromJsonFile(IH._path .. "options.txt", IH, IH.settings)
end)
