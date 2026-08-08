--[[
	Big Ammo Pickups — core + WeaponTweakData apply
	Must be self-contained: weapontweakdata loads BEFORE menumanager,
	so menu.lua is not available yet when this hook runs.
]]

_G.BigAmmoPickups = _G.BigAmmoPickups or {}
local BAP = BigAmmoPickups

BAP._path = BAP._path or ModPath
BAP._data_path = BAP._data_path or (SavePath .. "big_ammo_pickups.txt")
BAP._originals = BAP._originals or {}
BAP.settings = BAP.settings or {}

function BAP:DefaultSettings()
	return {
		enabled = true,
		multiplier = 10,
		min_floor = 2,
		max_floor = 5,
		boost_zero_pickup = true,
		zero_pickup_min = 4,
		zero_pickup_max = 8,
	}
end

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

function BAP:Save()
	local file = io.open(self._data_path, "w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

-- Capture vanilla AMMO_PICKUP once per weapon key.
-- force=true clears cache first (use on WeaponTweakData:init only).
function BAP:StoreOriginals(wtd, force)
	if not wtd then
		return
	end
	if force then
		self._originals = {}
	end
	for key, weap in pairs(wtd) do
		if type(weap) == "table" and type(weap.AMMO_PICKUP) == "table"
			and type(weap.AMMO_PICKUP[1]) == "number" and type(weap.AMMO_PICKUP[2]) == "number" then
			if not self._originals[key] then
				self._originals[key] = { weap.AMMO_PICKUP[1], weap.AMMO_PICKUP[2] }
			end
		end
	end
end

function BAP:Apply(wtd)
	wtd = wtd or (tweak_data and tweak_data.weapon)
	if not wtd then
		return
	end
	if not self.settings or self.settings.multiplier == nil then
		self:Load()
	end
	self:StoreOriginals(wtd, false)

	local s = self.settings
	local boosted = 0
	local zeroed = 0

	for key, orig in pairs(self._originals) do
		local weap = wtd[key]
		if type(weap) == "table" then
			if not s.enabled then
				weap.AMMO_PICKUP = { orig[1], orig[2] }
			else
				local min_v, max_v = orig[1], orig[2]
				local was_zero = min_v <= 0 and max_v <= 0
				if was_zero then
					if s.boost_zero_pickup then
						min_v = s.zero_pickup_min or 0
						max_v = math.max(s.zero_pickup_max or 0, min_v)
						weap.AMMO_PICKUP = { min_v, max_v }
						zeroed = zeroed + 1
					else
						weap.AMMO_PICKUP = { orig[1], orig[2] }
					end
				else
					local mult = s.multiplier or 1
					min_v = min_v * mult
					max_v = max_v * mult
					local min_f = s.min_floor or 0
					local max_f = s.max_floor or 0
					if min_f > 0 then
						min_v = math.max(min_v, min_f)
					end
					if max_f > 0 then
						max_v = math.max(max_v, max_f)
					end
					if max_v < min_v then
						max_v = min_v
					end
					weap.AMMO_PICKUP = { min_v, max_v }
					boosted = boosted + 1
				end
			end
		end
	end

	if log then
		log(string.format(
			"[BigAmmoPickups] applied enabled=%s mult=%s boosted=%d special=%d floors=%s/%s zero=%s-%s",
			tostring(s.enabled),
			tostring(s.multiplier),
			boosted,
			zeroed,
			tostring(s.min_floor),
			tostring(s.max_floor),
			tostring(s.zero_pickup_min),
			tostring(s.zero_pickup_max)
		))
	end
end

-- Load settings as soon as this file is required (weapon tweak hook).
if not BAP._loaded_once then
	BAP:Load()
	BAP._loaded_once = true
end

local _orig_init = WeaponTweakData.init
function WeaponTweakData:init(tweak_data)
	_orig_init(self, tweak_data)
	if not BigAmmoPickups.settings or BigAmmoPickups.settings.multiplier == nil then
		BigAmmoPickups:Load()
	end
	-- Vanilla values are fresh here — force-capture originals then apply.
	BigAmmoPickups:StoreOriginals(self, true)
	BigAmmoPickups:Apply(self)
end
