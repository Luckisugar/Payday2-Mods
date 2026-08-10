--[[
	Auto Skill Sets — core logic
	Save skill builds, auto-spend on level-up, restore after infamy.
]]

if _G.AutoSkillSets and AutoSkillSets._core_loaded then
	return
end

_G.AutoSkillSets = _G.AutoSkillSets or {}
local ASS = AutoSkillSets
ASS._core_loaded = true
ASS._path = ASS._path or ModPath
ASS._data_path = ASS._data_path or (SavePath .. "auto_skill_sets.txt")
ASS.SLOT_COUNT = 8

function ASS:DefaultSettings()
	return {
		enabled = true,
		auto_spend = true,
		infamy_prompt = true,
		block_mid_heist = true,
		edit_cheat = false,
		active_slot = 1,
		cheat_level = 100,
		cheat_infamy = 0,
		cheat_skill_points = 120,
		builds = {}
	}
end

function ASS:EmptyBuild()
	return {
		empty = true,
		name = "",
		skills = {},
		priority = {},
		skill_switch = 1,
		saved_at = ""
	}
end

function ASS:EnsureBuilds()
	self.settings = self.settings or self:DefaultSettings()
	self.settings.builds = self.settings.builds or {}

	for i = 1, self.SLOT_COUNT do
		local key = tostring(i)
		if type(self.settings.builds[key]) ~= "table" then
			self.settings.builds[key] = self:EmptyBuild()
			self.settings.builds[key].name = "Slot " .. i
		end
	end

	local slot = tonumber(self.settings.active_slot) or 1
	self.settings.active_slot = math.max(1, math.min(self.SLOT_COUNT, math.floor(slot)))
end

function ASS:Load()
	self.settings = self:DefaultSettings()
	local file = io.open(self._data_path, "r")
	if file then
		local raw = file:read("*all")
		file:close()
		local ok, data = pcall(json.decode, raw)
		if ok and type(data) == "table" then
			for k, v in pairs(data) do
				self.settings[k] = v
			end
		end
	end
	self:EnsureBuilds()
end

