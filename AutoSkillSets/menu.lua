--[[
	Auto Skill Sets — BLT Mod Options menu

	Visibility pattern matches DynamicSuspicionIndicators:
	item._visible_callback_name_list + gui_node:refresh_gui on toggle.
]]

_G.AutoSkillSets = _G.AutoSkillSets or {}
local ASS = AutoSkillSets

ASS._path = ASS._path or ModPath
ASS._data_path = ASS._data_path or (SavePath .. "auto_skill_sets.txt")

if not ASS.Load then
	function ASS:DefaultSettings()
		return {
			enabled = true,
			auto_spend = true,
			infamy_prompt = true,
			block_mid_heist = true,
			edit_cheat = false,
			active_slot = 1,
			cheat_level = 100,
			cheat_infamy = 0,
			cheat_skill_points = 120,
			builds = {}
		}
	end
	function ASS:Load()
		self.settings = self:DefaultSettings()
	end
	function ASS:Save() end
	function ASS:SystemMsg(msg)
		if log then log("[Auto Skill Sets] " .. tostring(msg)) end
	end
end

if not ASS.settings then
	ASS:Load()
end

-- Core may load after menumanager on some boot orders; pull it in so InstallHooks runs.
if not ASS.InstallHooks then
	local core = (ASS._path or ModPath) .. "core.lua"
	local ok, err = pcall(dofile, core)
	if not ok and log then
		log("[Auto Skill Sets] failed to load core.lua: " .. tostring(err))
	end
end
if ASS.InstallHooks then
	ASS:InstallHooks()
end

Hooks:Add("LocalizationManagerPostInit", "AutoSkillSets_loc", function(loc)
	loc:load_localization_file(ASS._path .. "loc/english.txt")
end)

Hooks:Add("MenuManagerInitialize", "AutoSkillSets_MenuInit_hooks", function(menu_manager)
	if ASS.InstallHooks then
		ASS:InstallHooks()
	end
end)

local MENU_ID = "auto_skill_sets_menu"

-- Same technique as DynamicSuspicionIndicators menu/builder.lua
local function set_visible_when(item, callback_name)
	if item then
		item._visible_callback_name_list = { callback_name }
	end
	return item
end

Hooks:Add("MenuManagerSetupCustomMenus", "AutoSkillSets_setup", function(menu_manager, nodes)
	MenuHelper:NewMenu(MENU_ID)
end)

