--[[
	Instant Restart — file logger for post-run diagnosis.
	Writes to SuperBLT saves + mod folder so we can read it after you test.
]]

_G.InstantRestart = _G.InstantRestart or {}
local IR = InstantRestart

IR._path = IR._path or ModPath
IR._log_save = (SavePath or "") .. "instant_restart.log"
IR._log_mod = (IR._path or ModPath) .. "instant_restart.log"
IR._log_enabled = true
IR._log_max_bytes = 256 * 1024

local function _ts()
	local ok, t = pcall(function()
		return os.date("%Y-%m-%d %H:%M:%S")
	end)
	if ok and t then
		return t
	end
	return "?"
end

local function _append(path, line)
	if not path or path == "" then
		return
	end
	local f = io.open(path, "a")
	if not f then
		return
	end
	f:write(line)
	f:write("\n")
	f:close()
end

local function _trim_if_huge(path)
	if not path or path == "" then
		return
	end
	local f = io.open(path, "r")
	if not f then
		return
	end
	local size = f:seek("end")
	f:close()
	if not size or size < (IR._log_max_bytes or 262144) then
		return
	end
	-- keep tail only
	f = io.open(path, "r")
	if not f then
		return
	end
	local data = f:read("*all") or ""
	f:close()
	local keep = data:sub(-math.floor((IR._log_max_bytes or 262144) / 2))
	f = io.open(path, "w")
	if f then
		f:write("...log trimmed...\n")
		f:write(keep)
		f:close()
	end
end

function IR:log(msg, data)
	if self._log_enabled == false then
		return
	end
	local line = string.format("[%s] %s", _ts(), tostring(msg or ""))
	if data ~= nil then
		local ok, enc = pcall(function()
			if type(data) == "table" and json and json.encode then
				return json.encode(data)
			end
			return tostring(data)
		end)
		line = line .. " | " .. (ok and enc or tostring(data))
	end
	_append(self._log_save, line)
	_append(self._log_mod, line)
	_trim_if_huge(self._log_save)
	_trim_if_huge(self._log_mod)
end

function IR:log_clear()
	for _, path in ipairs({ self._log_save, self._log_mod }) do
		if path and path ~= "" then
			local f = io.open(path, "w")
			if f then
				f:write(string.format("[%s] === InstantRestart log cleared ===\n", _ts()))
				f:close()
			end
		end
	end
end

function IR:snapshot()
	local snap = {
		pending = self.pending_auto_start and true or false,
		starting = self.starting and true or false,
		enabled = self.settings and self.settings.enabled,
		auto_start = self.settings and self.settings.auto_start,
		start_delay = self.settings and self.settings.start_delay,
		is_server = nil,
		in_game = nil,
		in_heist = nil,
		state_name = nil,
		state_type = nil,
		has_start_game_intro = nil,
		peers_ok = nil,
		streaming_ok = nil,
		single_player = nil,
		job_id = nil,
		global_pending = nil,
		file_pending = nil
	}

	local ok
	ok, snap.is_server = pcall(function()
		return Network and Network:is_server() or false
	end)
	ok, snap.in_game = pcall(function()
		return Utils and Utils:IsInGameState() or false
	end)
	ok, snap.in_heist = pcall(function()
		return Utils and Utils:IsInHeist() or false
	end)
	ok, snap.single_player = pcall(function()
		return Global and Global.game_settings and Global.game_settings.single_player
	end)
	ok, snap.job_id = pcall(function()
		return managers and managers.job and managers.job:current_level_id()
	end)
	ok, snap.global_pending = pcall(function()
		return Global and Global.instant_restart_pending
	end)
	ok, snap.file_pending = pcall(function()
		return self:read_pending_flag()
	end)

	local state
	ok, state = pcall(function()
		return game_state_machine and game_state_machine:current_state()
	end)
	if ok and state then
		snap.state_type = type(state)
		local name_ok, name = pcall(function()
			if state.name then
				return state:name()
			end
			return nil
		end)
		if name_ok then
			snap.state_name = name
		end
		local class_ok, cname = pcall(function()
			return state.CLASS_NAME or (state.super and tostring(state.super)) or tostring(state)
		end)
		if class_ok then
			snap.state_repr = tostring(cname):sub(1, 120)
		end
		snap.has_start_game_intro = type(state.start_game_intro) == "function"
		snap._starting_mission_briefing_intro = state._starting_mission_briefing_intro and true or false
		snap._intro_t = state._intro_t ~= nil
		snap._started = state._started and true or false
	end

	ok, snap.peers_ok = pcall(function()
		return self:peers_synched()
	end)

	ok, snap.streaming_ok = pcall(function()
		local session = managers.network and managers.network:session()
		if not session then
			return true
		end
		local lp = session:local_peer()
		if lp and lp.is_streaming_complete then
			return lp:is_streaming_complete()
		end
		return true
	end)

	return snap
end

function IR:log_snapshot(tag)
	self:log(tag or "snapshot", self:snapshot())
end
