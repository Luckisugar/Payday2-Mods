_G.SawStealthConceal = _G.SawStealthConceal or {}
local SSC = SawStealthConceal

SSC._path = SSC._path or ModPath
SSC._data_path = SSC._data_path or (SavePath .. "saw_stealth_conceal.txt")

if not SSC.DefaultSettings then
	-- menu can load after core; core defines these. Soft defaults if order flips.
	function SSC:DefaultSettings()
		return { enabled = true, concealment = 30 }
	end
end

if not SSC.Load then
	function SSC:Load()
		self.settings = self:DefaultSettings()
	end
end

if not SSC.Save then
	function SSC:Save() end
end

SSC:Load()

Hooks:Add("LocalizationManagerPostInit", "SawStealthConceal_loc", function(loc)
	loc:add_localized_strings({
		saw_stealth_conceal_menu_title = "Saw Stealth Conceal",
		saw_stealth_conceal_menu_desc = "OVE9000 Saw concealment for stealth (higher = better detection).",
		saw_stealth_conceal_enabled = "Enabled",
		saw_stealth_conceal_enabled_desc = "Override saw concealment.",
		saw_stealth_conceal_value = "Saw concealment",
		saw_stealth_conceal_value_desc = "Vanilla saw is very low. 30 = max stealth-friendly. Restart or re-equip after change.",
	})
end)

local function rebuild_menu()
	-- NewMenu clones BLT's template; that template does not exist until menu setup
	if not MenuHelper.menu_to_clone then
		return
	end
	local menu_id = "saw_stealth_conceal_menu"
	MenuHelper:NewMenu(menu_id)

	MenuHelper:AddToggle({
		id = "ssc_enabled",
		title = "saw_stealth_conceal_enabled",
		desc = "saw_stealth_conceal_enabled_desc",
		callback = "ssc_toggle_enabled",
		value = SSC.settings.enabled,
		menu_id = menu_id,
		priority = 100,
	})

	MenuHelper:AddSlider({
		id = "ssc_concealment",
		title = "saw_stealth_conceal_value",
		desc = "saw_stealth_conceal_value_desc",
		callback = "ssc_set_concealment",
		value = SSC.settings.concealment or 30,
		min = 1,
		max = 30,
		step = 1,
		show_value = true,
		menu_id = menu_id,
		priority = 90,
	})

	Hooks:Add("MenuManagerBuildCustomMenus", "SawStealthConceal_build", function(menu_manager, nodes)
		nodes[menu_id] = MenuHelper:BuildMenu(menu_id)
		if HeistHelper and HeistHelper.AttachMenuItem then
			HeistHelper.AttachMenuItem(nodes, menu_id, "saw_stealth_conceal_menu_title", "saw_stealth_conceal_menu_desc")
		else
			MenuHelper:AddMenuItem(nodes.blt_options, menu_id, "saw_stealth_conceal_menu_title", "saw_stealth_conceal_menu_desc")
		end
	end)
end

MenuCallbackHandler.ssc_toggle_enabled = function(self, item)
	SSC.settings.enabled = item:value() == "on"
	SSC:Save()
	if SSC.Apply then
		SSC:Apply()
	end
end

MenuCallbackHandler.ssc_set_concealment = function(self, item)
	SSC.settings.concealment = math.floor(tonumber(item:value()) or 30)
	SSC:Save()
	if SSC.Apply then
		SSC:Apply()
	end
end

Hooks:Add("MenuManagerSetupCustomMenus", "SawStealthConceal_setup", function()
	rebuild_menu()
end)