Hooks:Add("MenuManagerPopulateCustomMenus", "AutoSkillSets_populate", function(menu_manager, nodes)
	if not ASS.settings then
		ASS:Load()
	end

	-- Visibility predicate (Edit (Cheat) must be on)
	MenuCallbackHandler.ass_edit_cheat_visible = function()
		return ASS.settings and ASS.settings.edit_cheat == true
	end

	-- Refresh row list after a parent toggle (DSI: dp_update_visibility)
	MenuCallbackHandler.ass_update_visibility = function(_, item)
		local gui_node = item and item.parameters and item:parameters().gui_node
		if gui_node and gui_node.refresh_gui then
			gui_node:refresh_gui(gui_node.node)
			if gui_node.highlight_item then
				gui_node:highlight_item(item, true)
			end
		end
	end

	MenuCallbackHandler.ass_toggle_enabled = function(self, item)
		ASS.settings.enabled = item:value() == "on"
		ASS:Save()
	end

	MenuCallbackHandler.ass_toggle_auto_spend = function(self, item)
		ASS.settings.auto_spend = item:value() == "on"
		ASS:Save()
	end

	MenuCallbackHandler.ass_toggle_infamy_prompt = function(self, item)
		ASS.settings.infamy_prompt = item:value() == "on"
		ASS:Save()
	end

	MenuCallbackHandler.ass_toggle_block_heist = function(self, item)
		ASS.settings.block_mid_heist = item:value() == "on"
		ASS:Save()
	end

	MenuCallbackHandler.ass_set_slot = function(self, item)
		local idx = math.floor(tonumber(item:value()) or 1)
		ASS.settings.active_slot = math.max(1, math.min(ASS.SLOT_COUNT or 8, idx))
		ASS:Save()
	end

	MenuCallbackHandler.ass_save_current = function(self, item)
		if ASS.SaveCurrentIntoActive then
			ASS:SaveCurrentIntoActive()
		else
			ASS:SystemMsg("Core not loaded yet — open a heist lobby once, then retry.")
		end
	end

	MenuCallbackHandler.ass_apply = function(self, item)
		if ASS.TryApply then
			ASS:TryApply(false, "manual")
		end
	end

	MenuCallbackHandler.ass_apply_cheat = function(self, item)
		if not (ASS.settings and ASS.settings.edit_cheat) then
			return
		end
		if ASS.TryApply then
			ASS:TryApply(true, "manual")
		end
	end

	MenuCallbackHandler.ass_diff = function(self, item)
		if ASS.DiffActive then
			ASS:DiffActive()
		end
	end

	MenuCallbackHandler.ass_delete = function(self, item)
		if ASS.DeleteActive then
			ASS:DeleteActive()
		end
	end

	-- Space-separated callbacks: BLT runs both (same as DSI parent toggles)
	MenuCallbackHandler.ass_toggle_edit_cheat = function(self, item)
		ASS.settings.edit_cheat = item:value() == "on"
		ASS:Save()
	end

	MenuCallbackHandler.ass_set_level = function(self, item)
		ASS.settings.cheat_level = math.floor(tonumber(item:value()) or 0)
		ASS:Save()
	end

	MenuCallbackHandler.ass_apply_level = function(self, item)
		if ASS.ApplyCheatLevel then
			ASS:ApplyCheatLevel()
		end
	end

	MenuCallbackHandler.ass_set_infamy = function(self, item)
		ASS.settings.cheat_infamy = math.floor(tonumber(item:value()) or 0)
		ASS:Save()
	end

	MenuCallbackHandler.ass_apply_infamy = function(self, item)
		if ASS.ApplyCheatInfamy then
			ASS:ApplyCheatInfamy()
		end
	end

	MenuCallbackHandler.ass_set_sp = function(self, item)
		ASS.settings.cheat_skill_points = math.floor(tonumber(item:value()) or 0)
		ASS:Save()
	end

	MenuCallbackHandler.ass_apply_sp = function(self, item)
		if ASS.ApplyCheatSkillPoints then
			ASS:ApplyCheatSkillPoints()
		end
	end

	-- ── Normal options ──────────────────────────────────────────────
	MenuHelper:AddToggle({
		id = "ass_enabled",
		title = "ass_enabled_title",
		desc = "ass_enabled_desc",
		callback = "ass_toggle_enabled",
		value = ASS.settings.enabled,
		menu_id = MENU_ID,
		priority = 200
	})

	MenuHelper:AddToggle({
		id = "ass_auto_spend",
		title = "ass_auto_spend_title",
		desc = "ass_auto_spend_desc",
		callback = "ass_toggle_auto_spend",
		value = ASS.settings.auto_spend,
		menu_id = MENU_ID,
		priority = 190
	})

	MenuHelper:AddToggle({
		id = "ass_infamy_prompt",
		title = "ass_infamy_prompt_title",
		desc = "ass_infamy_prompt_desc",
		callback = "ass_toggle_infamy_prompt",
		value = ASS.settings.infamy_prompt,
		menu_id = MENU_ID,
		priority = 180
	})

	MenuHelper:AddToggle({
		id = "ass_block_heist",
		title = "ass_block_heist_title",
		desc = "ass_block_heist_desc",
		callback = "ass_toggle_block_heist",
		value = ASS.settings.block_mid_heist,
		menu_id = MENU_ID,
		priority = 170
	})

	MenuHelper:AddDivider({
		id = "ass_div_builds",
		size = 12,
		no_text = true,
		menu_id = MENU_ID,
		priority = 160
	})

	MenuHelper:AddMultipleChoice({
		id = "ass_slot",
		title = "ass_slot_title",
		desc = "ass_slot_desc",
		callback = "ass_set_slot",
		items = {
			"ass_slot_1",
			"ass_slot_2",
			"ass_slot_3",
			"ass_slot_4",
			"ass_slot_5",
			"ass_slot_6",
			"ass_slot_7",
			"ass_slot_8"
		},
		value = ASS.settings.active_slot or 1,
		menu_id = MENU_ID,
		priority = 150
	})

	MenuHelper:AddButton({
		id = "ass_save",
		title = "ass_save_title",
		desc = "ass_save_desc",
		callback = "ass_save_current",
		menu_id = MENU_ID,
		priority = 140
	})

	MenuHelper:AddButton({
		id = "ass_apply",
		title = "ass_apply_title",
		desc = "ass_apply_desc",
		callback = "ass_apply",
		menu_id = MENU_ID,
		priority = 130
	})

	MenuHelper:AddButton({
		id = "ass_diff",
		title = "ass_diff_title",
		desc = "ass_diff_desc",
		callback = "ass_diff",
		menu_id = MENU_ID,
		priority = 120
	})

	MenuHelper:AddButton({
		id = "ass_delete",
		title = "ass_delete_title",
		desc = "ass_delete_desc",
		callback = "ass_delete",
		menu_id = MENU_ID,
		priority = 110
	})

	-- ── Edit (Cheat) ────────────────────────────────────────────────
	MenuHelper:AddDivider({
		id = "ass_div_before_edit",
		size = 18,
		no_text = true,
		menu_id = MENU_ID,
		priority = 100
	})

	MenuHelper:AddToggle({
		id = "ass_edit_cheat",
		title = "ass_edit_cheat_title",
		desc = "ass_edit_cheat_desc",
		-- both fire: save setting, then rebuild visible rows (DSI pattern)
		callback = "ass_toggle_edit_cheat ass_update_visibility",
		value = ASS.settings.edit_cheat,
		menu_id = MENU_ID,
		priority = 90
	})

	set_visible_when(MenuHelper:AddDivider({
		id = "ass_div_after_edit",
		size = 14,
		no_text = true,
		menu_id = MENU_ID,
		priority = 85
	}), "ass_edit_cheat_visible")

	set_visible_when(MenuHelper:AddButton({
		id = "ass_apply_cheat",
		title = "ass_apply_cheat_title",
		desc = "ass_apply_cheat_desc",
		callback = "ass_apply_cheat",
		menu_id = MENU_ID,
		priority = 80
	}), "ass_edit_cheat_visible")

	set_visible_when(MenuHelper:AddDivider({
		id = "ass_div_level",
		size = 16,
		no_text = true,
		menu_id = MENU_ID,
		priority = 75
	}), "ass_edit_cheat_visible")

	set_visible_when(MenuHelper:AddSlider({
		id = "ass_level",
		title = "ass_level_title",
		desc = "ass_level_desc",
		callback = "ass_set_level",
		value = ASS.settings.cheat_level or 100,
		min = 0,
		max = 100,
		step = 1,
		show_value = true,
		display_precision = 0,
		menu_id = MENU_ID,
		priority = 70
	}), "ass_edit_cheat_visible")

	set_visible_when(MenuHelper:AddButton({
		id = "ass_level_apply",
		title = "ass_level_apply_title",
		desc = "ass_level_apply_desc",
		callback = "ass_apply_level",
		menu_id = MENU_ID,
		priority = 65
	}), "ass_edit_cheat_visible")

	set_visible_when(MenuHelper:AddDivider({
		id = "ass_div_infamy",
		size = 16,
		no_text = true,
		menu_id = MENU_ID,
		priority = 60
	}), "ass_edit_cheat_visible")

	set_visible_when(MenuHelper:AddSlider({
		id = "ass_infamy",
		title = "ass_infamy_title",
		desc = "ass_infamy_desc",
		callback = "ass_set_infamy",
		value = ASS.settings.cheat_infamy or 0,
		min = 0,
		max = 500,
		step = 1,
		show_value = true,
		display_precision = 0,
		menu_id = MENU_ID,
		priority = 55
	}), "ass_edit_cheat_visible")

	set_visible_when(MenuHelper:AddButton({
		id = "ass_infamy_apply",
		title = "ass_infamy_apply_title",
		desc = "ass_infamy_apply_desc",
		callback = "ass_apply_infamy",
		menu_id = MENU_ID,
		priority = 50
	}), "ass_edit_cheat_visible")

	set_visible_when(MenuHelper:AddDivider({
		id = "ass_div_sp",
		size = 16,
		no_text = true,
		menu_id = MENU_ID,
		priority = 45
	}), "ass_edit_cheat_visible")

	set_visible_when(MenuHelper:AddSlider({
		id = "ass_sp",
		title = "ass_sp_title",
		desc = "ass_sp_desc",
		callback = "ass_set_sp",
		value = ASS.settings.cheat_skill_points or 120,
		min = 0,
		max = 500,
		step = 1,
		show_value = true,
		display_precision = 0,
		menu_id = MENU_ID,
		priority = 40
	}), "ass_edit_cheat_visible")

	set_visible_when(MenuHelper:AddButton({
		id = "ass_sp_apply",
		title = "ass_sp_apply_title",
		desc = "ass_sp_apply_desc",
		callback = "ass_apply_sp",
		menu_id = MENU_ID,
		priority = 35
	}), "ass_edit_cheat_visible")
end)

Hooks:Add("MenuManagerBuildCustomMenus", "AutoSkillSets_build", function(menu_manager, nodes)
	nodes[MENU_ID] = MenuHelper:BuildMenu(MENU_ID)
	MenuHelper:AddMenuItem(nodes.blt_options, MENU_ID, "ass_menu_title", "ass_menu_desc")
end)
