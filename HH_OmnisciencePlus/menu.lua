_G.OmnisciencePlus = _G.OmnisciencePlus or {}
OmnisciencePlus._path = ModPath
OmnisciencePlus._data_path = SavePath .. "omniscience_plus.txt"
OmnisciencePlus.settings = OmnisciencePlus.settings or {}
OmnisciencePlus._suspended = false

function OmnisciencePlus:DefaultSettings()
	return {
		enabled = true,
		require_skill = true,
		start_t_tenths = 10,
		interval_t_tenths = 10,
		radius_m = 75,
		target_resense_t = 10,
		marks_per_tick = 0,
		mark_items = true,
		mark_cameras = true,
		mark_circuit_boxes = true,
		mark_people = true,
		mark_pickups = true,
		mark_loot = true,
		mark_loose_loot = true,
		mark_atms = true,
		mark_crates = true,
		mark_safes = true,
		mark_computers = false,
		mark_body_bags = false,
		mark_dropped_bags = false,
		sync_people = false,
		permanent_marks = false,
	}
end

function OmnisciencePlus:Load()
	self.settings = self:DefaultSettings()
	local file = io.open(self._data_path, "r")
	if file then
		local ok, data = pcall(json.decode, file:read("*all"))
		file:close()
		if ok and type(data) == "table" then
			for k, v in pairs(data) do
				if self.settings[k] ~= nil or k == "enabled" then
					self.settings[k] = v
				end
			end
		end
	end
	pcall(function()
		self:Save()
	end)
end

function OmnisciencePlus:Save()
	local file = io.open(self._data_path, "w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

function OmnisciencePlus:StartT()
	return (self.settings.start_t_tenths or 10) / 10
end

function OmnisciencePlus:IntervalT()
	return (self.settings.interval_t_tenths or 10) / 10
end

function OmnisciencePlus:SenseRadius()
	return (self.settings.radius_m or 75) * 100
end

function OmnisciencePlus:ResenseT()
	return self.settings.target_resense_t or 10
end

function OmnisciencePlus:Suspend()
	self._suspended = true
	self._diag = 0
	if self.ClearQuestWaypoints then
		pcall(function()
			self:ClearQuestWaypoints()
		end)
	end
end

function OmnisciencePlus:Resume()
	self._suspended = false
	self._diag = 0
	self._err_logged = nil
	self._quest_next_t = 0
end

function OmnisciencePlus:ApplyToTweakData()
	if not tweak_data or not tweak_data.player then
		return
	end
	tweak_data.player.omniscience = tweak_data.player.omniscience or {}
	tweak_data.player.omniscience.start_t = self:StartT()
	tweak_data.player.omniscience.interval_t = self:IntervalT()
	tweak_data.player.omniscience.sense_radius = self:SenseRadius()
	tweak_data.player.omniscience.target_resense_t = self:ResenseT()
	tweak_data.player.omniscience.sense_exit_sq = 4900
end

OmnisciencePlus:Load()

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_OmnisciencePlus", function(loc)
	loc:load_localization_file(OmnisciencePlus._path .. "loc/english.txt")
end)

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_OmnisciencePlus", function(menu_manager)
	local function num_cb(key)
		return function(self, item)
			OmnisciencePlus.settings[key] = math.floor(item:value() + 0.5)
			OmnisciencePlus:ApplyToTweakData()
		end
	end
	local function tog_cb(key)
		return function(self, item)
			OmnisciencePlus.settings[key] = item:value() == "on"
			OmnisciencePlus:ApplyToTweakData()
		end
	end

	MenuCallbackHandler.OmnisciencePlus_Enabled = tog_cb("enabled")
	MenuCallbackHandler.OmnisciencePlus_RequireSkill = tog_cb("require_skill")
	MenuCallbackHandler.OmnisciencePlus_Permanent = tog_cb("permanent_marks")
	MenuCallbackHandler.OmnisciencePlus_MarkItems = tog_cb("mark_items")
	MenuCallbackHandler.OmnisciencePlus_MarkCameras = tog_cb("mark_cameras")
	MenuCallbackHandler.OmnisciencePlus_MarkCircuitBoxes = tog_cb("mark_circuit_boxes")
	MenuCallbackHandler.OmnisciencePlus_MarkPeople = tog_cb("mark_people")
	MenuCallbackHandler.OmnisciencePlus_MarkPickups = tog_cb("mark_pickups")
	MenuCallbackHandler.OmnisciencePlus_MarkLoot = tog_cb("mark_loot")
	MenuCallbackHandler.OmnisciencePlus_MarkLooseLoot = tog_cb("mark_loose_loot")
	MenuCallbackHandler.OmnisciencePlus_MarkAtms = tog_cb("mark_atms")
	MenuCallbackHandler.OmnisciencePlus_MarkCrates = tog_cb("mark_crates")
	MenuCallbackHandler.OmnisciencePlus_MarkSafes = tog_cb("mark_safes")
	MenuCallbackHandler.OmnisciencePlus_MarkComputers = tog_cb("mark_computers")
	MenuCallbackHandler.OmnisciencePlus_MarkBodyBags = tog_cb("mark_body_bags")
	MenuCallbackHandler.OmnisciencePlus_MarkDroppedBags = tog_cb("mark_dropped_bags")
	MenuCallbackHandler.OmnisciencePlus_SyncPeople = tog_cb("sync_people")
	MenuCallbackHandler.OmnisciencePlus_StartT = num_cb("start_t_tenths")
	MenuCallbackHandler.OmnisciencePlus_IntervalT = num_cb("interval_t_tenths")
	MenuCallbackHandler.OmnisciencePlus_RadiusM = num_cb("radius_m")
	MenuCallbackHandler.OmnisciencePlus_Resense = num_cb("target_resense_t")
	MenuCallbackHandler.OmnisciencePlus_MarksPerTick = num_cb("marks_per_tick")
	MenuCallbackHandler.OmnisciencePlus_Save = function(self)
		OmnisciencePlus:Save()
		OmnisciencePlus:ApplyToTweakData()
	end

	MenuHelper:LoadFromJsonFile(OmnisciencePlus._path .. "options.txt", OmnisciencePlus, OmnisciencePlus.settings)
end)
