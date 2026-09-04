--[[
	Collect on kill: if this cop would drop an ammo box and we got the kill,
	apply a virtual box pickup and do not leave the box on the floor.
]]

_G.BigAmmoPickups = _G.BigAmmoPickups or {}
local BAP = BigAmmoPickups

local function _local_player()
	return managers.player and managers.player:player_unit()
end

local function _is_local_killer(attack_data)
	local att = attack_data and attack_data.attacker_unit
	if not alive(att) then
		return false
	end
	local me = _local_player()
	if not alive(me) then
		return false
	end
	if att == me then
		return true
	end
	local base = att:base()
	if base then
		if base.thrower_unit then
			local thrower = base:thrower_unit()
			if thrower == me then
				return true
			end
		end
		if base.sentry_gun and base.get_owner then
			if base:get_owner() == me then
				return true
			end
		end
	end
	return false
end

if CopDamage and CopDamage.die then
	Hooks:PreHook(CopDamage, "die", "BigAmmoPickups_MarkLocalKill", function(self, attack_data)
		self._bap_local_kill = _is_local_killer(attack_data)
	end)
end

if CopDamage and CopDamage.drop_pickup then
	local _orig = CopDamage.drop_pickup
	function CopDamage:drop_pickup(extra)
		if not BAP.settings or BAP.settings.collect_on_kill == nil then
			if BAP.Load then
				BAP:Load()
			end
		end
		local eat = BAP.settings and BAP.settings.collect_on_kill and self._bap_local_kill and self._pickup
		if not eat then
			return _orig(self, extra)
		end
		-- Spawn the box so we can fire vanilla Gambler share packets (allies need no mod), then eat it.
		_orig(self, extra)
		local pos = self._unit and self._unit:position()
		local box = BAP.FindNearbyAmmoBox and BAP:FindNearbyAmmoBox(pos, 250)
		if BAP.ApplyVirtualBoxPickup then
			BAP:ApplyVirtualBoxPickup(box)
		end
		if box then
			BAP:ConsumeAmmoBox(box)
		elseif pos and DelayedCalls then
			DelayedCalls:Add("BAP_EatBox_" .. tostring(self._unit:key()), 0.2, function()
				local late = BAP:FindNearbyAmmoBox(pos, 250)
				if late then
					BAP:ConsumeAmmoBox(late)
				end
			end)
		end
	end
end
