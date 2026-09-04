--[[
	Diamond Path Helper v1.2.0 — The Diamond (level id: mus)

	Captures the REAL safe floor tiles after the path is generated, then prints
	ONE clean chat line.

	CRITICAL FIX v1.2.0:
	  setup_path / hack_path were wiping AFTER a002/b00x already arrived, so the
	  announced path lost the real entrance tile. Player stepped on the wrong
	  first column and alarmed instantly. Never wipe once cells are collecting.

	Grid (facing the diamond from the entrance / gas room door):
	  Columns 1–6 left → right
	  Rows a → i  (a = entrance / start, i = diamond end)

	Path cells are mission elements a001..i006. Safe floor pieces also run
	unit sequence "path_on" (piece_* props).
]]

_G.DiamondPathHelper = _G.DiamondPathHelper or {}
local DPH = DiamondPathHelper

DPH._path = DPH._path or ModPath
DPH._data_path = DPH._data_path or (SavePath .. "diamond_path_helper.txt")
DPH.settings = DPH.settings or {}

if not DPH.Load then
	function DPH:DefaultSettings()
		return {
			enabled = true,
			chat_mode = 1, -- 1 private, 2 public, 3 both
			show_grid = true, -- on: shows S/#/D map so you can verify before stepping
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
					self.settings[k] = v
				end
			end
		end
	end
end

if not next(DPH.settings) or DPH.settings.enabled == nil then
	if DPH.Load then
		DPH:Load()
	end
end

-- Runtime state
DPH._armed = false
DPH._cells = {} -- set: key "a001" -> true
DPH._capture_order = {} -- ordered list of first-seen keys (debug / fallback)
DPH._report_token = 0
DPH._announced_key = nil
DPH._last_announce_t = 0
DPH._path_gen = 0 -- increments only on a real empty wipe

local ROW_ORDER = { "a", "b", "c", "d", "e", "f", "g", "h", "i" }
local ROW_INDEX = { a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = 7, h = 8, i = 9 }
local CELL_PATTERN = "^([a-i])00([1-6])$"
local SETUP_NAMES = {
	setup_path = true,
	hack_path = true,
}
local PIECE_PATTERN = "piece_([a-i]00[1-6])"

local MIN_CELLS_TO_ANNOUNCE = 6
local SETTLE_DELAY = 1.1 -- wait after last new cell (lights trickle in)
local FORCE_DELAY = 2.0

local function is_diamond_level()
	local level_id = Global.game_settings and Global.game_settings.level_id
	return level_id == "mus"
end

local function parse_cell(name)
	if type(name) ~= "string" then
		return nil
	end
	local row, col = string.match(name, CELL_PATTERN)
	if row and col then
		return row, tonumber(col), row .. "00" .. col
	end
	return nil
end

local function cell_key(row, col)
	return string.format("%s00%d", row, col)
end

local function game_time()
	if TimerManager and TimerManager.game then
		local ok, t = pcall(function()
			return TimerManager:game():time()
		end)
		if ok and t then
			return t
		end
	end
	return 0
end

function DPH:IsEnabled()
	return self.settings and self.settings.enabled ~= false
end

function DPH:CellCount()
	local n = 0
	for _ in pairs(self._cells or {}) do
		n = n + 1
	end
	return n
end

function DPH:ClearCells(reason)
	self._cells = {}
	self._capture_order = {}
	self._announced_key = nil
	self._path_gen = (self._path_gen or 0) + 1
	if log then
		log(string.format("[DiamondPathHelper] CLEARED cells (%s) gen=%d", tostring(reason or "?"), self._path_gen))
	end
end

--- Start / refresh a path capture window.
--- WIPE is only allowed when we have ZERO cells so far.
--- setup_path often fires AFTER a001/a002 already arrived — wiping then drops the
--- real entrance tile and the printed path starts on the wrong column (instant alarm).
function DPH:Arm(reason, wipe)
	if not self:IsEnabled() or not is_diamond_level() then
		return
	end
	local n = self:CellCount()
	if wipe then
		if n > 0 then
			-- Keep collecting — do NOT destroy in-flight tiles
			if log then
				log(string.format(
					"[DiamondPathHelper] Arm(%s) wipe REQUESTED but kept %d cells (no wipe)",
					tostring(reason or "?"),
					n
				))
			end
			wipe = false
		else
			self:ClearCells(reason or "arm")
		end
	end
	self._armed = true
	self._report_token = (self._report_token or 0) + 1
	if log then
		log(string.format(
			"[DiamondPathHelper] Armed (%s) wipe=%s cells=%d gen=%d",
			tostring(reason or "?"),
			tostring(wipe and true or false),
			self:CellCount(),
			self._path_gen or 0
		))
	end
	self:ScheduleReport(FORCE_DELAY, true)
end

function DPH:AddCell(key, source)
	if not key then
		return
	end
	local row, col = parse_cell(key)
	if not row then
		return
	end
	if not self._armed then
		self._armed = true
		self._cells = self._cells or {}
		self._capture_order = self._capture_order or {}
		self._report_token = (self._report_token or 0) + 1
	end
	if self._cells[key] then
		return
	end
	self._cells[key] = true
	table.insert(self._capture_order, key)
	if log then
		log(string.format(
			"[DiamondPathHelper] +%s (%s) total=%d order=#%d",
			key,
			tostring(source or "?"),
			self:CellCount(),
			#self._capture_order
		))
	end
	self:ScheduleReport(SETTLE_DELAY, false)
end

function DPH:CellList()
	local list = {}
	for key in pairs(self._cells or {}) do
		table.insert(list, key)
	end
	return list
end

local function neighbors_of(set, row, col)
	local ri = ROW_INDEX[row]
	local out = {}
	local deltas = {
		{ 0, -1 },
		{ 0, 1 },
		{ -1, 0 },
		{ 1, 0 },
	}
	for _, d in ipairs(deltas) do
		local nr_i = ri + d[1]
		local nc = col + d[2]
		if nr_i >= 1 and nr_i <= 9 and nc >= 1 and nc <= 6 then
			local nrow = ROW_ORDER[nr_i]
			local k = cell_key(nrow, nc)
			if set[k] then
				table.insert(out, { row = nrow, col = nc, key = k })
			end
		end
	end
	return out
end

--- Longest simple path from start that reaches row i when possible (DFS, tiny graph).
local function best_walk_from(set, start_key)
	local srow, scol = parse_cell(start_key)
	if not srow then
		return { start_key }
	end

	local best = { start_key }
	local best_reaches_i = (srow == "i")

	local function dfs(row, col, path, visited)
		local reached_i = (row == "i")
		local better = false
		if reached_i and not best_reaches_i then
			better = true
		elseif reached_i == best_reaches_i then
			if #path > #best then
				better = true
			elseif #path == #best then
				-- Prefer higher max row
				local max_a, max_b = 0, 0
				for _, k in ipairs(path) do
					local r = parse_cell(k)
					if r then
						max_a = math.max(max_a, ROW_INDEX[r] or 0)
					end
				end
				for _, k in ipairs(best) do
					local r = parse_cell(k)
					if r then
						max_b = math.max(max_b, ROW_INDEX[r] or 0)
					end
				end
				better = max_a > max_b
			end
		end
		if better then
			best = {}
			for _, k in ipairs(path) do
				table.insert(best, k)
			end
			best_reaches_i = reached_i
		end

		if #path >= 24 then
			return
		end

		local nbs = neighbors_of(set, row, col)
		-- Prefer climbing toward diamond, then lateral
		table.sort(nbs, function(a, b)
			local sa = ROW_INDEX[a.row] * 10 - math.abs(a.col - col)
			local sb = ROW_INDEX[b.row] * 10 - math.abs(b.col - col)
			if ROW_INDEX[a.row] > ROW_INDEX[row] then
				sa = sa + 50
			end
			if ROW_INDEX[b.row] > ROW_INDEX[row] then
				sb = sb + 50
			end
			return sa > sb
		end)

		for _, n in ipairs(nbs) do
			if not visited[n.key] then
				visited[n.key] = true
				table.insert(path, n.key)
				dfs(n.row, n.col, path, visited)
				table.remove(path)
				visited[n.key] = nil
			end
		end
	end

	dfs(srow, scol, { start_key }, { [start_key] = true })
	return best, best_reaches_i
end

--- Rebuild walk order from entrance (row a) along adjacent safe tiles toward row i.
function DPH:OrderPath()
	local set = {}
	for key in pairs(self._cells or {}) do
		local row, col = parse_cell(key)
		if row and col then
			set[key] = true
		end
	end

	local starts = {}
	for col = 1, 6 do
		local k = cell_key("a", col)
		if set[k] then
			table.insert(starts, k)
		end
	end
	if #starts == 0 then
		-- Incomplete capture — start from lowest row present
		for _, row in ipairs(ROW_ORDER) do
			for col = 1, 6 do
				local k = cell_key(row, col)
				if set[k] then
					table.insert(starts, k)
				end
			end
			if #starts > 0 then
				break
			end
		end
	end

	local best, best_ok = nil, false
	for _, sk in ipairs(starts) do
		local path, reaches_i = best_walk_from(set, sk)
		if not best then
			best, best_ok = path, reaches_i
		elseif reaches_i and not best_ok then
			best, best_ok = path, reaches_i
		elseif reaches_i == best_ok and path and best and #path > #best then
			best, best_ok = path, reaches_i
		end
	end

	if not best or #best == 0 then
		best = self:CellList()
		table.sort(best, function(a, b)
			local ra, ca = parse_cell(a)
			local rb, cb = parse_cell(b)
			if ra == rb then
				return (ca or 0) < (cb or 0)
			end
			return (ROW_INDEX[ra] or 0) < (ROW_INDEX[rb] or 0)
		end)
	else
		-- Append disconnected leftovers (should be rare)
		local visited = {}
		for _, k in ipairs(best) do
			visited[k] = true
		end
		local leftovers = {}
		for key in pairs(set) do
			if not visited[key] then
				table.insert(leftovers, key)
			end
		end
		if #leftovers > 0 then
			table.sort(leftovers, function(a, b)
				local ra, ca = parse_cell(a)
				local rb, cb = parse_cell(b)
				if ra == rb then
					return (ca or 0) < (cb or 0)
				end
				return (ROW_INDEX[ra] or 0) < (ROW_INDEX[rb] or 0)
			end)
			if log then
				log("[DiamondPathHelper] WARNING leftover tiles not on walk: " .. table.concat(leftovers, ","))
			end
			for _, k in ipairs(leftovers) do
				table.insert(best, k)
			end
		end
	end

	return best
end

function DPH:BuildFormats()
	local ordered = self:OrderPath()
	if not ordered or #ordered == 0 then
		return nil
	end

	local cols = {}
	local keys_line = {}
	for _, key in ipairs(ordered) do
		local _, col = parse_cell(key)
		table.insert(cols, tostring(col))
		table.insert(keys_line, key)
	end
	local compact = table.concat(cols, "-")

	-- Group runs: 3-3-4-5-5 → 33-4-55
	local groups = {}
	local cur, count = nil, 0
	for _, key in ipairs(ordered) do
		local _, col = parse_cell(key)
		if col == cur then
			count = count + 1
		else
			if cur then
				table.insert(groups, string.rep(tostring(cur), count))
			end
			cur = col
			count = 1
		end
	end
	if cur then
		table.insert(groups, string.rep(tostring(cur), count))
	end
	local grouped = table.concat(groups, "-")

	local by_row = {}
	for _, key in ipairs(ordered) do
		local row, col = parse_cell(key)
		by_row[row] = by_row[row] or {}
		table.insert(by_row[row], col)
	end
	local row_bits = {}
	for _, row in ipairs(ROW_ORDER) do
		local cols_on_row = by_row[row]
		if cols_on_row and #cols_on_row > 0 then
			local uniq, seen = {}, {}
			for _, c in ipairs(cols_on_row) do
				if not seen[c] then
					seen[c] = true
					table.insert(uniq, tostring(c))
				end
			end
			table.insert(row_bits, table.concat(uniq, "/"))
		end
	end
	local by_row_str = table.concat(row_bits, " > ")

	local has_row_a = by_row["a"] and #by_row["a"] > 0
	local start_key = ordered[1]
	local _, start_col = parse_cell(start_key)

	local grid_lines = {}
	-- Always build grid for private chat when show_grid, else still log it
	do
		table.insert(grid_lines, "  1 2 3 4 5 6   (1=left 6=right facing diamond)")
		for i = #ROW_ORDER, 1, -1 do
			local row = ROW_ORDER[i]
			local setc = {}
			for _, c in ipairs(by_row[row] or {}) do
				setc[c] = true
			end
			local cells = {}
			for c = 1, 6 do
				if setc[c] then
					if row == "a" and c == start_col then
						table.insert(cells, "S")
					elseif row == "i" then
						table.insert(cells, "D")
					else
						table.insert(cells, "#")
					end
				else
					table.insert(cells, ".")
				end
			end
			table.insert(grid_lines, row .. " " .. table.concat(cells, " "))
		end
	end

	return {
		compact = compact,
		grouped = grouped,
		by_row = by_row_str,
		grid_lines = grid_lines,
		count = #ordered,
		start_key = start_key,
		start_col = start_col,
		has_row_a = has_row_a,
		keys_line = table.concat(keys_line, " "),
		key = compact .. "|" .. tostring(#ordered) .. "|" .. tostring(start_key),
	}
end

function DPH:Announce(fmt)
	if not fmt or not managers or not managers.chat then
		return
	end

	local t = game_time()
	if self._announced_key == fmt.key and (t - (self._last_announce_t or 0)) < 8 then
		return
	end
	self._announced_key = fmt.key
	self._last_announce_t = t
	self._armed = false

	local prefix = "[Diamond Path]"
	local color = Color(0.37, 0.88, 1)
	local channel = (ChatManager and ChatManager.GAME) or 1
	local mode = tonumber(self.settings.chat_mode) or 1
	local username = (managers.network and managers.network.account and managers.network.account:username()) or "Offline"

	local start_line = string.format(
		"START on tile %s = column %d (row a entrance). 1=left … 6=right facing diamond.",
		tostring(fmt.start_key or "?"),
		tonumber(fmt.start_col) or 0
	)
	local main = string.format("%s  (%d tiles)", fmt.compact, fmt.count or 0)
	local secondary = string.format("steps: %s  |  a→i: %s", fmt.grouped, fmt.by_row)
	if not fmt.has_row_a then
		secondary = secondary .. "  |  ⚠ no row-a tile — path may be incomplete, do NOT trust start column"
	end

	local function send_private(text)
		managers.chat:_receive_message(channel, prefix, text, color)
	end

	local function send_public(text)
		managers.chat:send_message(channel, username, text)
	end

	if mode == 1 or mode == 3 then
		send_private(start_line)
		send_private(main)
		send_private(secondary)
		if self.settings.show_grid ~= false and fmt.grid_lines then
			for _, gl in ipairs(fmt.grid_lines) do
				send_private(gl)
			end
		end
	end
	if mode == 2 or mode == 3 then
		send_public(prefix .. " START col " .. tostring(fmt.start_col) .. " | " .. fmt.compact)
	end

	if self.settings.show_hint and managers.hud and managers.hud.show_hint then
		managers.hud:show_hint({
			text = string.format("Path start col %s: %s", tostring(fmt.start_col), fmt.compact),
			time = 10,
		})
	end

	if log then
		log(string.format(
			"[DiamondPathHelper] ANNOUNCE start=%s col=%s path=%s keys=[%s]",
			tostring(fmt.start_key),
			tostring(fmt.start_col),
			fmt.compact,
			tostring(fmt.keys_line)
		))
	end
end

function DPH:ScheduleReport(delay, force)
	if not self:IsEnabled() or not is_diamond_level() then
		return
	end
	delay = delay or SETTLE_DELAY
	self._report_token = (self._report_token or 0) + 1
	local token = self._report_token
	local allow_short = force and true or false

	local function do_report()
		if token ~= self._report_token then
			return
		end
		if not self:IsEnabled() or not is_diamond_level() then
			return
		end
		local n = self:CellCount()
		if n <= 0 then
			if log then
				log("[DiamondPathHelper] Report skipped — no cells yet.")
			end
			return
		end
		if n < MIN_CELLS_TO_ANNOUNCE and not allow_short then
			self:ScheduleReport(0.7, true)
			return
		end
		-- Prefer waiting for a row-a entrance tile if we're still armed and short on time
		local has_a = false
		for key in pairs(self._cells or {}) do
			if string.sub(key, 1, 1) == "a" then
				has_a = true
				break
			end
		end
		if not has_a and not allow_short then
			self:ScheduleReport(0.5, true)
			return
		end
		local fmt = self:BuildFormats()
		if fmt then
			self:Announce(fmt)
		end
	end

	local id = "DiamondPathHelper_Report_" .. tostring(token)
	if DelayedCalls and DelayedCalls.Add then
		DelayedCalls:Add(id, delay, do_report)
	elseif managers and managers.enemy and managers.enemy.add_delayed_clbk then
		managers.enemy:add_delayed_clbk(id, do_report, game_time() + delay)
	else
		do_report()
	end
end

function DPH:BeginCollect()
	self:Arm("begin_collect", false)
end

function DPH:QueueReport(delay)
	self:ScheduleReport(delay or FORCE_DELAY, true)
end

function DPH:OnElementExecuted(element)
	if not self:IsEnabled() or not is_diamond_level() or not element then
		return
	end

	local name = nil
	if element.editor_name then
		local ok, result = pcall(function()
			return element:editor_name()
		end)
		if ok then
			name = result
		end
	end
	name = name or element._editor_name
	if type(name) ~= "string" then
		name = nil
	end

	if name and SETUP_NAMES[name] then
		-- Real path generation signal. ONLY wipe if we have no tiles yet.
		-- Mission often does: hack_path → a002/b002 → setup_path (wipe was killing start).
		self:Arm(name, self:CellCount() == 0)
		return
	end

	if name then
		local _, _, key = parse_cell(name)
		if key then
			self:AddCell(key, "element:" .. name)
			return
		end
	end

	if element._values and type(element._values.event) == "string" then
		local _, _, ekey = parse_cell(element._values.event)
		if ekey then
			self:AddCell(ekey, "event")
		end
	end
end

function DPH:OnSequence(unit, sequence_name)
	if not self:IsEnabled() or not is_diamond_level() then
		return
	end
	if sequence_name ~= "path_on" then
		return
	end
	if not alive(unit) then
		return
	end

	local ud = unit.unit_data and unit:unit_data()
	local name_id = ud and (ud.name_id or ud.name_id_string)
	local cell = nil
	if type(name_id) == "string" then
		cell = string.match(name_id, PIECE_PATTERN)
	end
	if not cell then
		return
	end

	self:AddCell(cell, "path_on")
end

-- ---------------------------------------------------------------------------
-- Hooks
-- ---------------------------------------------------------------------------

if MissionScriptElement then
	Hooks:PostHook(MissionScriptElement, "on_executed", "DiamondPathHelper_ElementOnExecuted", function(self, instigator, ...)
		DPH:OnElementExecuted(self)
	end)

	if MissionScriptElement.client_on_executed then
		Hooks:PostHook(MissionScriptElement, "client_on_executed", "DiamondPathHelper_ElementClientOnExecuted", function(self, ...)
			DPH:OnElementExecuted(self)
		end)
	end
end

if UnitDamage then
	Hooks:PostHook(UnitDamage, "run_sequence_simple", "DiamondPathHelper_RunSequenceSimple", function(self, name, params)
		DPH:OnSequence(self._unit, name)
	end)

	if UnitDamage.run_sequence then
		Hooks:PostHook(UnitDamage, "run_sequence", "DiamondPathHelper_RunSequence", function(self, name, ...)
			DPH:OnSequence(self._unit, name)
		end)
	end
end

if log then
	log("[DiamondPathHelper] core.lua v1.2.0 LOADED — no mid-path wipe, keep entrance tile")
end
