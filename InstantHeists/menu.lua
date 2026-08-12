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
	MenuCallbackHandler.InstantHeists_ProtectPuzzle = function(self, item)
		IH.settings.protect_puzzle_timers = item:value() == "on"
		IH:Save()
	end
	MenuCallbackHandler.InstantHeists_GhostMode = function(self, item)
		IH.settings.ghost_mode = item:value() == "on"
		IH:Save()
		if managers and managers.chat and managers.chat._receive_message then
			local msg = IH.settings.ghost_mode
				and "Ghost Mode ON — AI/cameras cannot detect you"
				or "Ghost Mode OFF — normal detection"
			managers.chat:_receive_message(
				(ChatManager and ChatManager.GAME) or 1,
				"[Instant Heists]",
				msg,
				Color(0.5, 1, 0.6)
			)
		end
	end
	MenuCallbackHandler.InstantHeists_Save = function(self)
		IH:Save()
	end

	MenuHelper:LoadFromJsonFile(IH._path .. "options.txt", IH, IH.settings)
end)
