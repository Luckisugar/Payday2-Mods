--[[
	Omniscience+ — track circuit / power boxes that are usable this run.

	Only currently-active interactions. Dummy spawn props (visible but
	never interactable) are ignored. After use (active → inactive) drop.
]]

_G.OmnisciencePlus = _G.OmnisciencePlus or {}
OmnisciencePlus._box_units = OmnisciencePlus._box_units or {}
OmnisciencePlus._box_ever_active = OmnisciencePlus._box_ever_active or {}
OmnisciencePlus._box_done = OmnisciencePlus._box_done or {}

local POWER_BOX_TID = {
	hack_electric_box = true,
	rewire_electric_box = true,
	rewire_friend_fuse_box = true,
	circuit_breaker = true,
	circuit_breaker_off = true,
	hold_circuit_breaker = true,
	hold_hlm_open_circuitbreaker = true,
	transformer_box = true,
	cas_open_powerbox = true,
	open_slash_close_sec_box = true,
}

local function tid_is_box(tid)
	if not tid or type(tid) ~= "string" then
		return false
	end
	if POWER_BOX_TID[tid] then
		return true
	end
	local t = string.lower(tid)
	if string.find(t, "electric_box", 1, true) or string.find(t, "fuse_box", 1, true)
		or string.find(t, "circuit_breaker", 1, true) or string.find(t, "transformer_box", 1, true)
		or string.find(t, "powerbox", 1, true) or string.find(t, "power_box", 1, true)
		or string.find(t, "open_powerbox", 1, true) or string.find(t, "open_circuitbreaker", 1, true)
		or string.find(t, "open_circuit_breaker", 1, true)
		or string.find(t, "open_slash_close_sec_box", 1, true)
		or (string.find(t, "rewire", 1, true) and (string.find(t, "box", 1, true) or string.find(t, "fuse", 1, true))) then
		return true
	end
	return false
end

local function tweak_is_box(tid)
	if not tid or not tweak_data or not tweak_data.interaction then
		return false
	end
	local tw = tweak_data.interaction[tid]
	if not tw then
		return false
	end
	if tw.icon and tostring(tw.icon) == "interaction_powerbox" then
		local text = tw.text_id and string.lower(tostring(tw.text_id)) or ""
		if text == "" then
			return true
		end
		if string.find(text, "circuit", 1, true) or string.find(text, "fuse", 1, true)
			or string.find(text, "rewire", 1, true) or string.find(text, "electric", 1, true)
			or string.find(text, "powerbox", 1, true) or string.find(text, "power_box", 1, true)
			or string.find(text, "transformer", 1, true) or string.find(text, "breaker", 1, true) then
			return true
		end
	end
	return false
end

local function unit_key(unit)
	if not unit then
		return nil
	end
	local ok, key = pcall(function()
		return unit:key()
	end)
	if ok then
		return key
	end
	return nil
end

local function inter_active(inter)
	if not inter then
		return false
	end
	local ok, result = pcall(function()
		if type(inter.active) == "function" then
			return inter:active() and true or false
		end
		if inter._active ~= nil then
			return inter._active and true or false
		end
		return false
	end)
	if ok then
		return result
	end
	return false
end

local function unit_enabled(unit)
	if not unit or not alive(unit) then
		return false
	end
	local en = true
	pcall(function()
		if type(unit.enabled) == "function" then
			en = unit:enabled() and true or false
		end
	end)
	return en
end

local function unit_visible(unit)
	if not unit or not alive(unit) then
		return false
	end
	local vis = true
	pcall(function()
		if type(unit.visible) == "function" then
			vis = unit:visible() and true or false
		end
	end)
	return vis
end

local function is_box_inter(inter)
	if not inter then
		return false
	end
	local tid = inter.tweak_data
	if type(tid) ~= "string" then
		tid = nil
	end
	return tid_is_box(tid) or tweak_is_box(tid)
end

local function mark_done(key)
	if not key then
		return
	end
	OmnisciencePlus._box_done[key] = true
	OmnisciencePlus._box_units[key] = nil
end

local function track(inter)
	if not inter or not inter._unit or not alive(inter._unit) then
		return
	end
	local unit = inter._unit
	local key = unit_key(unit)
	if not key or OmnisciencePlus._box_done[key] then
		return
	end

	if not is_box_inter(inter) then
		if OmnisciencePlus._box_units[key] or OmnisciencePlus._box_ever_active[key] then
			mark_done(key)
		end
		return
	end

	if not unit_enabled(unit) or not unit_visible(unit) then
		OmnisciencePlus._box_units[key] = nil
		return
	end

	if inter_active(inter) then
		OmnisciencePlus._box_ever_active[key] = true
		OmnisciencePlus._box_units[key] = unit
		return
	end

	-- Inactive: dummy spawn, or already used. Never tag never-active slots.
	if OmnisciencePlus._box_ever_active[key] then
		mark_done(key)
		return
	end
	OmnisciencePlus._box_units[key] = nil
end

if BaseInteractionExt then
	Hooks:PostHook(BaseInteractionExt, "init", "OmnisciencePlus_BoxTrack_Init", function(self)
		track(self)
	end)
	Hooks:PostHook(BaseInteractionExt, "set_tweak_data", "OmnisciencePlus_BoxTrack_Tweak", function(self, id)
		track(self)
	end)
	Hooks:PostHook(BaseInteractionExt, "set_active", "OmnisciencePlus_BoxTrack_Active", function(self, active)
		track(self)
	end)
	Hooks:PostHook(BaseInteractionExt, "destroy", "OmnisciencePlus_BoxTrack_Destroy", function(self)
		if self._unit then
			local key = unit_key(self._unit)
			if key then
				mark_done(key)
			end
		end
	end)
end
