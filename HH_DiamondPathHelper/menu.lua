--[[ Diamond Path Helper — Heist Helper module ]]

_G.DiamondPathHelper = _G.DiamondPathHelper or {}
local DPH = DiamondPathHelper

DPH._path = ModPath
DPH._data_path = SavePath .. "diamond_path_helper.txt"
DPH.settings = DPH.settings or {}

function DPH:DefaultSettings()
	return {
		enabled = true,
		chat_mode = 1,
		show_grid = false,
		show_hint = true,
	}
end

function DPH:Load()
	self.settings = self:DefaultSettings()
	local file = io.open(self._data_path, "r")
	if file then
		local ok, data = pcall(json.decode, file:read("*all"))
		file:close()
		if ok and type(data) == "table" then
			for k, v in pairs(data) do
				if self.settings[k] ~= nil or k == "enabled" or k == "chat_mode" or k == "show_grid" or k == "show_hint" then
					self.settings[k] = v
				end
			end
		end
	else
		-- one-shot migrate from combined heist_helper.txt
		local old = io.open(SavePath .. "heist_helper.txt", "r")
		if old then
			local ok, data = pcall(json.decode, old:read("*all"))
			old:close()
			if ok and type(data) == "table" then
				for _, k in ipairs({ "enabled", "chat_mode", "show_grid", "show_hint" }) do
					if data[k] ~= nil then
						self.settings[k] = data[k]
					end
				end
			end
		end
	end
end

function DPH:Save()
	local keep = self:DefaultSettings()
	for k, v in pairs(self.settings) do
		if keep[k] ~= nil then
			keep[k] = v
		end
	end
	self.settings = keep
	local file = io.open(self._data_path, "w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

DPH:Load()

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_DiamondPathHelper", function(loc)
	loc:load_localization_file(DPH._path .. "loc/english.txt")
end)

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_DiamondPathHelper", function(menu_manager)
	MenuCallbackHandler.hh_diamond_enabled = function(self, item)
		DPH.settings.enabled = item:value() == "on"
		DPH:Save()
	end
	MenuCallbackHandler.hh_chat_mode = function(self, item)
		DPH.settings.chat_mode = item:value()
		DPH:Save()
	end
	MenuCallbackHandler.hh_show_grid = function(self, item)
		DPH.settings.show_grid = item:value() == "on"
		DPH:Save()
	end
	MenuCallbackHandler.hh_show_hint = function(self, item)
		DPH.settings.show_hint = item:value() == "on"
		DPH:Save()
	end
	MenuCallbackHandler.dph_enabled = MenuCallbackHandler.hh_diamond_enabled
	MenuCallbackHandler.dph_chat_mode = MenuCallbackHandler.hh_chat_mode
	MenuCallbackHandler.dph_show_grid = MenuCallbackHandler.hh_show_grid
	MenuCallbackHandler.dph_show_hint = MenuCallbackHandler.hh_show_hint
	MenuHelper:LoadFromJsonFile(DPH._path .. "options.txt", DPH, DPH.settings)
end)
