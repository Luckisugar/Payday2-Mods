--[[
	Loot Mule — multi-bag stack (LIFO). Crouch-only pickup. Throw distance slider.
]]

_G.LootMule = _G.LootMule or {}
local LM = LootMule

LM._path = LM._path or ModPath
LM._data_path = LM._data_path or (SavePath .. "loot_mule.txt")
LM.stack = LM.stack or {}

-- Gap between dump-all throws. Same-frame dumps eat bags / orphan zip attachments.
LM.DUMP_GAP = 0.1
LM.RELEASE_GAP = 0.05

function LM:DefaultSettings()
	return {
		enabled = true,
		crouch_pickup = true,
		throw_distance = 1.69,
		dump_all = true,
		show_stack_hint = true,
		unlimited_body_bags = true
	}
end

function LM:Load()
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
	local td = tonumber(self.settings.throw_distance) or 1.69
	self.settings.throw_distance = math.max(0.25, math.min(10, math.floor(td * 100 + 0.5) / 100))
	local d = self.settings.dump_all
	self.settings.dump_all = (d == true or d == "on" or d == 1)
	local h = self.settings.show_stack_hint
	self.settings.show_stack_hint = (h == true or h == "on" or h == 1)
end

function LM:Save()
	local file = io.open(self._data_path, "w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

function LM:IsEnabled()
	return self.settings and self.settings.enabled == true
end

--- Active for stacking (still active while stack non-empty so you can empty bags after disable).
function LM:StackActive()
	if self:IsEnabled() then
		return true
	end
	return self.stack and #self.stack > 0
end

function LM:IsCrouching()
	local player = managers.player and managers.player:player_unit()
	if not alive(player) then
		return false
	end
	local state = player:movement() and player:movement():current_state()
	if state and state.ducking then
		return state:ducking() == true
	end
	if state and state._state_data then
		return state._state_data.ducking == true
	end
	return false
end

function LM:IsMultiplayerClient()
	return Network ~= nil and Network.is_client and Network:is_client() == true
end

--- Host (or SP): our enabled flag. Client: host pinged that they have Loot Mule on.
function LM:HostAllowsStack()
	if not self:IsMultiplayerClient() then
		return self:IsEnabled()
	end
	return self._host_allows_stack == true
end

function LM:SetHostAllowsStack(on)
	self._host_allows_stack = on == true
end

function LM:BroadcastHostState()
	if not Network or not Network.is_server or not Network:is_server() then
		return
	end
	if not LuaNetworking or not LuaNetworking.SendToPeers then
		return
	end
	local payload = self:IsEnabled() and "1" or "0"
	pcall(function()
		LuaNetworking:SendToPeers("LM_HOST", payload)
	end)
end

function LM:RequestHostState()
	if not self:IsMultiplayerClient() then
		return
	end
	if not LuaNetworking or not LuaNetworking.SendToPeers then
		return
	end
	pcall(function()
		LuaNetworking:SendToPeers("LM_REQ", "1")
	end)
end

--- True if the player already has a bag (vanilla carry and/or our stack).
function LM:IsAlreadyCarrying()
	if self:Count() > 0 then
		return true
	end
	if managers.player and managers.player.is_carrying then
		return managers.player:is_carrying() == true
	end
	return false
end

function LM:ValidCarryId(id)
	if not id or id == "" then
		return false
	end
	local td = tweak_data and tweak_data.carry
	if not td or type(td[id]) ~= "table" then
		return false
	end
	local typ = td[id].type
	if not typ or not td.types or not td.types[typ] then
		return false
	end
	return true
end

--- nil = allowed. "host_only" / "crouch" / "busy"
function LM:PickupBlockReason()
	if self._dumping or self._wait_release then
		return "busy"
	end
	if not self:IsAlreadyCarrying() then
		return nil
	end
	if self:IsMultiplayerClient() and not self:HostAllowsStack() then
		return "host_only"
	end
	if self.settings and self.settings.crouch_pickup and not self:IsCrouching() then
		return "crouch"
	end
	return nil
end

--- First bag: always OK while mod on (no crouch needed).
--- Extra bags: host must have the mod; crouch if crouch_pickup is on.
function LM:CanPickupNow()
	if not self:IsEnabled() then
		return false
	end
	return self:PickupBlockReason() == nil
end

function LM:ThrowMult()
	if not self:IsEnabled() then
		return 1
	end
	return math.max(0.25, math.min(10, tonumber(self.settings.throw_distance) or 1.69))
end

--- One G throw = entire stack flies out. Off = LIFO one bag per throw.
function LM:DumpAllOnThrow()
	return self:IsEnabled() and self.settings and self.settings.dump_all == true
end

function LM:ShowNotifications()
	return self.settings and self.settings.show_stack_hint == true
end

function LM:UnlimitedBodyBags()
	return self:IsEnabled() and self.settings.unlimited_body_bags == true
end

function LM:Count()
	return self.stack and #self.stack or 0
end

function LM:AddCarry(cdata)
	if not cdata or not cdata.carry_id or not self:ValidCarryId(cdata.carry_id) then
		return
	end
	table.insert(self.stack, {
		carry_id = cdata.carry_id,
		multiplier = cdata.multiplier or 1,
		dye_initiated = cdata.dye_initiated,
		has_dye_pack = cdata.has_dye_pack,
		dye_value_multiplier = cdata.dye_value_multiplier
	})
	self:HudRefresh()
end

function LM:RemoveTop()
	if not self.stack or #self.stack == 0 then
		return nil
	end
	local cdata = table.remove(self.stack, #self.stack)
	self:HudRefresh()
	return cdata
end

function LM:ClearStack()
	self.stack = {}
	self:HudRefresh()
end

function LM:AbortThrow()
	self._dumping = false
	self._wait_release = false
	self._force_dump = false
	self._dump_t = 0
	self._release_t = 0
end

function LM:IsThrowHeld()
	local player = managers.player and managers.player:player_unit()
	if not alive(player) then
		return false
	end
	local mov = player.movement and player:movement()
	local state = mov and mov.current_state and mov:current_state()
	local ctrl = state and state._controller
	if not ctrl and player.base then
		local b = player:base()
		if b and b.controller then
			ctrl = b:controller()
		end
	end
	if not ctrl or not ctrl.get_input_bool then
		return false
	end
	return ctrl:get_input_bool("use_item") == true
end

--- Stack count: special equipment icon (CSR style) + optional hint text.
function LM:HudRefresh()
	if managers.hud and managers.hud.remove_special_equipment then
		managers.hud:remove_special_equipment("lootmule_stack")
		local n = self:Count()
		if n > 0 and managers.hud.add_special_equipment then
			managers.hud:add_special_equipment({
				id = "lootmule_stack",
				icon = "pd2_loot",
				amount = n
			})
		end
	end

	if not self:ShowNotifications() then
		return
	end
	local n = self:Count()
	if n <= 0 then
		return
	end
	if managers.hud and managers.hud.show_hint then
		managers.hud:show_hint({
			text = "Loot Mule: " .. tostring(n) .. " bag" .. (n == 1 and "" or "s"),
			time = 1.5
		})
	end
end

if not LM.settings then
	LM:Load()
end
