--[[ Auto-start + rebuy when back in IngameWaitingForPlayers ]]

if not _G.InstantRestart or not InstantRestart.try_auto_start then
	dofile(ModPath .. "core.lua")
end

local IR = InstantRestart

Hooks:PostHook(IngameWaitingForPlayersState, "at_enter", "InstantRestart_WaitingEnter", function(self, ...)
	pcall(function()
		IR:log("hook_waiting_at_enter")
		IR:refresh_pending_from_disk()
		IR:log_snapshot("waiting_at_enter")
		if IR.pending_auto_start then
			-- Early rebuy attempt once mission elements exist
			IR:try_rebuy_preplan()
			IR:try_auto_start("waiting_at_enter")
		end
	end)
end)

Hooks:PostHook(IngameWaitingForPlayersState, "update", "InstantRestart_WaitingUpdate", function(self, t, dt, ...)
	pcall(function()
		if IR.pending_auto_start or IR:read_pending_flag() then
			IR:try_auto_start("waiting_update")
		end
	end)
end)

if IngameWaitingForPlayersState and IngameWaitingForPlayersState.start_game_intro then
	Hooks:PostHook(IngameWaitingForPlayersState, "start_game_intro", "InstantRestart_StartIntroLog", function(self, ...)
		pcall(function()
			IR:log("hook_start_game_intro_called")
		end)
	end)
end
