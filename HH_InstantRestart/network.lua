--[[ Instant Restart — SuperBLT LuaNetworking for SYSTEM chat on peers ]]

if not _G.InstantRestart or not InstantRestart.on_network_system_message then
	dofile(ModPath .. "core.lua")
end

local IR = InstantRestart
local NET_ID = IR._net_id or "IR_SYSMSG"

Hooks:Add("NetworkReceivedData", "InstantRestart_NetSystem", function(sender, id, data)
	if id ~= NET_ID then
		return
	end
	-- Only accept short plain text
	if type(data) ~= "string" or #data > 200 then
		return
	end
	IR:on_network_system_message(sender, data)
end)
