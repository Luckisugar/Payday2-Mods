--[[
	Loot Mule — stash: keep the bag, walk/run/jump like you are empty-handed.
	Stays in PlayerCarry so G still throws and vans still secure.
]]

if not LootMule or not LootMule.Load then
	dofile(ModPath .. "core.lua")
end

local LM = LootMule

if not PlayerCarry or LM._playercarry_wrapped then
	return
end
LM._playercarry_wrapped = true

local master_enter = PlayerCarry.enter
local master_run = PlayerCarry._check_action_run
local master_jump = PlayerCarry._perform_jump
local master_walk = PlayerCarry._get_max_walk_speed
local master_bob = PlayerCarry._get_walk_headbob

function PlayerCarry:enter(state_data, enter_data)
	master_enter(self, state_data, enter_data)
	if LM.ApplyStashFeel then
		LM:ApplyStashFeel()
	end
end

function PlayerCarry:_check_action_run(...)
	if LM:IsStashOn() then
		return PlayerCarry.super._check_action_run(self, ...)
	end
	return master_run(self, ...)
end

function PlayerCarry:_perform_jump(jump_vec, ...)
	if LM:IsStashOn() then
		return PlayerCarry.super._perform_jump(self, jump_vec, ...)
	end
	return master_jump(self, jump_vec, ...)
end

function PlayerCarry:_get_max_walk_speed(...)
	if LM:IsStashOn() then
		return PlayerCarry.super._get_max_walk_speed(self, ...)
	end
	return master_walk(self, ...)
end

function PlayerCarry:_get_walk_headbob(...)
	if LM:IsStashOn() then
		return PlayerCarry.super._get_walk_headbob(self, ...)
	end
	return master_bob(self, ...)
end
