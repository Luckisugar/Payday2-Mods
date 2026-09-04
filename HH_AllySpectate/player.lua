--[[
	Ally Spectate — camera apply + freeze local movement while watching.
]]

if not _G.AllySpectate or not AllySpectate.Load then
	dofile(ModPath .. "core.lua")
end

local AS = AllySpectate

-- Apply spectate camera after local FP camera update so we win the last write.
if FPCameraPlayerBase then
	Hooks:PostHook(FPCameraPlayerBase, "update", "AllySpectate_FPCamUpdate", function(self, unit, t, dt)
		if not AS.active then
			return
		end
		AS:apply_camera()
	end)

	Hooks:PostHook(FPCameraPlayerBase, "_update_rot", "AllySpectate_FPCamRot", function(self, ...)
		if not AS.active then
			return
		end
		AS:apply_camera()
	end)
end

-- Also tick from player standard in case camera path differs (vehicles etc.)
if PlayerStandard then
	Hooks:PostHook(PlayerStandard, "update", "AllySpectate_PlayerStandardUpdate", function(self, t, dt)
		if not AS.active then
			return
		end
		AS:apply_camera()

		if AS.settings.freeze_local then
			if self._stick_move then
				mvector3.set_static(self._stick_move, 0, 0, 0)
			end
			self._move_dir = nil
			self._normal_move_dir = nil
		end
	end)

	-- Block shooting / interactions while spectating so you do not fire blind
	Hooks:PostHook(PlayerStandard, "_check_action_primary_attack", "AllySpectate_BlockShoot", function(self, t, input)
		if AS.active then
			return false
		end
	end)
end

-- Carry / other common states
local function freeze_state_update(self, t, dt)
	if not AS.active then
		return
	end
	AS:apply_camera()
	if AS.settings.freeze_local and self._stick_move then
		mvector3.set_static(self._stick_move, 0, 0, 0)
	end
end

if PlayerCarry then
	Hooks:PostHook(PlayerCarry, "update", "AllySpectate_PlayerCarryUpdate", freeze_state_update)
end

if PlayerMaskOff then
	Hooks:PostHook(PlayerMaskOff, "update", "AllySpectate_PlayerMaskOffUpdate", freeze_state_update)
end

if PlayerBleedOut then
	Hooks:PostHook(PlayerBleedOut, "update", "AllySpectate_BleedOutExit", function(self, t, dt)
		if AS.active then
			AS:stop("you went down")
		end
	end)
end

if PlayerFatal then
	Hooks:PostHook(PlayerFatal, "enter", "AllySpectate_FatalExit", function(self, ...)
		if AS.active then
			AS:stop("fatal")
		end
	end)
end

if PlayerIncapacitated then
	Hooks:PostHook(PlayerIncapacitated, "enter", "AllySpectate_IncapExit", function(self, ...)
		if AS.active then
			AS:stop("incapacitated")
		end
	end)
end

if PlayerTased then
	Hooks:PostHook(PlayerTased, "enter", "AllySpectate_TasedExit", function(self, ...)
		if AS.active then
			AS:stop("tased")
		end
	end)
end

-- Damage auto-exit
if PlayerDamage then
	Hooks:PostHook(PlayerDamage, "damage_bullet", "AllySpectate_DmgBullet", function(self, ...)
		if AS.active and AS.settings.auto_exit_on_damage then
			AS:stop("you took damage")
		end
	end)
	Hooks:PostHook(PlayerDamage, "damage_explosion", "AllySpectate_DmgExpl", function(self, ...)
		if AS.active and AS.settings.auto_exit_on_damage then
			AS:stop("you took damage")
		end
	end)
	Hooks:PostHook(PlayerDamage, "damage_fire", "AllySpectate_DmgFire", function(self, ...)
		if AS.active and AS.settings.auto_exit_on_damage then
			AS:stop("you took damage")
		end
	end)
	Hooks:PostHook(PlayerDamage, "damage_melee", "AllySpectate_DmgMelee", function(self, ...)
		if AS.active and AS.settings.auto_exit_on_damage then
			AS:stop("you took damage")
		end
	end)
	Hooks:PostHook(PlayerDamage, "damage_tase", "AllySpectate_DmgTase", function(self, ...)
		if AS.active and AS.settings.auto_exit_on_damage then
			AS:stop("you took damage")
		end
	end)
end

-- Clean exit on heist end / leave
if GameSetup then
	Hooks:PostHook(GameSetup, "paused_update", "AllySpectate_Paused", function(self, t, dt)
		if AS.active then
			AS:apply_camera()
		end
	end)
end

Hooks:Add("GameSetupOnQuitGame", "AllySpectate_Quit", function()
	if AS.active then
		AS:stop("quit")
	end
end)
