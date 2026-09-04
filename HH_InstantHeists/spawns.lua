--[[
	Instant Heists — natural GroupAI spawn cadence (assault / recon / reenforce).

	Does not touch scripted ElementSpawnEnemy* heist events.
	Host-authoritative. Mid-heist slider changes re-apply tweak_data.
]]

if not InstantHeists or not InstantHeists.Load then
	dofile(ModPath .. "core.lua")
end

local IH = InstantHeists

local function clone_nums(v)
	if type(v) == "number" then
		return v
	end
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, n in pairs(v) do
		if type(n) == "number" then
			out[k] = n
		elseif type(n) == "table" then
			out[k] = clone_nums(n)
		else
			out[k] = n
		end
	end
	return out
end

local function scale_nums(v, mult)
	mult = tonumber(mult) or 1
	if mult < 1 then
		mult = 1
	end
	if type(v) == "number" then
		return math.max(0.1, v / mult)
	end
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, n in pairs(v) do
		if type(n) == "number" then
			out[k] = math.max(0.1, n / mult)
		elseif type(n) == "table" then
			out[k] = scale_nums(n, mult)
		else
			out[k] = n
		end
	end
	return out
end

local TWEAK_FIELDS = {
	{ "assault", "delay", "assault_break_mult" },
	{ "assault", "hostage_hesitation_delay", "assault_break_mult" },
	{ "recon", "interval", "recon_spawn_mult" },
	{ "reenforce", "interval", "recon_spawn_mult" },
}

-- Never promote a 0-weight group (unloaded units → PackageManager crash).
-- Sliders are a recipe: if they differ, kind shares follow the sliders
-- (grunt 1 / dozer 4 ≈ 1:4 among squads this map already has). If every
-- present kind is the same number, keep vanilla ratios (0 still means off).
local function slot_count(orig_w)
	local slots = 1
	for _, v in pairs(orig_w) do
		if type(v) == "table" then
			local n = #v
			if n > slots then
				slots = n
			end
		end
	end
	return slots
end

local function slot_val(v, slot)
	if type(v) == "number" then
		return v
	end
	if type(v) == "table" then
		return tonumber(v[slot]) or 0
	end
	return 0
end

function IH:WriteMixedWeights(weights, orig_w, groups)
	if type(weights) ~= "table" or type(orig_w) ~= "table" then
		return
	end
	local slots = slot_count(orig_w)
	local kind_of = {}
	for gname, _ in pairs(orig_w) do
		local gdata = (self._mix_group_orig and self._mix_group_orig[gname]) or (groups and groups[gname])
		kind_of[gname] = self:GroupPrimaryKind(gname, gdata)
	end
	for slot = 1, slots do
		local kind_tot = {}
		local grand = 0
		for gname, ov in pairs(orig_w) do
			local k = kind_of[gname]
			local n = slot_val(ov, slot)
			if n > 0 then
				kind_tot[k] = (kind_tot[k] or 0) + n
				grand = grand + n
			end
		end
		local mix_sum, mix_first, mix_same = 0, nil, true
		local mix_of = {}
		for k, tot in pairs(kind_tot) do
			if tot > 0 then
				local m = self:MixMult(k)
				mix_of[k] = m
				if m > 0 then
					mix_sum = mix_sum + m
				end
				if mix_first == nil then
					mix_first = m
				elseif m ~= mix_first then
					mix_same = false
				end
			end
		end
		local factor = {}
		for k, tot in pairs(kind_tot) do
			local m = mix_of[k] or 1
			if m <= 0 or tot <= 0 or grand <= 0 then
				factor[k] = 0
			elseif mix_same then
				factor[k] = 1
			else
				local target = (mix_sum > 0) and (m / mix_sum) or 0
				local share = tot / grand
				factor[k] = (share > 0) and (target / share) or 0
			end
		end
		for gname, ov in pairs(orig_w) do
			local k = kind_of[gname]
			local n = slot_val(ov, slot)
			local f = factor[k] or 0
			local nv = (n > 0) and (n * f) or 0
			local cur = weights[gname]
			if type(ov) == "number" then
				weights[gname] = nv
			elseif type(ov) == "table" then
				if type(cur) ~= "table" then
					cur = clone_nums(ov)
					weights[gname] = cur
				end
				cur[slot] = nv
			end
		end
	end
