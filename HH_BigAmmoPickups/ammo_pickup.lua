--[[
	Big Ammo Pickups — core + WeaponTweakData apply
	Must be self-contained: weapontweakdata loads BEFORE menumanager,
	so menu.lua is not available yet when this hook runs.
]]

_G.BigAmmoPickups = _G.BigAmmoPickups or {}
local BAP = BigAmmoPickups

BAP._path = BAP._path or ModPath
BAP._data_path = BAP._data_path or (SavePath .. "big_ammo_pickups.txt")
BAP._originals = BAP._originals or {}
BAP.settings = BAP.settings or {}

function BAP:DefaultSettings()
	return {
		enabled = true,
		multiplier = 10,
		min_floor = 2,
		max_floor = 5,
		boost_zero_pickup = true,
		zero_pickup_min = 4,
		zero_pickup_max = 8,
		tactical_from_ammo = false,
		tactical_min = 20,
		tactical_max = 25,
		tactical_throwable = true,
		pickup_heal = false,
		heal_min = 16,
		heal_max = 24,
		heal_cooldown = 3,
		share_ammo = false,
		share_ammo_percent = 50,
		share_ammo_cooldown = 5,
		share_heal = false,
		share_heal_percent = 50,
		share_heal_cooldown = 3,
		collect_on_kill = false,
		mag_when_full = false,
	}
end

function BAP:Load()
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

