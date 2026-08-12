--[[
	Instant Heists — Ghost Mode

	When enabled: AI, cameras, and suspicion never "see" you. You can stand
	on a guard — no detection meter, no camera alarm, no weapons-hot from
	being spotted.

	Does not auto-complete stealth objectives; only kills detection of you.
	Still host-synced for multiplayer (clients with Ghost on only protect themselves
	for local hooks; host-side GroupAI is authoritative for many alarms).
]]

if not InstantHeists or not InstantHeists.Load then
	dofile(ModPath .. "core.lua")
end

local IH = InstantHeists

local function ghost()
	return IH and IH.GhostOn and IH:GhostOn()
end

-- ---------------------------------------------------------------------------
-- Player suspicion / uncover
-- ---------------------------------------------------------------------------

if PlayerMovement then
	local orig_suspicion = PlayerMovement.on_suspicion
	function PlayerMovement:on_suspicion(observer_unit, status)
		if ghost() then
			return
		end
		return orig_suspicion(self, observer_unit, status)
	end

	local orig_uncovered = PlayerMovement.on_uncovered
	function PlayerMovement:on_uncovered(enemy_unit)
		if ghost() then
			return
		end
		return orig_uncovered(self, enemy_unit)
	end
end

-- ---------------------------------------------------------------------------
-- Group AI: spotted criminal, aggression, police called / weapons hot
-- ---------------------------------------------------------------------------

if GroupAIStateBase then
	local orig_spotted = GroupAIStateBase.criminal_spotted
	function GroupAIStateBase:criminal_spotted(unit)
		if ghost() then
			return
		end
		return orig_spotted(self, unit)
	end

	local orig_agg = GroupAIStateBase.report_aggression
	function GroupAIStateBase:report_aggression(unit)
		if ghost() then
			return
		end
		return orig_agg(self, unit)
	end

	local orig_sus_prog = GroupAIStateBase.on_criminal_suspicion_progress
	function GroupAIStateBase:on_criminal_suspicion_progress(u_suspect, u_observer, status)
		if ghost() then
			return
		end
		return orig_sus_prog(self, u_suspect, u_observer, status)
	end

	local orig_switch = GroupAIStateBase._clbk_switch_enemies_to_not_cool
	function GroupAIStateBase:_clbk_switch_enemies_to_not_cool()
		if ghost() then
			return
		end
		return orig_switch(self)
	end

	local orig_police_called = GroupAIStateBase.on_police_called
	function GroupAIStateBase:on_police_called(called_reason)
		if ghost() then
			return
		end
		return orig_police_called(self, called_reason)
	end

	local orig_police_hot = GroupAIStateBase.on_police_weapons_hot
	function GroupAIStateBase:on_police_weapons_hot(called_reason)
		if ghost() then
			return
		end
		return orig_police_hot(self, called_reason)
	end

	local orig_gangster_hot = GroupAIStateBase.on_gangster_weapons_hot
	function GroupAIStateBase:on_gangster_weapons_hot(called_reason)
		if ghost() then
			return
		end
		return orig_gangster_hot(self, called_reason)
	end

	local orig_enemy_hot = GroupAIStateBase.on_enemy_weapons_hot
	function GroupAIStateBase:on_enemy_weapons_hot(is_delayed_callback)
		if ghost() then
			return
		end
		return orig_enemy_hot(self, is_delayed_callback)
	end

	if GroupAIStateBase.sync_event then
		local orig_sync = GroupAIStateBase.sync_event
		function GroupAIStateBase:sync_event(event_id, blame_id)
			if ghost() then
				return
			end
			return orig_sync(self, event_id, blame_id)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Security cameras
-- ---------------------------------------------------------------------------

if SecurityCamera then
	local orig_upd_sus = SecurityCamera._upd_suspicion
	function SecurityCamera:_upd_suspicion(t)
		if ghost() then
			return
		end
		return orig_upd_sus(self, t)
	end

	local orig_alarm = SecurityCamera._sound_the_alarm
	function SecurityCamera:_sound_the_alarm(detected_unit)
		if ghost() then
			return
		end
		return orig_alarm(self, detected_unit)
	end

	local orig_sus_sound = SecurityCamera._set_suspicion_sound
	function SecurityCamera:_set_suspicion_sound(suspicion_level)
		if ghost() then
			return
		end
		return orig_sus_sound(self, suspicion_level)
	end

	if SecurityCamera.clbk_call_the_police then
		local orig_cam_call = SecurityCamera.clbk_call_the_police
		function SecurityCamera:clbk_call_the_police()
			if ghost() then
				return
			end
			return orig_cam_call(self)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Cop movement / logics — never escalate from detecting you
-- ---------------------------------------------------------------------------

if CopMovement and CopMovement.anim_clbk_police_called then
	local orig_anim = CopMovement.anim_clbk_police_called
	function CopMovement:anim_clbk_police_called(unit)
		if ghost() then
			return
		end
		return orig_anim(self, unit)
	end
end

if CopLogicArrest then
	if CopLogicArrest._upd_enemy_detection then
		local orig_det = CopLogicArrest._upd_enemy_detection
		function CopLogicArrest._upd_enemy_detection(data)
			if ghost() then
				return
			end
			return orig_det(data)
		end
	end
	if CopLogicArrest._call_the_police then
		local orig_call = CopLogicArrest._call_the_police
		function CopLogicArrest._call_the_police(data, my_data, paniced)
			if ghost() then
				return
			end
			return orig_call(data, my_data, paniced)
		end
	end
end

if CopLogicIdle and CopLogicIdle.on_alert then
	local orig_alert = CopLogicIdle.on_alert
	function CopLogicIdle.on_alert(data, alert_data)
		if ghost() then
			return
		end
		return orig_alert(data, alert_data)
	end
end

if CopLogicBase and CopLogicBase._get_logic_state_from_reaction then
	local orig_react = CopLogicBase._get_logic_state_from_reaction
	function CopLogicBase._get_logic_state_from_reaction(data, reaction)
		if ghost() then
			return "idle"
		end
		return orig_react(data, reaction)
	end
end

if log then
	log("[InstantHeists] ghost.lua loaded — Ghost Mode hooks ready")
end