end

-- Pick the squad's "identity" so sliders stay unmixed:
-- a dozer+medic pack is a dozer pack, not an average of both.
function IH:GroupPrimaryKind(gname, gdata)
	local prio = { dozer = 6, cloaker = 5, taser = 4, sniper = 3, shield = 2, medic = 1, grunt = 0 }
	local best, score = self:UnitKindOf(gname), prio[self:UnitKindOf(gname)] or 0
	if type(gdata) == "table" and type(gdata.spawn) == "table" then
		for _, entry in ipairs(gdata.spawn) do
			if entry and entry.unit then
				local k = self:UnitKindOf(entry.unit)
				local s = prio[k] or 0
				if s > score then
					best, score = k, s
				end
			end
		end
	end
	return best
end

function IH:GroupMixMult(gname, gdata)
	return self:MixMult(self:GroupPrimaryKind(gname, gdata))
end

function IH:ApplySpawnMix()
	local gai = tweak_data and tweak_data.group_ai
	if not gai or not self.MixMult then
		return
	end
	self._mix_group_orig = self._mix_group_orig or {}
	self._mix_weight_orig = self._mix_weight_orig or {}

	-- Only change WHO gets picked and WHETHER a type is allowed in a pack.
	-- Never inflate squad size — that stacks them on one spawn point and
	-- the group never finishes, so they never get assault orders.
	local groups = gai.enemy_spawn_groups
	if type(groups) == "table" then
		for gname, gdata in pairs(groups) do
			if type(gdata) == "table" and type(gdata.spawn) == "table" then
				if not self._mix_group_orig[gname] then
					local snap = { spawn = {}, amount = clone_nums(gdata.amount) }
					for i, entry in ipairs(gdata.spawn) do
						snap.spawn[i] = {
							unit = entry.unit,
							freq = entry.freq,
							amount_min = entry.amount_min,
							amount_max = entry.amount_max,
						}
					end
					self._mix_group_orig[gname] = snap
				end
				local orig = self._mix_group_orig[gname]
				for i, entry in ipairs(gdata.spawn) do
					local o = orig.spawn[i]
					if o then
						local m = self:MixMult(self:UnitKindOf(o.unit))
						if type(o.freq) == "number" then
							entry.freq = (m <= 0) and 0 or o.freq
						end
						if type(o.amount_min) == "number" then
							entry.amount_min = (m <= 0) and 0 or o.amount_min
						end
						if type(o.amount_max) == "number" then
							entry.amount_max = (m <= 0) and 0 or o.amount_max
						end
					end
				end
				if orig.amount then
					gdata.amount = clone_nums(orig.amount)
				end
			end
		end
	end

	for _, mode in ipairs({ "besiege", "street", "safehouse" }) do
		local block = gai[mode]
		if type(block) == "table" then
			for _, phase in ipairs({ "assault", "recon", "reenforce" }) do
				local weights = block[phase] and block[phase].groups
				if type(weights) == "table" then
					local wkey = mode .. "." .. phase
					if not self._mix_weight_orig[wkey] then
						self._mix_weight_orig[wkey] = clone_nums(weights)
					end
					local orig_w = self._mix_weight_orig[wkey]
					self:WriteMixedWeights(weights, orig_w, groups)
				end
			end
		end
	end

	-- Live GroupAI often keeps its own groups table. Rewrite that too.
	local st = managers and managers.groupai and managers.groupai:state()
	local live = st and st._tweak_data
	if type(live) == "table" then
		for _, phase in ipairs({ "assault", "recon", "reenforce" }) do
			local weights = live[phase] and live[phase].groups
			if type(weights) == "table" then
				local orig_w = nil
				for _, mode in ipairs({ "besiege", "street", "safehouse" }) do
					local cand = self._mix_weight_orig[mode .. "." .. phase]
					if type(cand) == "table" then
						local hit = false
						for kn, _ in pairs(weights) do
							if cand[kn] ~= nil then
								hit = true
								break
							end
						end
						if hit then
							orig_w = cand
							break
						end
					end
				end
				if orig_w then
					self:WriteMixedWeights(weights, orig_w, groups)
				end
			end
		end
	end
