--[[ Briefing GUI hooks: rebuy + auto-start backup ]]

if not _G.InstantRestart or not InstantRestart.try_auto_start then
	dofile(ModPath .. "core.lua")
end

local IR = InstantRestart

if MissionBriefingGui then
	Hooks:PostHook(MissionBriefingGui, "init", "InstantRestart_BriefingInit", function(self, ...)
		pcall(function()
			IR:log("hook_briefing_init")
			IR:refresh_pending_from_disk()
			IR:log_snapshot("briefing_init")
			if IR.pending_auto_start then
				IR:try_rebuy_preplan()
				IR:try_auto_start("briefing_init")
			end
		end)
	end)

	Hooks:PostHook(MissionBriefingGui, "update", "InstantRestart_BriefingUpdate", function(self, t, ...)
		pcall(function()
			if IR.pending_auto_start or IR:read_pending_flag() then
				IR:try_auto_start("briefing_update")
			end
		end)
	end)

	Hooks:PostHook(MissionBriefingGui, "on_ready_pressed", "InstantRestart_ReadyPressedLog", function(self, ...)
		pcall(function()
			IR:log("hook_briefing_ready_pressed", { ready = self._ready })
		end)
	end)
end

-- Preplanning map open = good moment to rebuy (same window as stock rebuy reminder)
if PrePlanningManager then
	Hooks:PostHook(PrePlanningManager, "on_preplanning_open", "InstantRestart_PreplanOpen", function(self, ...)
		pcall(function()
			IR:log("hook_preplan_open")
			IR:refresh_pending_from_disk()
			if IR.pending_auto_start then
				IR:try_rebuy_preplan()
			end
		end)
	end)
end

-- Mission assets table ready (Buy All / individual unlocks)
if MissionAssetsManager then
	Hooks:PostHook(MissionAssetsManager, "init_finalize", "InstantRestart_AssetsReady", function(self, ...)
		pcall(function()
			IR:log("hook_assets_init_finalize")
			IR:refresh_pending_from_disk()
			if IR.pending_auto_start and not IR.rebuy_done then
				IR:try_rebuy_preplan()
				IR:try_auto_start("assets_init_finalize")
			end
		end)
	end)

	Hooks:PostHook(MissionAssetsManager, "create_asset_textures", "InstantRestart_AssetTextures", function(self, ...)
		pcall(function()
			if IR.pending_auto_start and not IR.rebuy_done then
				IR:try_rebuy_preplan()
			end
		end)
	end)
end
