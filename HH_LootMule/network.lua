--[[ Instant Restart-style SuperBLT ping: host has Loot Mule on/off ]]

if not LootMule or not LootMule.Load then
	dofile(ModPath .. "core.lua")
end

local LM = LootMule

local function sender_is_host(sender)
	local session = managers.network and managers.network:session()
	local server = session and session.server_peer and session:server_peer()
	return server and server:id() == sender
end

Hooks:Add("NetworkReceivedData", "LootMule_NetHost", function(sender, id, data)
	if id == "LM_HOST" then
		if sender_is_host(sender) then
			LM:SetHostAllowsStack(data == "1")
		end
		return
	end
	if id == "LM_REQ" then
		if Network and Network:is_server() then
			LM:BroadcastHostState()
		end
	end
end)

Hooks:Add("NetworkManagerOnPeerAdded", "LootMule_PeerAdded", function(peer, peer_id)
	if not Network or not Network:is_server() then
		return
	end
	if DelayedCalls and DelayedCalls.Add then
		DelayedCalls:Add("LootMule_HostPing" .. tostring(peer_id), 1.5, function()
			LM:BroadcastHostState()
		end)
	else
		LM:BroadcastHostState()
	end
end)

Hooks:Add("BaseNetworkSessionOnLoadComplete", "LootMule_SessionLoad", function()
	if Network and Network:is_server() then
		LM:BroadcastHostState()
	elseif LM:IsMultiplayerClient() then
		if DelayedCalls and DelayedCalls.Add then
			DelayedCalls:Add("LootMule_ClientReq", 1.5, function()
				LM:RequestHostState()
			end)
		else
			LM:RequestHostState()
		end
	end
end)
