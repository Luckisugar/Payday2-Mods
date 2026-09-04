--[[
	Ninja — Heist Helper submenu.
	Do not use options.txt parent_menu_id: SuperBLT can Build this node
	before heist_helper_menu exists (log: parent is null, ignoring).
]]

_G.SilentAssassin = _G.SilentAssassin or {}
local SA = SilentAssassin

SA._path = SA._path or ModPath
SA._loc_path = SA._loc_path or (ModPath .. "loc/")
SA._data_path = SA._data_path or (SavePath .. "silentassassin.txt")
SA.settings = SA.settings or {}
SA._hh_menu = true

if not SA.Load then
	pcall(dofile, (SA._path or ModPath) .. "SilentAssassin.lua")
end

local MENU_ID = "silent_assassin_options"

local function load_loc(loc)
	loc:add_localized_strings({
		silent_assassin_title = "Ninja",
		silent_assassin_desc = "Pager-free stealth kills. Only My Kills / Only While Crouching.",
	})
	local path = (SA._loc_path or (ModPath .. "loc/")) .. "english.json"
	if io.file_is_readable and io.file_is_readable(path) then
		pcall(function()
			loc:load_localization_file(path)
		end)
	end
end

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_SilentAssassin_HH", load_loc)

local function settings()
	if SA.Load and (not SA.settings or SA.settings.enabled == nil) then
		pcall(function()
			SA:Load()
		end)
	end
	return SA.settings or {}
end

local function on_off(v)
	if v == true or v == "on" then
		return true
	end
	return false
end

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_SilentAssassin_HH", function()
	MenuCallbackHandler.SilentAssassin_setNumPagers = setNumPagers
	MenuCallbackHandler.SilentAssassin_setNumPagersPerPlayer = setNumPagersPerPlayer
	MenuCallbackHandler.SilentAssassin_enabledToggle = setEnabled
	MenuCallbackHandler.SilentAssassin_killPagerEnabledToggle = setStealthKillEnabled
	MenuCallbackHandler.SilentAssassin_enablePagerBonusToggle = setEnablePagerBonusToggle
	MenuCallbackHandler.SilentAssassin_setPagerDetectionThreshold = setPagerDetectionThreshold
	MenuCallbackHandler.SilentAssassin_localKillsOnlyToggle = setLocalKillsOnly
	MenuCallbackHandler.SilentAssassin_crouchOnlyToggle = setCrouchOnly
	MenuCallbackHandler.SilentAssassin_Close = function()
		if SA.Save then
			SA:Save()
		end
	end
end)

Hooks:Add("MenuManagerSetupCustomMenus", "SilentAssassin_HH_setup", function()
	MenuHelper:NewMenu(MENU_ID)
end)

Hooks:Add("MenuManagerPopulateCustomMenus", "SilentAssassin_HH_populate", function()
	local s = settings()
	local function tog(id, title, desc, cb, key, default, prio)
		MenuHelper:AddToggle({
			id = id,
			title = title,
			desc = desc,
			callback = cb,
			value = on_off(s[key] ~= nil and s[key] or default),
			menu_id = MENU_ID,
			priority = prio,
		})
	end

	tog("sa_enabled", "sa_enabled_title", "sa_enabled_desc", "SilentAssassin_enabledToggle", "enabled", true, 100)
	tog("sa_kill_pager_enabled", "sa_kill_pager_enabled_title", "sa_kill_pager_enabled_desc", "SilentAssassin_killPagerEnabledToggle", "stealth_kill_enabled", true, 90)
	tog("sa_local_kills_only", "sa_local_kills_only_title", "sa_local_kills_only_desc", "SilentAssassin_localKillsOnlyToggle", "local_kills_only", true, 80)
	tog("sa_crouch_only", "sa_crouch_only_title", "sa_crouch_only_desc", "SilentAssassin_crouchOnlyToggle", "crouch_only", true, 70)

	MenuHelper:AddSlider({
		id = "sa_pager_detection_threshold",
		title = "sa_pager_detection_threshold_title",
		desc = "sa_pager_detection_threshold_desc",
		callback = "SilentAssassin_setPagerDetectionThreshold",
		value = tonumber(s.pager_detection_threshold) or 1,
		min = 0,
		max = 100,
		step = 1,
		show_value = true,
		menu_id = MENU_ID,
		priority = 60,
	})

	local pager_items = {}
	for i = 0, 20 do
		pager_items[#pager_items + 1] = "sa_pagers_" .. tostring(i)
	end

	MenuHelper:AddMultipleChoice({
		id = "sa_menu_num_pagers",
		title = "sa_num_pagers",
		desc = "sa_num_pagers_desc",
		callback = "SilentAssassin_setNumPagers",
		items = pager_items,
		value = (tonumber(s.num_pagers) or 12) + 1,
		menu_id = MENU_ID,
		priority = 50,
	})

	MenuHelper:AddMultipleChoice({
		id = "sa_menu_num_pagers_per_player",
		title = "sa_num_pagers_per_player",
		desc = "sa_num_pagers_per_player_desc",
		callback = "SilentAssassin_setNumPagersPerPlayer",
		items = pager_items,
		value = (tonumber(s.num_pagers_per_player) or 3) + 1,
		menu_id = MENU_ID,
		priority = 40,
	})
end)

local function already_linked(parent, menu_id)
	if not parent or not parent._items then
		return false
	end
	for _, item in pairs(parent._items) do
		if item._parameters and item._parameters.name == menu_id then
			return true
		end
	end
	return false
end

local function attach_to_hub(nodes)
	if not nodes or not nodes[MENU_ID] then
		return false
	end
	local parent = nodes.heist_helper_menu
	if not parent then
		return false
	end
	if already_linked(parent, MENU_ID) then
		return true
	end
	MenuHelper:AddMenuItem(parent, MENU_ID, "silent_assassin_title", "silent_assassin_desc")
	return true
end

Hooks:Add("MenuManagerBuildCustomMenus", "SilentAssassin_HH_build", function(menu_manager, nodes)
	nodes[MENU_ID] = MenuHelper:BuildMenu(MENU_ID, { back_callback = "SilentAssassin_Close" })
	if attach_to_hub(nodes) then
		return
	end
	-- Hub node not ready yet — retry a few times. Never parent to blt_options
	-- (that put two Ninja buttons on the main Mod Options list).
	if DelayedCalls then
		local tries = 0
		local function retry()
			tries = tries + 1
			if attach_to_hub(nodes) or tries >= 20 then
				return
			end
			DelayedCalls:Add("SilentAssassin_HH_reattach", 0.05, retry)
		end
		DelayedCalls:Add("SilentAssassin_HH_reattach", 0.05, retry)
	end
end)
