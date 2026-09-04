-- Omniscience+ v3.3.3 — hard-stop sensing the INSTANT leave/menu/restart starts
_G.OmnisciencePlus = _G.OmnisciencePlus or {}

local function hard_suspend(why)
	OmnisciencePlus._suspended = true
	OmnisciencePlus._quest_next_t = 0
	OmnisciencePlus._box_units = {}
	OmnisciencePlus._box_ever_active = {}
	OmnisciencePlus._box_done = {}
	if type(OmnisciencePlus.Suspend) == "function" then
		pcall(function()
			OmnisciencePlus:Suspend()
		end)
	end
	if type(OmnisciencePlus.ClearQuestWaypoints) == "function" then
		pcall(function()
			OmnisciencePlus:ClearQuestWaypoints()
		end)
	end
	-- no disk/log here — unload path must stay light
end

local function hard_resume()
	OmnisciencePlus._suspended = false
	OmnisciencePlus._quest_next_t = 0
	OmnisciencePlus._box_units = OmnisciencePlus._box_units or {}
	OmnisciencePlus._box_ever_active = OmnisciencePlus._box_ever_active or {}
	OmnisciencePlus._box_done = OmnisciencePlus._box_done or {}
	if type(OmnisciencePlus.Resume) == "function" then
		pcall(function()
			OmnisciencePlus:Resume()
		end)
	end
end

-- Broad set of leave/menu/restart hooks (PreHook = before teardown work)
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

if NetworkGameSetup then
	try_hook(NetworkGameSetup, "destroy", "OmnisciencePlus_NetGame_Destroy")
	try_hook(NetworkGameSetup, "load_start_menu", "OmnisciencePlus_NetGame_LoadMenu")
end

if MenuCallbackHandler then
	try_hook(MenuCallbackHandler, "load_start_menu", "OmnisciencePlus_CB_LoadMenu")
	try_hook(MenuCallbackHandler, "disconnect_from_game", "OmnisciencePlus_CB_Disconnect")
	try_hook(MenuCallbackHandler, "_dialog_end_game_yes", "OmnisciencePlus_CB_EndGame")
	try_hook(MenuCallbackHandler, "end_game", "OmnisciencePlus_CB_EndGame2")
	-- Heist restart paths (your 05:58 crash timing)
	try_hook(MenuCallbackHandler, "restart_game", "OmnisciencePlus_CB_Restart")
	try_hook(MenuCallbackHandler, "restart_to_lobby", "OmnisciencePlus_CB_RestartLobby")
	try_hook(MenuCallbackHandler, "load_start_menu_lobby", "OmnisciencePlus_CB_Lobby")
	try_hook(MenuCallbackHandler, "_dialog_restart_yes", "OmnisciencePlus_CB_RestartYes")
	try_hook(MenuCallbackHandler, "_dialog_restart_accept", "OmnisciencePlus_CB_RestartAccept")
end

-- Resume only when actually spawning into a heist
pcall(function()
	if PlayerManager then
		Hooks:PostHook(PlayerManager, "spawned_player", "OmnisciencePlus_Spawned332", function()
			hard_resume()
		end)
	end
end)

-- Extra: clear waypoints if HUD is torn down mid-session
pcall(function()
	if HUDManager then
		Hooks:PreHook(HUDManager, "destroy", "OmnisciencePlus_HUD_Destroy", function()
			hard_suspend("HUD_destroy")
		end)
	end
end)
