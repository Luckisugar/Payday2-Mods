-- Omniscience+ v3.2.3 — hard-stop sensing the INSTANT leave/menu starts
_G.OmnisciencePlus = _G.OmnisciencePlus or {}

local function hard_suspend(why)
	OmnisciencePlus._suspended = true
	if type(OmnisciencePlus.Suspend) == "function" then
		pcall(function()
			OmnisciencePlus:Suspend()
		end)
	end
	-- no disk/log here — unload path must stay light
end

local function hard_resume()
	OmnisciencePlus._suspended = false
	if type(OmnisciencePlus.Resume) == "function" then
		pcall(function()
			OmnisciencePlus:Resume()
		end)
	end
end

-- Broad set of leave/menu hooks (PreHook = before teardown work)
local function try_hook(class_tbl, method, id)
	if not class_tbl or not class_tbl[method] then
		return
	end
	pcall(function()
		Hooks:PreHook(class_tbl, method, id, function()
			hard_suspend(id)
		end)
	end)
end

if Setup then
	try_hook(Setup, "load_start_menu", "OmnisciencePlus_Setup_LoadMenu")
	try_hook(Setup, "quit", "OmnisciencePlus_Setup_Quit")
end

if GameSetup then
	try_hook(GameSetup, "load_start_menu", "OmnisciencePlus_Game_LoadMenu")
	try_hook(GameSetup, "destroy", "OmnisciencePlus_Game_Destroy")
	try_hook(GameSetup, "stop_game", "OmnisciencePlus_Game_Stop")
end

if MenuCallbackHandler then
	try_hook(MenuCallbackHandler, "load_start_menu", "OmnisciencePlus_CB_LoadMenu")
	try_hook(MenuCallbackHandler, "disconnect_from_game", "OmnisciencePlus_CB_Disconnect")
	try_hook(MenuCallbackHandler, "_dialog_end_game_yes", "OmnisciencePlus_CB_EndGame")
	try_hook(MenuCallbackHandler, "end_game", "OmnisciencePlus_CB_EndGame2")
end

-- Resume only when actually spawning into a heist
pcall(function()
	if PlayerManager then
		Hooks:PostHook(PlayerManager, "spawned_player", "OmnisciencePlus_Spawned323", function()
			hard_resume()
		end)
	end
end)