function BAP:Save()
	local file = io.open(self._data_path, "w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

-- Capture vanilla AMMO_PICKUP once per weapon key.
-- force=true clears cache first (use on WeaponTweakData:init only).
function BAP:StoreOriginals(wtd, force)
	if not wtd then
		return
	end
	if force then
		self._originals = {}
	end
	for key, weap in pairs(wtd) do
		if type(weap) == "table" and type(weap.AMMO_PICKUP) == "table"
			and type(weap.AMMO_PICKUP[1]) == "number" and type(weap.AMMO_PICKUP[2]) == "number" then
			if not self._originals[key] then
				self._originals[key] = { weap.AMMO_PICKUP[1], weap.AMMO_PICKUP[2] }
			end
		end
	end
end

function BAP:Apply(wtd)
	wtd = wtd or (tweak_data and tweak_data.weapon)
	if not wtd then
		return
	end
	if not self.settings or self.settings.multiplier == nil then
		self:Load()
	end
	self:StoreOriginals(wtd, false)

	local s = self.settings
	local boosted = 0
	local zeroed = 0

	for key, orig in pairs(self._originals) do
		local weap = wtd[key]
		if type(weap) == "table" then
			if not s.enabled then
				weap.AMMO_PICKUP = { orig[1], orig[2] }
			else
				local min_v, max_v = orig[1], orig[2]
				local was_zero = min_v <= 0 and max_v <= 0
				if was_zero then
					if s.boost_zero_pickup then
						min_v = s.zero_pickup_min or 0
						max_v = math.max(s.zero_pickup_max or 0, min_v)
						weap.AMMO_PICKUP = { min_v, max_v }
						zeroed = zeroed + 1
					else
						weap.AMMO_PICKUP = { orig[1], orig[2] }
					end
				else
					local mult = s.multiplier or 1
					min_v = min_v * mult
					max_v = max_v * mult
					local min_f = s.min_floor or 0
					local max_f = s.max_floor or 0
					if min_f > 0 then
						min_v = math.max(min_v, min_f)
					end
					if max_f > 0 then
						max_v = math.max(max_v, max_f)
					end
					if max_v < min_v then
						max_v = min_v
					end
					weap.AMMO_PICKUP = { min_v, max_v }
					boosted = boosted + 1
				end
			end
		end
	end

	if log then
		log(string.format(
			"[BigAmmoPickups] applied enabled=%s mult=%s boosted=%d special=%d floors=%s/%s zero=%s-%s",
			tostring(s.enabled),
			tostring(s.multiplier),
			boosted,
			zeroed,
			tostring(s.min_floor),
			tostring(s.max_floor),
			tostring(s.zero_pickup_min),
			tostring(s.zero_pickup_max)
		))
	end
end

BAP._hint_gap = 12
BAP._next_heal_t = BAP._next_heal_t or 0
BAP._next_share_ammo_t = BAP._next_share_ammo_t or 0
BAP._next_share_heal_t = BAP._next_share_heal_t or 0
BAP._next_hint_t = BAP._next_hint_t or 0

function BAP:_now()
	if TimerManager and TimerManager.game then
		return TimerManager:game():time()
	end
	return 0
end

function BAP:_ensure_settings()
	if not self.settings or self.settings.multiplier == nil then
		self:Load()
	end
end

function BAP:IsUsingGambler()
	local pm = managers.player
	if not pm or not pm.has_category_upgrade then
		return false
	end
	return pm:has_category_upgrade("temporary", "loose_ammo_restore_health")
		or pm:has_category_upgrade("temporary", "loose_ammo_give_team")
end

function BAP:_local_player()
	return managers.player and managers.player:player_unit()
end

function BAP:AddLocalPickupAmmo(ratio)
	ratio = ratio or 1
	local unit = self:_local_player()
	if not alive(unit) then
		return false
	end
	local inv = unit:inventory()
	if not inv then
		return false
	end
	local picked = false
	for id, weapon in pairs(inv:available_selections()) do
		if weapon.unit and weapon.unit:base() and weapon.unit:base().add_ammo then
			if weapon.unit:base():add_ammo(ratio) then
				picked = true
			end
			if managers.hud and managers.hud.set_ammo_amount then
				managers.hud:set_ammo_amount(id, weapon.unit:base():ammo_info())
			end
		end
	end
	return picked
end

-- Chamber mag from reserve. Same clip write as vanilla RaycastWeaponBase:on_reload
-- (what pressing R does). Ammo Efficiency's on_ammo_increase -> add_ammo_to_pool
-- is a no-op when total is already max, which is the case we care about.
function BAP:TryFillMagazineFromPickup(weapon)
	self:_ensure_settings()
	if not self.settings.mag_when_full then
		return false
	end
	if not weapon then
		return false
	end
	local base = weapon
	if weapon.ammo_base then
		local ok, ab = pcall(function()
			return weapon:ammo_base()
		end)
		if ok and ab then
			base = ab
		end
	end
	if not base.get_ammo_remaining_in_clip or not base.get_ammo_max_per_clip or not base.get_ammo_total then
		return false
	end
	local clip = base:get_ammo_remaining_in_clip()
	local clip_max = base:get_ammo_max_per_clip()
	local total = base:get_ammo_total()
	if not clip or not clip_max or not total then
		return false
	end
	if clip >= clip_max or total <= clip then
		return false
	end
	base:set_ammo_remaining_in_clip(math.min(total, clip_max))
	if weapon.set_magazine_empty then
		pcall(function()
			weapon:set_magazine_empty(false)
		end)
	end
	if managers.hud and managers.hud.set_ammo_amount and weapon.selection_index and weapon.ammo_info then
		pcall(function()
			managers.hud:set_ammo_amount(weapon:selection_index(), weapon:ammo_info())
		end)
	end
	return true
end

function BAP:HealLocal(amount)
	if not amount or amount <= 0 then
		return false
	end
	local unit = self:_local_player()
	if not alive(unit) then
		return false
	end
	local dmg = unit:character_damage()
	if not dmg or dmg.dead and dmg:dead() then
		return false
	end
	if dmg.need_revive and dmg:need_revive() then
		return false
	end
	if dmg.is_downed and dmg:is_downed() then
		return false
	end
	if dmg.is_berserker and dmg:is_berserker() then
		return false
	end
	if dmg.restore_health then
		return dmg:restore_health(amount, true) and true or false
	end
	return false
end

function BAP:_roll_self_heal()
	local s = self.settings
	local lo = tonumber(s.heal_min) or 16
	local hi = tonumber(s.heal_max) or 24
	if lo > hi then
		lo, hi = hi, lo
	end
	if hi <= 0 then
		return 0
	end
	return math.random(math.floor(lo), math.floor(hi))
end

-- Same packets vanilla Gambler uses. Allies do not need this mod.
-- ammo: AmmoClip event 1 (bonnie_share_ammo) → their client add_ammo(0.5 of THEIR pickup table)
-- heal: event 2+sync → their client restore_health with vanilla Gambler math
function BAP:SendVanillaShare(clip_unit, send_ammo, heal_card)
	if not alive(clip_unit) then
		return false
	end
	local session = managers.network and managers.network:session()
	if not session or not session.send_to_peers_synched then
		return false
	end
	local sent = false
	if send_ammo then
		local pct = tonumber(self.settings.share_ammo_percent) or 50
		local times = 1
		if pct >= 75 then
			times = 2
		elseif pct <= 0 then
			times = 0
		end
		local ev = (AmmoClip and AmmoClip.EVENT_IDS and AmmoClip.EVENT_IDS.bonnie_share_ammo) or 1
		for _ = 1, times do
			session:send_to_peers_synched("sync_unit_event_id_16", clip_unit, "pickup", ev)
			sent = true
		end
	end
	if heal_card and heal_card > 0 then
		local base = 8
		local td = tweak_data and tweak_data.upgrades and tweak_data.upgrades.loose_ammo_restore_health_values
		if td and td.base then
			base = td.base
		end
		local sync_value = math.floor((heal_card - base) + 0.5)
		sync_value = math.max(0, math.min(13, sync_value))
		session:send_to_peers_synched("sync_unit_event_id_16", clip_unit, "pickup", 2 + sync_value)
		sent = true
	end
	return sent
end

function BAP:FindNearbyAmmoBox(pos, radius)
	if not pos or not managers.slot then
		return nil
	end
	local ok, slot = pcall(function()
		return managers.slot:get_mask("pickups")
	end)
	if not ok or not slot then
		return nil
	end
	local units = World:find_units_quick("sphere", pos, radius or 220, slot)
	if not units then
		return nil
	end
	for _, u in ipairs(units) do
		if alive(u) and u.base then
			local base = u:base()
			if base and base._ammo_box then
				return u
			end
		end
	end
	return nil
end

function BAP:ConsumeAmmoBox(unit)
	if not alive(unit) then
		return
	end
	local base = unit:base()
	if not base then
		return
	end
	if Network:is_client() and managers.network and managers.network:session() then
		managers.network:session():send_to_host("sync_pickup", unit)
	end
	if base.consume then
		base._picked_up = true
		base:consume()
	end
end

function BAP:_maybe_hint()
	local t = self:_now()
	if t < (self._next_hint_t or 0) then
		return
	end
	self._next_hint_t = t + (self._hint_gap or 12)
	if managers.hud and managers.hud.show_hint then
		managers.hud:show_hint({
			text = managers.localization and managers.localization:exists("bap_share_hint")
				and managers.localization:text("bap_share_hint")
				or "Shared ammo / health",
			time = 1.4
		})
	end
end

-- clip_unit = the ammo box, still alive. Needed so vanilla peers can receive share.
function BAP:OnQualifyingPickup(clip_unit)
	self:_ensure_settings()
	local s = self.settings
	if self:IsUsingGambler() then
		return
	end

	local t = self:_now()
	local healed = 0
	local send_ammo = false
	local heal_card = 0

	if s.pickup_heal then
		local cd = tonumber(s.heal_cooldown) or 3
		if t >= (self._next_heal_t or 0) then
			healed = self:_roll_self_heal()
			if healed > 0 and self:HealLocal(healed) then
				self._next_heal_t = t + math.max(cd, 0)
				local unit = self:_local_player()
				if alive(unit) and unit:sound() then
					unit:sound():play("pickup_ammo_health_boost", nil, true)
				end
			else
				healed = 0
			end
		end
	end

	if s.share_ammo then
		local cd = tonumber(s.share_ammo_cooldown) or 5
		if t >= (self._next_share_ammo_t or 0) and (tonumber(s.share_ammo_percent) or 50) > 0 then
			send_ammo = true
			self._next_share_ammo_t = t + math.max(cd, 0)
		end
	end

	if s.share_heal and healed > 0 then
		local cd = tonumber(s.share_heal_cooldown) or 3
		if t >= (self._next_share_heal_t or 0) then
			heal_card = healed * ((tonumber(s.share_heal_percent) or 50) / 100)
			if heal_card > 0 then
				self._next_share_heal_t = t + math.max(cd, 0)
			end
		end
	end

	local shared = false
	if (send_ammo or heal_card > 0) and alive(clip_unit) then
		shared = self:SendVanillaShare(clip_unit, send_ammo, heal_card)
	end

	if shared or healed > 0 then
		self:_maybe_hint()
	end
end

function BAP:ApplyVirtualBoxPickup(clip_unit)
	self:_ensure_settings()
	local unit = self:_local_player()
	if not alive(unit) then
		return false
	end
	self:AddLocalPickupAmmo(1)
	if alive(unit) and unit:sound() then
		unit:sound():play("pickup_ammo", nil, true)
	end
	if self.OnAmmoDropPickedUp then
		self:OnAmmoDropPickedUp(unit)
	end
	self:OnQualifyingPickup(clip_unit)
	return true
end

-- Load settings as soon as this file is required (weapon tweak hook).
if not BAP._loaded_once then
	BAP:Load()
	BAP._loaded_once = true
end

local _orig_init = WeaponTweakData.init
function WeaponTweakData:init(tweak_data)
	_orig_init(self, tweak_data)
	if not BigAmmoPickups.settings or BigAmmoPickups.settings.multiplier == nil then
		BigAmmoPickups:Load()
	end
	-- Vanilla values are fresh here — force-capture originals then apply.
	BigAmmoPickups:StoreOriginals(self, true)
	BigAmmoPickups:Apply(self)
end
