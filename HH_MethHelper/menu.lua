--[[ Meth Helper — Heist Helper module ]]

_G.MethHelper = _G.MethHelper or {}
_G.HeistHelper = _G.HeistHelper or {}
local MH = MethHelper

MH._path = ModPath
MH._data_path = SavePath .. "meth_helper.txt"
MH.settings = MH.settings or {}

function MH:DefaultSettings()
	return {
		meth_enabled = true,
		meth_ingred_chatmode = 1,
		meth_ingred_hintmode = true,
		meth_ingred_repeat = false,
		meth_added_chatmode = 1,
		meth_added_hintmode = false,
		meth_done_chatmode = 1,
		meth_done_hintmode = false,
		meth_fail_chatmode = 3,
		meth_fail_hintmode = true,
		meth_message_allcaps = false,
	}
end

function MH:Load()
	self.settings = self:DefaultSettings()
	local file = io.open(self._data_path, "r")
	if file then
		local ok, data = pcall(json.decode, file:read("*all"))
		file:close()
		if ok and type(data) == "table" then
			for k, v in pairs(data) do
				self.settings[k] = v
			end
		end
		return
	end
	local function merge(path, map)
		local f = io.open(path, "r")
		if not f then
			return
		end
		local ok, data = pcall(json.decode, f:read("*all"))
		f:close()
		if not ok or type(data) ~= "table" then
			return
		end
		if map then
			for src, dst in pairs(map) do
				if data[src] ~= nil then
					self.settings[dst] = data[src]
				end
			end
		else
			for k, v in pairs(data) do
				if self.settings[k] ~= nil then
					self.settings[k] = v
				end
			end
		end
	end
	merge(SavePath .. "heist_helper.txt")
	merge(SavePath .. "methhelperupdated.txt", {
		enabled = "meth_enabled",
		ingred_chatmode = "meth_ingred_chatmode",
		ingred_hintmode = "meth_ingred_hintmode",
		ingred_repeat = "meth_ingred_repeat",
		added_chatmode = "meth_added_chatmode",
		added_hintmode = "meth_added_hintmode",
		done_chatmode = "meth_done_chatmode",
		done_hintmode = "meth_done_hintmode",
		fail_chatmode = "meth_fail_chatmode",
		fail_hintmode = "meth_fail_hintmode",
		message_allcaps = "meth_message_allcaps",
	})
end

function MH:Save()
	local file = io.open(self._data_path, "w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

function MH:IsMethEnabled()
	return self.settings and self.settings.meth_enabled ~= false
end

function MH:ToggleMeth(enabled)
	if enabled == nil then
		self.settings.meth_enabled = not self:IsMethEnabled()
	else
		self.settings.meth_enabled = enabled and true or false
	end
	return self:IsMethEnabled()
end

function MH:MethOutputType(kind)
	local chatmode = self.settings["meth_" .. kind .. "_chatmode"] or 3
	local hintmode = self.settings["meth_" .. kind .. "_hintmode"] or false
	return chatmode, hintmode
end

-- meth.lua still talks to HeistHelper if present
HeistHelper.IsMethEnabled = function(self)
	return MH:IsMethEnabled()
end
HeistHelper.ToggleMeth = function(self, enabled)
	return MH:ToggleMeth(enabled)
end
HeistHelper.MethOutputType = function(self, kind)
	return MH:MethOutputType(kind)
end
HeistHelper.settings = MH.settings

MH:Load()
HeistHelper.settings = MH.settings

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_MethHelper", function(loc)
	loc:load_localization_file(MH._path .. "loc/english.txt")
end)

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_MethHelper", function(menu_manager)
	MenuCallbackHandler.hh_meth_enabled = function(self, item)
		MH.settings.meth_enabled = item:value() == "on"
		MH:Save()
	end
	MenuCallbackHandler.hh_meth_allcaps = function(self, item)
		MH.settings.meth_message_allcaps = item:value() == "on"
		MH:Save()
	end
	MenuCallbackHandler.hh_meth_ingred_repeat = function(self, item)
		MH.settings.meth_ingred_repeat = item:value() == "on"
		MH:Save()
	end
	MenuCallbackHandler.hh_meth_ingred_chat = function(self, item)
		MH.settings.meth_ingred_chatmode = tonumber(item:value())
		MH:Save()
	end
	MenuCallbackHandler.hh_meth_ingred_hint = function(self, item)
		MH.settings.meth_ingred_hintmode = item:value() == "on"
		MH:Save()
	end
	MenuCallbackHandler.hh_meth_added_chat = function(self, item)
		MH.settings.meth_added_chatmode = tonumber(item:value())
		MH:Save()
	end
	MenuCallbackHandler.hh_meth_added_hint = function(self, item)
		MH.settings.meth_added_hintmode = item:value() == "on"
		MH:Save()
	end
	MenuCallbackHandler.hh_meth_done_chat = function(self, item)
		MH.settings.meth_done_chatmode = tonumber(item:value())
		MH:Save()
	end
	MenuCallbackHandler.hh_meth_done_hint = function(self, item)
		MH.settings.meth_done_hintmode = item:value() == "on"
		MH:Save()
	end
	MenuCallbackHandler.hh_meth_fail_chat = function(self, item)
		MH.settings.meth_fail_chatmode = tonumber(item:value())
		MH:Save()
	end
	MenuCallbackHandler.hh_meth_fail_hint = function(self, item)
		MH.settings.meth_fail_hintmode = item:value() == "on"
		MH:Save()
	end
	MenuHelper:LoadFromJsonFile(MH._path .. "options.txt", MH, MH.settings)
end)
