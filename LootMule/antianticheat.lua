--[[
	Loot Mule — bag anti-cheat bypass

	Vanilla only allows ONE bag per peer (NetworkPeer._carry_id):
	  2nd pickup → "cheated by picking up too many bags"
	  2nd throw  → "tried to cheat by throwing too many bags"
	  verify fails → server_drop_carry aborts → bags vanish (eaten)

	Same approach as Carry Stacker Reloaded: when Loot Mule is enabled,
	verify_carry / register_carry always succeed.
]]

if not LootMule or not LootMule.Load then
	dofile(ModPath .. "core.lua")
end

local LM = LootMule

-- PlayerManager hooks (loaded with playermanager)
if PlayerManager and not LM._hooked_pm_anticheat then
	LM._hooked_pm_anticheat = true

	local master_verify_carry = PlayerManager.verify_carry
	local master_register_carry = PlayerManager.register_carry

	function PlayerManager:verify_carry(peer, carry_id, ...)
		if LM:IsEnabled() then
			return true
		end
		return master_verify_carry(self, peer, carry_id, ...)
	end

	function PlayerManager:register_carry(peer, carry_id, ...)
		if LM:IsEnabled() then
			return true
		end
		return master_register_carry(self, peer, carry_id, ...)
	end
end

-- NetworkPeer hooks (loaded with networkpeer — may load later than playermanager)
if NetworkPeer and not LM._hooked_peer_anticheat then
	LM._hooked_peer_anticheat = true

	local master_verify_bag = NetworkPeer.verify_bag

	function NetworkPeer:verify_bag(carry_id, pickup, ...)
		if LM:IsEnabled() then
			if pickup then
				self._carry_id = carry_id
			else
				-- Allow any throw; clear so state stays sane
				self._carry_id = nil
			end
			return true
		end
		return master_verify_bag(self, carry_id, pickup, ...)
	end
end
