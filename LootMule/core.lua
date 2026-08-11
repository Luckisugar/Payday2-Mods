--[[
	Loot Mule — multi-bag stack (LIFO). Crouch-only pickup. Throw distance slider.
]]

_G.LootMule = _G.LootMule or {}
local LM = LootMule

LM._path = LM._path or ModPath
LM._data_path = LM._data_path or (SavePath .. "loot_mule.txt")
LM.stack = LM.stack or {}

function LM:DefaultSettings()
	return {
		enabled = true,
		crouch_pickup = true,
		throw_distance = 1.0,
		show_stack_hint = true
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
	local td = tonumber(self.settings.throw_distance) or 1
	self.settings.throw_distance = math.max(0.25, math.min(10, td))
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

function LM:CanPickupNow()
	if not self:IsEnabled() then
		return false
	end
	if self.settings.crouch_pickup then
		return self:IsCrouching()
	end
	return true
end

function LM:ThrowMult()
	if not self:IsEnabled() then
		return 1
	end
	return math.max(0.25, math.min(10, tonumber(self.settings.throw_distance) or 1))
end

function LM:Count()
	return self.stack and #self.stack or 0
end

function LM:AddCarry(cdata)
	if not cdata then
		return
	end
	table.insert(self.stack, {
		carry_id = cdata.carry_id,
		multiplier = cdata.multiplier or 1,
		dye_initiated = cdata.dye_initiated,
		has_dye_pack = cdata.has_dye_pack,
		dye_value_multiplier = cdata.dye_value_multiplier
	})
	self:Hint()
end

function LM:RemoveTop()
	if not self.stack or #self.stack == 0 then
		return nil
	end
	local cdata = table.remove(self.stack, #self.stack)
	self:Hint()
	return cdata
end

function LM:ClearStack()
	self.stack = {}
end

function LM:Hint()
	if not self.settings or not self.settings.show_stack_hint then
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