end

function IH:ApplyEnemySpawnTweaks()
	local gai = tweak_data and tweak_data.group_ai
	if not gai then
		return
	end
	self._gai_orig = self._gai_orig or {}
	for _, mode in ipairs({ "besiege", "street", "safehouse" }) do
		local block = gai[mode]
		if type(block) == "table" then
			for _, spec in ipairs(TWEAK_FIELDS) do
				local cat, field, mult_key = spec[1], spec[2], spec[3]
				if block[cat] and block[cat][field] ~= nil then
					local orig_key = mode .. "." .. cat .. "." .. field
					if self._gai_orig[orig_key] == nil then
						self._gai_orig[orig_key] = clone_nums(block[cat][field])
					end
					block[cat][field] = scale_nums(self._gai_orig[orig_key], self:SpawnMult(mult_key))
				end
			end
		end
	end
	if self.ApplySpawnMix then
		self:ApplySpawnMix()
	end
end

function IH:ScaleAssaultSpawnTask(spawn_task)
	if not spawn_task then
		return
	end
	local m = self:SpawnMult("assault_spawn_mult")
	if m <= 1 then
		return
	end
	if type(spawn_task.delay_t) == "number" and not spawn_task._ih_scaled_delay then
		spawn_task.delay_t = math.max(0, spawn_task.delay_t / m)
		spawn_task._ih_scaled_delay = true
	end
	if type(spawn_task.next_check_t) == "number" and not spawn_task._ih_scaled_check then
		spawn_task.next_check_t = math.max(0, spawn_task.next_check_t / m)
		spawn_task._ih_scaled_check = true
	end
	local group = spawn_task.spawn_group
	local pts = group and group.spawn_pts
	if type(pts) ~= "table" then
		return
	end
	for _, sp in ipairs(pts) do
		if type(sp.interval) == "number" then
			if not sp._ih_orig_interval then
				sp._ih_orig_interval = sp.interval
			end
			sp.interval = math.max(0.1, sp._ih_orig_interval / m)
		end
	end
end

if GroupAITweakData then
	Hooks:PostHook(GroupAITweakData, "init", "InstantHeists_GroupAITweak", function()
		if IH.ApplyEnemySpawnTweaks then
			IH:ApplyEnemySpawnTweaks()
		end
	end)
end

if tweak_data and tweak_data.group_ai then
	IH:ApplyEnemySpawnTweaks()
end

if GroupAIStateBesiege then
	if GroupAIStateBesiege._perform_group_spawning then
		Hooks:PreHook(GroupAIStateBesiege, "_perform_group_spawning", "InstantHeists_perform_group_spawn", function(self, spawn_task)
			if IH.ScaleAssaultSpawnTask then
				IH:ScaleAssaultSpawnTask(spawn_task)
			end
		end)
	end
	if GroupAIStateBesiege._upd_group_spawning then
		Hooks:PreHook(GroupAIStateBesiege, "_upd_group_spawning", "InstantHeists_upd_group_spawn", function(self)
			if not IH or not IH.ScaleAssaultSpawnTask or not self._spawning_groups then
				return
			end
			for _, spawn_task in pairs(self._spawning_groups) do
				IH:ScaleAssaultSpawnTask(spawn_task)
			end
		end)
	end
end