function ASS:Save()
	self:EnsureBuilds()
	local file = io.open(self._data_path, "w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

function ASS:ActiveBuild()
	self:EnsureBuilds()
	local key = tostring(self.settings.active_slot)
	return self.settings.builds[key]
end

function ASS:SlotLabel(i)
	local b = self.settings.builds[tostring(i)]
	if b and not b.empty and b.saved_at and b.saved_at ~= "" then
		return string.format("Slot %d (%s)", i, b.saved_at)
	end
	return string.format("Slot %d (empty)", i)
end

function ASS:SystemMsg(msg)
	local text = "[Auto Skill Sets] " .. tostring(msg)
	if log then
		log(text)
	end
	if managers and managers.chat and managers.chat._receive_message then
		local name = "SYSTEM"
		if managers.localization and managers.localization.to_upper_text then
			local ok, loc = pcall(function()
				return managers.localization:to_upper_text("menu_system_message")
			end)
			if ok and loc and loc ~= "" then
				name = loc
			end
		end
		local color = Color(1, 1, 0.8, 0.2)
		if tweak_data and tweak_data.system_chat_color then
			color = tweak_data.system_chat_color
		end
		local channel = (ChatManager and ChatManager.GAME) or 1
		pcall(function()
			managers.chat:_receive_message(channel, name, text, color)
		end)
	end
end

function ASS:InHeist()
	if Utils and Utils.IsInHeist then
		local ok, res = pcall(function()
			return Utils:IsInHeist()
		end)
		if ok then
			return res and true or false
		end
	end
	if managers and managers.player and managers.player.player_unit then
		local unit = managers.player:player_unit()
		if unit and alive and alive(unit) then
			return true
		end
	end
	return false
end

function ASS:CanAutoApply()
	if not self.settings or not self.settings.enabled then
		return false
	end
	if self.settings.block_mid_heist and self:InHeist() then
		return false
	end
	if not managers or not managers.skilltree then
		return false
	end
	return true
end

function ASS:FindSkill(skill_id)
	if not tweak_data or not tweak_data.skilltree or not tweak_data.skilltree.trees then
		return nil, nil
	end
	for tree, tree_data in ipairs(tweak_data.skilltree.trees) do
		if tree_data.tiers then
			for tier, tier_skills in ipairs(tree_data.tiers) do
				for _, sid in ipairs(tier_skills) do
					if sid == skill_id then
						return tree, tier
					end
				end
			end
		end
	end
	return nil, nil
end

function ASS:SkillDisplayName(skill_id)
	if not tweak_data or not tweak_data.skilltree or not tweak_data.skilltree.skills then
		return skill_id
	end
	local data = tweak_data.skilltree.skills[skill_id]
	if not data then
		return skill_id
	end
	local name_id = data.name_id
	if not name_id and data[1] then
		name_id = data[1].name_id
	end
	if name_id and managers.localization then
		local ok, text = pcall(function()
			return managers.localization:text(name_id)
		end)
		if ok and text and text ~= "" then
			return text
		end
	end
	return skill_id
end

function ASS:CaptureCurrent()
	local st = managers.skilltree
	if not st or not st._global or not st._global.skills then
		return nil
	end

	local skills = {}
	for skill_id, data in pairs(st._global.skills) do
		local unlocked = data.unlocked or 0
		if unlocked > 0 then
			skills[skill_id] = unlocked
		end
	end

	local priority = {}
	if tweak_data and tweak_data.skilltree and tweak_data.skilltree.trees then
		for _, tree_data in ipairs(tweak_data.skilltree.trees) do
			if tree_data.tiers then
				for _, tier_skills in ipairs(tree_data.tiers) do
					for _, skill_id in ipairs(tier_skills) do
						if skills[skill_id] then
							table.insert(priority, skill_id)
						end
					end
				end
			end
		end
	end

	local switch = 1
	if st.get_selected_skill_switch then
		switch = st:get_selected_skill_switch() or 1
	end

	return {
		empty = false,
		name = "Slot " .. tostring(self.settings.active_slot),
		skills = skills,
		priority = priority,
		skill_switch = switch,
		saved_at = os.date("%Y-%m-%d %H:%M")
	}
end

function ASS:SaveCurrentIntoActive()
	if not managers or not managers.skilltree then
		self:SystemMsg("Cannot save — skill tree not ready.")
		return false
	end
	local snap = self:CaptureCurrent()
	if not snap then
		self:SystemMsg("Cannot save — no skill data.")
		return false
	end
	self:EnsureBuilds()
	local key = tostring(self.settings.active_slot)
	snap.name = "Slot " .. key
	self.settings.builds[key] = snap
	self:Save()
	local count = 0
	for _ in pairs(snap.skills) do
		count = count + 1
	end
	self:SystemMsg(string.format("Saved %d skills into %s.", count, self:SlotLabel(self.settings.active_slot)))
	return true
end

function ASS:DeleteActive()
	self:EnsureBuilds()
	local key = tostring(self.settings.active_slot)
	self.settings.builds[key] = self:EmptyBuild()
	self.settings.builds[key].name = "Slot " .. key
	self:Save()
	self:SystemMsg("Cleared " .. self:SlotLabel(self.settings.active_slot) .. ".")
end

function ASS:BuildOrder(build)
	local target = build.skills or {}
	local order = {}
	local seen = {}

	for _, skill_id in ipairs(build.priority or {}) do
		if target[skill_id] and not seen[skill_id] then
			table.insert(order, skill_id)
			seen[skill_id] = true
		end
	end

	if tweak_data and tweak_data.skilltree and tweak_data.skilltree.trees then
		for _, tree_data in ipairs(tweak_data.skilltree.trees) do
			if tree_data.tiers then
				for _, tier_skills in ipairs(tree_data.tiers) do
					for _, skill_id in ipairs(tier_skills) do
						if target[skill_id] and not seen[skill_id] then
							table.insert(order, skill_id)
							seen[skill_id] = true
						end
					end
				end
			end
		end
	end

	for skill_id, _ in pairs(target) do
		if not seen[skill_id] then
			table.insert(order, skill_id)
			seen[skill_id] = true
		end
	end

	return order
end

function ASS:InvestOne(skill_id, cheat)
	local st = managers.skilltree
	local tree, tier = self:FindSkill(skill_id)
	if not tree or not tier then
		return false, "unknown"
	end

	if not st:skill_unlocked(tree, skill_id) then
		return false, "tier_locked"
	end

	local skill_state = st._global.skills[skill_id]
	if not skill_state then
		return false, "missing_state"
	end

	local current = skill_state.unlocked or 0
	local total = skill_state.total or 0
	if current >= total then
		return false, "maxed"
	end

	local next_step = current + 1
	local cost = st:skill_cost(tier, next_step)
	if not cost or cost < 0 then
		return false, "bad_cost"
	end

	local pts = st:points()
	if pts < cost then
		if not cheat then
			return false, "no_points"
		end
		st:_set_points(cost)
	end

	if not st:unlock(skill_id) then
		return false, "unlock_failed"
	end

	local step = st:skill_step(skill_id)
	local spent = st:skill_cost(tier, step)
	st:spend_points(spent)
	st:_set_points_spent(tree, st:points_spent(tree) + spent)

	return true, spent
end

function ASS:ApplyBuild(build, cheat, silent)
	if not build or build.empty or not build.skills or not next(build.skills) then
		if not silent then
			self:SystemMsg("Active slot is empty — save a build first.")
		end
		return false, 0, 0
	end

	if not managers or not managers.skilltree then
		if not silent then
			self:SystemMsg("Skill tree not ready.")
		end
		return false, 0, 0
	end

	local order = self:BuildOrder(build)
	local steps = 0
	local points_spent = 0
	local changed = true
	local guard = 0

	while changed and guard < 500 do
		changed = false
		guard = guard + 1
		for _, skill_id in ipairs(order) do
			local want = tonumber(build.skills[skill_id]) or 0
			local have = managers.skilltree:skill_step(skill_id) or 0
			while have < want do
				local ok, spent_or_err = self:InvestOne(skill_id, cheat)
				if ok then
					steps = steps + 1
					points_spent = points_spent + (tonumber(spent_or_err) or 0)
					changed = true
					have = managers.skilltree:skill_step(skill_id) or have + 1
				else
					break
				end
			end
		end
	end

	if managers.menu_component and managers.menu_component._update_outfit_information then
		pcall(function()
			MenuCallbackHandler:_update_outfit_information()
		end)
	elseif MenuCallbackHandler and MenuCallbackHandler._update_outfit_information then
		pcall(function()
			MenuCallbackHandler:_update_outfit_information()
		end)
	end

	if SystemInfo and SystemInfo.distribution and Idstring and managers.statistics and managers.statistics.publish_skills_to_steam then
		pcall(function()
			if SystemInfo:distribution() == Idstring("STEAM") then
				managers.statistics:publish_skills_to_steam()
			end
		end)
	end

	if managers.savefile and managers.savefile.save_progress then
		pcall(function()
			managers.savefile:save_progress()
		end)
	end

	return true, steps, points_spent
end

function ASS:TryApply(cheat, reason)
	if not self.settings.enabled and not cheat then
		return
	end

	if self.settings.block_mid_heist and self:InHeist() then
		if reason ~= "manual" then
			return
		end
		self:SystemMsg("Blocked mid-heist. Leave the heist or disable the safety option.")
		return
	end

	local build = self:ActiveBuild()
	if not build or build.empty then
		if reason == "manual" or reason == "infamy" then
			self:SystemMsg("No saved build in the active slot.")
		end
		return
	end

	local ok, steps, spent = self:ApplyBuild(build, cheat and true or false, false)
	if not ok then
		return
	end

	if steps > 0 then
		local mode = cheat and "cheat restore" or "auto-spend"
		self:SystemMsg(string.format("%s: unlocked %d step(s), spent %d point(s). [%s]", mode, steps, spent, reason or "apply"))
	elseif reason == "manual" or reason == "infamy" then
		self:SystemMsg("Nothing to apply — already matches, or tiers/points blocked.")
	end
end

function ASS:DiffActive()
	local build = self:ActiveBuild()
	if not build or build.empty or not build.skills or not next(build.skills) then
		self:SystemMsg("Active slot empty — nothing to diff.")
		QuickMenu:new("Auto Skill Sets — Diff", "Active slot is empty. Save a build first.", {
			{ text = "OK", is_cancel_button = true }
		}, true)
		return
	end

	if not managers or not managers.skilltree then
		self:SystemMsg("Skill tree not ready.")
		return
	end

	local owned, partial, missing = {}, {}, {}
	for skill_id, want in pairs(build.skills) do
		want = tonumber(want) or 0
		local have = managers.skilltree:skill_step(skill_id) or 0
		local label = self:SkillDisplayName(skill_id)
		if have >= want then
			table.insert(owned, label)
		elseif have > 0 then
			table.insert(partial, string.format("%s (%d/%d)", label, have, want))
		else
			table.insert(missing, string.format("%s (0/%d)", label, want))
		end
	end

	table.sort(owned)
	table.sort(partial)
	table.sort(missing)

	local summary = string.format("Owned %d · Partial %d · Missing %d", #owned, #partial, #missing)
	self:SystemMsg("Diff — " .. summary)

	local function join_max(list, max_n)
		if #list == 0 then
			return "(none)"
		end
		local out = {}
		for i = 1, math.min(#list, max_n) do
			table.insert(out, list[i])
		end
		local s = table.concat(out, ", ")
		if #list > max_n then
			s = s .. string.format(" … +%d more", #list - max_n)
		end
		return s
	end

	local body = summary
		.. "\n\nPartial: "
		.. join_max(partial, 12)
		.. "\n\nMissing: "
		.. join_max(missing, 12)

	QuickMenu:new("Auto Skill Sets — Diff", body, {
		{ text = "OK", is_cancel_button = true }
	}, true)
end

function ASS:RequireEditCheat()
	if not self.settings.edit_cheat then
		self:SystemMsg("Turn on Edit (Cheat) first.")
		QuickMenu:new("Auto Skill Sets", "Enable Edit (Cheat) in Mod Options before using these controls.", {
			{ text = "OK", is_cancel_button = true }
		}, true)
		return false
	end
	return true
end

function ASS:ApplyCheatLevel()
	if not self:RequireEditCheat() then
		return
	end
	if not managers or not managers.experience then
		self:SystemMsg("Experience manager not ready.")
		return
	end
	local level = math.floor(tonumber(self.settings.cheat_level) or 0)
	level = math.max(0, math.min(managers.experience:level_cap() or 100, level))
	managers.experience:_set_current_level(level)
	if managers.experience._set_next_level_data then
		local next_lv = math.min(level + 1, managers.experience:level_cap() or 100)
		pcall(function()
			managers.experience:_set_next_level_data(next_lv)
		end)
	end
	if managers.savefile and managers.savefile.save_progress then
		pcall(function()
			managers.savefile:save_progress()
		end)
	end
	self:SystemMsg("Level set to " .. tostring(level) .. ".")
end

function ASS:ApplyCheatInfamy()
	if not self:RequireEditCheat() then
		return
	end
	if not managers or not managers.experience then
		self:SystemMsg("Experience manager not ready.")
		return
	end
	local rank = math.floor(tonumber(self.settings.cheat_infamy) or 0)
	local max_rank = 500
	if tweak_data and tweak_data.infamy and tweak_data.infamy.ranks then
		max_rank = tweak_data.infamy.ranks
	end
	rank = math.max(0, math.min(max_rank, rank))
	-- set_current_rank only applies when value <= max; it also aquires an infamy point
	managers.experience:set_current_rank(rank)
	if managers.savefile and managers.savefile.save_progress then
		pcall(function()
			managers.savefile:save_progress()
		end)
	end
	self:SystemMsg("Infamy set to " .. tostring(rank) .. ". Restart may be needed for some UI.")
end

function ASS:ApplyCheatSkillPoints()
	if not self:RequireEditCheat() then
		return
	end
	if not managers or not managers.skilltree then
		self:SystemMsg("Skill tree not ready.")
		return
	end
	local pts = math.floor(tonumber(self.settings.cheat_skill_points) or 0)
	pts = math.max(0, math.min(500, pts))
	managers.skilltree:_set_points(pts)
	if managers.savefile and managers.savefile.save_progress then
		pcall(function()
			managers.savefile:save_progress()
		end)
	end
	self:SystemMsg("Skill points set to " .. tostring(pts) .. ".")
end

function ASS:ShowInfamyPrompt()
	if not self.settings.enabled then
		return
	end
	if not self.settings.infamy_prompt then
		if self.settings.auto_spend then
			self:TryApply(false, "infamy")
		end
		return
	end

	local build = self:ActiveBuild()
	local slot_info = self:SlotLabel(self.settings.active_slot)
	if not build or build.empty then
		self:SystemMsg("Infamy reset — active slot empty, nothing to restore.")
		return
	end

	local function delayed()
		QuickMenu:new(
			"Auto Skill Sets",
			"Infamy reset your skills.\nRestore " .. slot_info .. "?",
			{
				{
					text = "Yes",
					callback = function()
						ASS:TryApply(false, "infamy")
					end
				},
				{
					text = "No",
					is_cancel_button = true
				},
				{
					text = "Restore Skills (Cheat)",
					callback = function()
						ASS:TryApply(true, "infamy")
					end
				}
			},
			true
		)
	end

	if DelayedCalls and DelayedCalls.Add then
		DelayedCalls:Add("AutoSkillSets_infamy_prompt", 0.75, delayed)
	else
		delayed()
	end
end

function ASS:OnPointsGained()
	if not self.settings.enabled or not self.settings.auto_spend then
		return
	end
	if not self:CanAutoApply() then
		return
	end
	-- slight delay so level-up cascade finishes
	local function run()
		ASS:TryApply(false, "level_up")
	end
	if DelayedCalls and DelayedCalls.Add then
		DelayedCalls:Add("AutoSkillSets_autospend", 0.35, run)
	else
		run()
	end
end

ASS:Load()

-- Hooks (skill tree)
if not ASS._hooks_skilltree then
	ASS._hooks_skilltree = true

	if SkillTreeManager then
		Hooks:PostHook(SkillTreeManager, "infamy_reset", "AutoSkillSets_infamy_reset", function(self)
			ASS:ShowInfamyPrompt()
		end)

		Hooks:PostHook(SkillTreeManager, "level_up", "AutoSkillSets_level_up", function(self)
			ASS:OnPointsGained()
		end)

		Hooks:PostHook(SkillTreeManager, "_aquire_points", "AutoSkillSets_aquire_points", function(self, points, selected_only)
			if points and points > 0 then
				ASS:OnPointsGained()
			end
		end)
	end
end

-- Experience hooks reserved for future; level set uses manager methods directly.
if not ASS._hooks_experience then
	ASS._hooks_experience = true
end
