--[[ Instant Restart — Mod Options ]]

_G.InstantRestart = _G.InstantRestart or {}
local IR = InstantRestart

IR._path = IR._path or ModPath
IR._data_path = IR._data_path or (SavePath .. "instant_restart.txt")

if not IR.Load then
	dofile((IR._path or ModPath) .. "core.lua")
end

if not IR.settings then
	IR:Load()
end

Hooks:Add("LocalizationManagerPostInit", "InstantRestart_loc", function(loc)
	loc:load_localization_file(IR._path .. "loc/english.txt")
end)

Hooks:Add("MenuManagerInitialize", "InstantRestart_MenuInit", function(menu_manager)
	MenuCallbackHandler.InstantRestart_Enabled = function(self, item)
		IR.settings.enabled = item:value() == "on"
		IR:Save()
	end
	MenuCallbackHandler.InstantRestart_AutoStart = function(self, item)
		IR.settings.auto_start = item:value() == "on"
		IR:Save()
	end
	MenuCallbackHandler.InstantRestart_Confirm = function(self, item)
		IR.settings.require_confirm = item:value() == "on"
		IR:Save()
	end
	MenuCallbackHandler.InstantRestart_StartDelay = function(self, item)
		IR.settings.start_delay = math.floor((item:value() * 10) + 0.5) / 10
		IR:Save()
	end
	MenuCallbackHandler.InstantRestart_Rebuy = function(self, item)
		IR.settings.rebuy_preplan = item:value() == "on"
		IR:Save()
	end
	MenuCallbackHandler.InstantRestart_SystemChat = function(self, item)
		IR.settings.system_chat = item:value() == "on"
		IR:Save()
	end
	MenuCallbackHandler.InstantRestart_NetChat = function(self, item)
		IR.settings.network_system_chat = item:value() == "on"
		IR:Save()
	end
	MenuCallbackHandler.InstantRestart_SafePeers = function(self, item)
		IR.settings.safe_peer_checks = item:value() == "on"
		IR:Save()
	end
	MenuCallbackHandler.InstantRestart_DebugLog = function(self, item)
		IR.settings.debug_log = item:value() == "on"
		IR._log_enabled = IR.settings.debug_log
		IR:Save()
	end
	MenuCallbackHandler.InstantRestart_ClearLog = function(self, item)
		if IR.log_clear then
			IR:log_clear()
		end
		if IR.system_message_local then
			IR:system_message_local("Instant Restart log cleared.")
		end
	end
	MenuCallbackHandler.InstantRestart_Save = function(self)
		IR:Save()
	end

	MenuHelper:LoadFromJsonFile(IR._path .. "options.txt", IR, IR.settings)
end)
