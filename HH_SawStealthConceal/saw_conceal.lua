--[[
	Saw Stealth Conceal — set OVE9000 Saw concealment high for stealth builds.
	weapontweakdata loads before menumanager; keep settings self-contained here.
]]

_G.SawStealthConceal = _G.SawStealthConceal or {}
local SSC = SawStealthConceal

SSC._path = SSC._path or ModPath
SSC._data_path = SSC._data_path or (SavePath .. "saw_stealth_conceal.txt")
SSC._originals = SSC._originals or {}
SSC.settings = SSC.settings or {}

-- Weapon tweak keys for the OVE9000 family
SSC.SAW_KEYS = {
	"saw",
	"saw_secondary",
}

function SSC:DefaultSettings()
	return {
		enabled = true,
		-- PD2 weapon concealment: higher = better stealth (max useful ~30)
		concealment = 30,
	}
end

function SSC:Load()
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

function SSC:Save()
	local file = io.open(self._data_path, "w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

function SSC:StoreOriginals(wtd, force)
	if not wtd then
		return
	end
	if force then
		self._originals = {}
	end
	for _, key in ipairs(self.SAW_KEYS) do
		local weap = wtd[key]
		if type(weap) == "table" and type(weap.stats) == "table" and type(weap.stats.concealment) == "number" then
			if not self._originals[key] then
				self._originals[key] = weap.stats.concealment
			end
		end
	end
end

function SSC:Apply(wtd)
	wtd = wtd or (tweak_data and tweak_data.weapon)
	if not wtd then
		return
	end
	if not self.settings or self.settings.concealment == nil then
		self:Load()
	end
	self:StoreOriginals(wtd, false)

	local s = self.settings
	local n = 0
	for _, key in ipairs(self.SAW_KEYS) do
		local weap = wtd[key]
		if type(weap) == "table" and type(weap.stats) == "table" then
			if not s.enabled then
				if self._originals[key] then
					weap.stats.concealment = self._originals[key]
				end
			else
				local val = tonumber(s.concealment) or 30
				if val < 0 then val = 0 end
				if val > 30 then val = 30 end
				weap.stats.concealment = val
				n = n + 1
			end
		end
	end
	if n > 0 then
		log(string.format("[SawStealthConceal] Applied concealment=%s to %d saw entries", tostring(s.concealment), n))
	end
end

SSC:Load()

Hooks:PostHook(WeaponTweakData, "init", "SawStealthConceal_WeaponTweakData_init", function(self)
	SSC:StoreOriginals(self, true)
	SSC:Apply(self)
end)
