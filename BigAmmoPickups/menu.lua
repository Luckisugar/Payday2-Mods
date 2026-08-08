--[[
	Big Ammo Pickups — BLT options menu only.
	Core Apply/Load lives in ammo_pickup.lua (must load with weapontweakdata).
]]

_G.BigAmmoPickups = _G.BigAmmoPickups or {}
local BAP = BigAmmoPickups

BAP._path = ModPath
BAP._data_path = SavePath .. "big_ammo_pickups.txt"
BAP._originals = BAP._originals or {}
BAP.settings = BAP.settings or {}

-- If weapon hook hasn't defined methods yet (shouldn't happen mid-session), provide fallbacks.
if not BAP.DefaultSettings then
	function BAP:DefaultSettings()
		return {
			enabled = true,
			multiplier = 10,
			min_floor = 2,
			max_floor = 5,
			boost_zero_pickup = true,
			zero_pickup_min = 4,
			zero_pickup_max = 8,
			tactical_from_ammo = false,
		}
	end
end

if not BAP.Load then
	function BAP:Load()
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
		end
	end
end

if not BAP.Save then
	function BAP:Save()
		local file = io.open(self._data_path, "w+")
		if file then
			file:write(json.encode(self.settings))
			file:close()
		end
	end
end

if not BAP.settings.multiplier then
	BAP:Load()
end

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_BigAmmoPickups", function(loc)
	loc:load_localization_file(BAP._path .. "loc/english.txt")
end)

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_BigAmmoPickups", function(menu_manager)
	MenuCallbackHandler.BigAmmoPickups_Enabled = function(self, item)
		BAP.settings.enabled = item:value() == "on"
		if BAP.Apply then BAP:Apply() end
	end
	MenuCallbackHandler.BigAmmoPickups_Multiplier = function(self, item)
		BAP.settings.multiplier = math.floor(item:value() + 0.5)
		if BAP.Apply then BAP:Apply() end
	end
	MenuCallbackHandler.BigAmmoPickups_MinFloor = function(self, item)
		BAP.settings.min_floor = math.floor(item:value() + 0.5)
		if BAP.Apply then BAP:Apply() end
	end
	MenuCallbackHandler.BigAmmoPickups_MaxFloor = function(self, item)
		BAP.settings.max_floor = math.floor(item:value() + 0.5)
		if BAP.Apply then BAP:Apply() end
	end
	MenuCallbackHandler.BigAmmoPickups_BoostZero = function(self, item)
		BAP.settings.boost_zero_pickup = item:value() == "on"
		if BAP.Apply then BAP:Apply() end
	end
	MenuCallbackHandler.BigAmmoPickups_ZeroMin = function(self, item)
		BAP.settings.zero_pickup_min = math.floor(item:value() + 0.5)
		if BAP.Apply then BAP:Apply() end
	end
	MenuCallbackHandler.BigAmmoPickups_ZeroMax = function(self, item)
		BAP.settings.zero_pickup_max = math.floor(item:value() + 0.5)
		if BAP.Apply then BAP:Apply() end
	end
	MenuCallbackHandler.BigAmmoPickups_TacticalFromAmmo = function(self, item)
		BAP.settings.tactical_from_ammo = item:value() == "on"
	end
	MenuCallbackHandler.BigAmmoPickups_Save = function(self)
		BAP:Save()
		if BAP.Apply then BAP:Apply() end
	end

	MenuHelper:LoadFromJsonFile(BAP._path .. "options.txt", BAP, BAP.settings)

	-- Safety: re-apply if tweak_data already exists (e.g. mid-session reload).
	if BAP.Apply and tweak_data and tweak_data.weapon then
		BAP:Apply(tweak_data.weapon)
	end
end)
