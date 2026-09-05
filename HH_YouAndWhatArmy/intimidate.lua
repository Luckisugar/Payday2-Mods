--[[
	You and What Army — Max Threat / Insta-recruit / resist-lock skip.
	Same file is hooked on CopLogicIdle, CopLogicIntimidated, and CopBrain.
]]

if not YouAndWhatArmy or not YouAndWhatArmy.Load then
	dofile(ModPath .. "core.lua")
end

local YAWA = YouAndWhatArmy
local req = tostring(RequiredScript or ""):gsub("\\", "/"):lower()

local function aggressor_is_foe(data, aggressor_unit)
	if not alive(aggressor_unit) then
		return false
	end
	local ok, foe = pcall(function()
		return aggressor_unit:movement():team().foes[data.unit:movement():team().id]
	end)
	return ok and foe and true or false
end

local function mark_attention(data, aggressor_unit)
	if not alive(aggressor_unit) then
		return
	end
	if CopLogicBase and CopLogicBase.identify_attention_obj_instant then
		CopLogicBase.identify_attention_obj_instant(data, aggressor_unit:key())
	end
	local gas = managers.groupai and managers.groupai:state()
	if gas and type(gas.criminal_spotted) == "function" then
		pcall(gas.criminal_spotted, gas, aggressor_unit)
	end
end

local function force_tie(data, aggressor_unit)
	local my_data = data.internal_data
	if not my_data or my_data.tied then
		return
	end
	local action_data = {
		clamp_to_graph = true,
		type = "act",
		body_part = 1,
		variant = "tied_all_in_one",
		blocks = {
			heavy_hurt = -1,
			hurt = -1,
			action = -1,
			light_hurt = -1,
			walk = -1
		}
	}
	pcall(function()
		data.unit:brain():action_request(action_data)
	end)
	if CopLogicIntimidated and CopLogicIntimidated._do_tied then
		pcall(CopLogicIntimidated._do_tied, data, aggressor_unit)
	end
	data.yawa_instant_tie = nil
end

if req:find("coplogicidle", 1, true) and not req:find("coplogicintimidated", 1, true) then
	if not YAWA._hooked_idle and CopLogicIdle and CopLogicIdle.on_intimidated then
		YAWA._hooked_idle = true
		local orig = CopLogicIdle.on_intimidated
		function CopLogicIdle.on_intimidated(data, amount, aggressor_unit)
			if not YAWA:FeatureOn() or not YAWA:CanDominate(data) or not aggressor_is_foe(data, aggressor_unit) then
				return orig(data, amount, aggressor_unit)
			end
			if not YAWA:AggressorAllowed(aggressor_unit) then
				return orig(data, amount, aggressor_unit)
			end

			if YAWA:TryConvert(data.unit, aggressor_unit) then
				mark_attention(data, aggressor_unit)
				return true
			end

			if YAWA:ShouldInstantCuff(aggressor_unit) then
				local gas = managers.groupai and managers.groupai:state()
				local room = true
				if gas and type(gas.has_room_for_police_hostage) == "function" then
					local ok, has_room = pcall(gas.has_room_for_police_hostage, gas)
					room = not ok or has_room
				end
				if room then
					data.yawa_instant_tie = true
					CopLogicIdle._surrender(data, amount, aggressor_unit)
					mark_attention(data, aggressor_unit)
					return true
				end
			end

			return orig(data, amount, aggressor_unit)
		end
	end
elseif req:find("coplogicintimidated", 1, true) then
	if not YAWA._hooked_intimidated and CopLogicIntimidated then
		YAWA._hooked_intimidated = true
		local orig_on = CopLogicIntimidated.on_intimidated
		function CopLogicIntimidated.on_intimidated(data, amount, aggressor_unit)
			if YAWA:FeatureOn() and YAWA:AggressorAllowed(aggressor_unit) then
				if YAWA:TryConvert(data.unit, aggressor_unit) then
					return
				end
				if data.yawa_instant_tie or YAWA:ShouldInstantCuff(aggressor_unit) then
					force_tie(data, aggressor_unit)
					YAWA:TryConvert(data.unit, aggressor_unit)
					return
				end
			end
			return orig_on(data, amount, aggressor_unit)
		end

		local orig_hands = CopLogicIntimidated._start_action_hands_up
		function CopLogicIntimidated._start_action_hands_up(data)
			if data.yawa_instant_tie then
				local my_data = data.internal_data
				local action_data = {
					clamp_to_graph = true,
					type = "act",
					body_part = 1,
					variant = "tied_all_in_one",
					blocks = {
						light_hurt = -1,
						hurt = -1,
						heavy_hurt = -1,
						walk = -1
					}
				}
				my_data.act_action = data.unit:brain():action_request(action_data)
				pcall(CopLogicIntimidated._do_tied, data, my_data.aggressor_unit)
				data.yawa_instant_tie = nil
				return
			end
			return orig_hands(data)
		end
	end
elseif req:find("copbrain", 1, true) then
	if not YAWA._hooked_brain and CopBrain and CopBrain.on_surrender_chance then
		YAWA._hooked_brain = true
		local orig = CopBrain.on_surrender_chance
		function CopBrain:on_surrender_chance()
			if YAWA:NoYellCooldownOn() then
				local window = self._logic_data and self._logic_data.surrender_window
				if window and window.expire_clbk_id then
					pcall(function()
						managers.enemy:remove_delayed_clbk(window.expire_clbk_id)
					end)
				end
				if self._logic_data then
					self._logic_data.surrender_window = nil
				end
				return
			end
			return orig(self)
		end
	end
end
