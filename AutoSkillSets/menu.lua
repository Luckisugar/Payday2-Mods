--[[
	Auto Skill Sets — BLT Mod Options menu
]]

_G.AutoSkillSets = _G.AutoSkillSets or {}
local ASS = AutoSkillSets

ASS._path = ASS._path or ModPath
ASS._data_path = ASS._data_path or (SavePath .. "auto_skill_sets.txt")

if not ASS.Load then
	-- core.lua not loaded yet (menu hook first); minimal stubs until core loads
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

Hooks:Add("LocalizationManagerPostInit", "AutoSkillSets_loc", function(loc)
	loc:load_localization_file(ASS._path .. "loc/english.txt")
end)

local MENU_ID = "auto_skill_sets_menu"

--- Hide cheat rows unless Edit (Cheat) is on (re-evaluated when the node refreshes).
local function mark_edit_cheat_only(item)
	if not item or not item._parameters then
		return item
	end
	item._parameters.visible_callback = "ass_edit_cheat_visible"
	return item
end

local function refresh_ass_menu()
	if not managers or not managers.menu then
		return
	end
	local active = managers.menu:active_menu()
	if active and active.logic and active.logic.refresh_node then
		pcall(function()
			active.logic:refresh_node()
		end)
	end
end

Hooks:Add("MenuManagerSetupCustomMenus", "AutoSkillSets_setup", function(menu_manager, nodes)
	MenuHelper:NewMenu(MENU_ID)
end)

Hooks:Add("MenuManagerPopulateCustomMenus", "AutoSkillSets_populate", function(menu_manager, nodes)
	if not ASS.settings then
		ASS:Load()
	end

	MenuCallbackHandler.ass_edit_cheat_visible = function(self, item)
		return ASS.settings and ASS.settings.edit_cheat == true
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
		if not ASS.settings.edit_cheat then
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

	MenuCallbackHandler.ass_toggle_edit_cheat = function(self, item)
		ASS.settings.edit_cheat = item:value() == "on"
		ASS:Save()
		refresh_ass_menu()
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

	-- ── Edit (Cheat) gate + gated controls ──────────────────────────
	MenuHelper:AddDivider({
		id = "ass_div_before_edit",
		size = 18,
		menu_id = MENU_ID,
		priority = 100
	})

	MenuHelper:AddToggle({
		id = "ass_edit_cheat",
		title = "ass_edit_cheat_title",
		desc = "ass_edit_cheat_desc",
		callback = "ass_toggle_edit_cheat",
		value = ASS.settings.edit_cheat,
		menu_id = MENU_ID,
		priority = 90
	})

	-- space after Edit toggle, then Restore Skills (cheat-only)
	mark_edit_cheat_only(MenuHelper:AddDivider({
		id = "ass_div_after_edit",
		size = 14,
		menu_id = MENU_ID,
		priority = 85
	}))

	mark_edit_cheat_only(MenuHelper:AddButton({
		id = "ass_apply_cheat",
		title = "ass_apply_cheat_title",
		desc = "ass_apply_cheat_desc",
		callback = "ass_apply_cheat",
		menu_id = MENU_ID,
		priority = 80
	}))

	-- Level section
	mark_edit_cheat_only(MenuHelper:AddDivider({
		id = "ass_div_level",
		size = 16,
		menu_id = MENU_ID,
		priority = 75
	}))

	mark_edit_cheat_only(MenuHelper:AddSlider({
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
	}))

	mark_edit_cheat_only(MenuHelper:AddButton({
		id = "ass_level_apply",
		title = "ass_level_apply_title",
		desc = "ass_level_apply_desc",
		callback = "ass_apply_level",
		menu_id = MENU_ID,
		priority = 65
	}))

	-- Infamy section
	mark_edit_cheat_only(MenuHelper:AddDivider({
		id = "ass_div_infamy",
		size = 16,
		menu_id = MENU_ID,
		priority = 60
	}))

	mark_edit_cheat_only(MenuHelper:AddSlider({
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
	}))

	mark_edit_cheat_only(MenuHelper:AddButton({
		id = "ass_infamy_apply",
		title = "ass_infamy_apply_title",
		desc = "ass_infamy_apply_desc",
		callback = "ass_apply_infamy",
		menu_id = MENU_ID,
		priority = 50
	}))

	-- Skill Points section
	mark_edit_cheat_only(MenuHelper:AddDivider({
		id = "ass_div_sp",
		size = 16,
		menu_id = MENU_ID,
		priority = 45
	}))

	mark_edit_cheat_only(MenuHelper:AddSlider({
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
	}))

	mark_edit_cheat_only(MenuHelper:AddButton({
		id = "ass_sp_apply",
		title = "ass_sp_apply_title",
		desc = "ass_sp_apply_desc",
		callback = "ass_apply_sp",
		menu_id = MENU_ID,
		priority = 35
	}))
end)

Hooks:Add("MenuManagerBuildCustomMenus", "AutoSkillSets_build", function(menu_manager, nodes)
	nodes[MENU_ID] = MenuHelper:BuildMenu(MENU_ID)
	MenuHelper:AddMenuItem(nodes.blt_options, MENU_ID, "ass_menu_title", "ass_menu_desc")
end)
