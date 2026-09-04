--[[
	Big Ammo Pickups — optional tactical charge restore from ammo drops.
	Every N enemy ammo-box pickups (random min–max from settings): +1 selected deployable,
	optionally +1 throwable (grenades etc.).
]]

_G.BigAmmoPickups = _G.BigAmmoPickups or {}
local BAP = BigAmmoPickups

BAP._ammo_drop_count = BAP._ammo_drop_count or 0
BAP._tactical_next_at = BAP._tactical_next_at or 22

function BAP:ResetTacticalCounter()
	self._ammo_drop_count = 0
	local min_i = (self.settings and self.settings.tactical_min) or 20
	local max_i = (self.settings and self.settings.tactical_max) or 25
	if min_i > max_i then
		min_i, max_i = max_i, min_i
	end
	self._tactical_next_at = math.random(min_i, max_i)
end

function BAP:_equipment_max_amount(equipment_name, slot_index)
	local td = tweak_data.equipments and tweak_data.equipments[equipment_name]
	if not td or not td.quantity then
		return 1
	end

	local max_a = td.quantity[1] or 0
	if managers.player.equiptment_upgrade_value then
		max_a = max_a + (managers.player:equiptment_upgrade_value(equipment_name, "quantity") or 0)
	end
	if managers.modifiers and managers.modifiers.modify_value then
		max_a = managers.modifiers:modify_value("PlayerManager:GetEquipmentMaxAmount", max_a, {
			equipment = equipment_name
		})
	end
	-- Jack of all Trades secondary slot is half quantity.
	if slot_index and slot_index > 1 then
		max_a = math.ceil(max_a / 2)
	end
	return math.max(max_a, 1)
end

function BAP:RestoreTacticalCharge()
	local pm = managers.player
	if not pm or not alive(pm:player_unit()) then
		return
	end

	-- Deployable currently selected (bags, sentry, trip mines, ECM, FAK…).
	local eq = pm._equipment
	local sel = eq and eq.selections and eq.selected_index and eq.selections[eq.selected_index]
	if sel and sel.equipment and sel.amount and sel.amount[1] then
		local cur = Application:digest_value(sel.amount[1], false)
		local max_a = self:_equipment_max_amount(sel.equipment, eq.selected_index)
		if cur < max_a then
			pm:add_equipment_amount(sel.equipment, 1, 1)
			local new_amt = Application:digest_value(sel.amount[1], false)
			if pm.update_deployable_equipment_amount_to_peers then
				pm:update_deployable_equipment_amount_to_peers(sel.equipment, new_amt)
			end
		end
	end

	-- Throwable (frags, molotov, flash, knives…) — optional.
	if self.settings and self.settings.tactical_throwable then
		if pm.add_grenade_amount and not (pm.got_max_grenades and pm:got_max_grenades()) then
			pm:add_grenade_amount(1)
		end
	end
end

function BAP:OnAmmoDropPickedUp(unit)
	if not self.settings or self.settings.tactical_from_ammo == nil then
		if self.Load then
			self:Load()
		end
	end
	if not self.settings or not self.settings.tactical_from_ammo then
		return
	end

	local local_unit = managers.player and managers.player:player_unit()
	if not local_unit or unit ~= local_unit then
		return
	end

	self._ammo_drop_count = (self._ammo_drop_count or 0) + 1
	local need = self._tactical_next_at or 22
	if self._ammo_drop_count >= need then
		self:ResetTacticalCounter()
		self:RestoreTacticalCharge()
	end
end

-- Mark local box pickup so we can fire vanilla Gambler share before consume deletes the unit.
-- File is hooked twice (raycastweaponbase + ammoclip); wrap once.
if AmmoClip and AmmoClip._pickup and not AmmoClip._bap_pickup_wrapped then
	AmmoClip._bap_pickup_wrapped = true
	local _orig_pickup = AmmoClip._pickup
	function AmmoClip:_pickup(unit)
		local me = managers.player and managers.player:player_unit()
		if self._ammo_box and unit == me then
			self._bap_local_pickup = true
		end
		return _orig_pickup(self, unit)
	end
end

if AmmoClip and AmmoClip.consume then
	Hooks:PreHook(AmmoClip, "consume", "BigAmmoPickups_ShareBeforeConsume", function(self)
		if not self._ammo_box or not self._bap_local_pickup or self._bap_did_effects then
			return
		end
		self._bap_did_effects = true
		local me = managers.player and managers.player:player_unit()
		if BigAmmoPickups.OnAmmoDropPickedUp then
			BigAmmoPickups:OnAmmoDropPickedUp(me)
		end
		if BigAmmoPickups.OnQualifyingPickup then
			BigAmmoPickups:OnQualifyingPickup(self._unit)
		end
	end)
end

-- Wrap on RaycastWeaponBase itself (subclasses inherit). Must hook
-- lib/units/weapons/raycastweaponbase — wrapping from ammoclip is often too early
-- and RaycastWeaponBase is still nil, so the old wrap never attached.
local function bap_wrap_add_ammo()
	local class = rawget(_G, "RaycastWeaponBase")
	if not class or type(class.add_ammo) ~= "function" or class._bap_mag_wrapped then
		return
	end
	class._bap_mag_wrapped = true
	local orig = class.add_ammo
	function class:add_ammo(ratio, add_amount_override)
		local picked, add_amount = orig(self, ratio, add_amount_override)
		if not BigAmmoPickups or not BigAmmoPickups.TryFillMagazineFromPickup then
			return picked, add_amount
		end
		local filled = BigAmmoPickups:TryFillMagazineFromPickup(self)
		if self.AKIMBO and self._second_gun and alive(self._second_gun) then
			local second = self._second_gun:base()
			if second then
				filled = BigAmmoPickups:TryFillMagazineFromPickup(second) or filled
			end
		end
		return picked or filled, add_amount
	end
end
bap_wrap_add_ammo()

-- Fresh counter when local player spawns (heist start).
if PlayerManager and PlayerManager.spawned_player then
	Hooks:PostHook(PlayerManager, "spawned_player", "BigAmmoPickups_ResetTacticalOnSpawn", function(self, peer_id, unit)
		-- Local player is always id 1 in PlayerManager._players.
		if peer_id == 1 and BigAmmoPickups.ResetTacticalCounter then
			BigAmmoPickups:ResetTacticalCounter()
		end
	end)
end
