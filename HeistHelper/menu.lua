--[[
	Heist Helper core — options hub only.
	Gameplay lives in sibling HH_* mods that parent to heist_helper_menu.
]]

_G.HeistHelper = _G.HeistHelper or {}
local HH = HeistHelper

HH.HUB_MENU_ID = "heist_helper_menu"
HH._path = ModPath
HH._version = "3.0.0"

--- Attach a custom-built menu to the hub (fallback: BLT options).
function HeistHelper.AttachMenuItem(nodes, menu_id, title, desc)
	local parent = nodes and (nodes.heist_helper_menu or nodes.blt_options)
	if parent then
		MenuHelper:AddMenuItem(parent, menu_id, title, desc)
	end
end

function HeistHelper.ParentMenuId()
	return "heist_helper_menu"
end

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_HeistHelper", function(loc)
	loc:load_localization_file(HH._path .. "loc/english.txt")
end)

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_HeistHelper", function(menu_manager)
	MenuHelper:LoadFromJsonFile(HH._path .. "options.txt", HH, {})
end)
