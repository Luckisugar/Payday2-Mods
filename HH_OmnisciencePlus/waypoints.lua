--[[
	Hide PAYDAY's off-screen waypoint arrows for Omniscience+ fallback icons
	(used only when a contour cannot be applied). Icons stay on the object.
]]

if not HUDManager or not HUDManager._update_waypoints then
	return
end

local WP_PREFIX = "omp_q_"

local function hide_edge_arrows()
	return true
end

Hooks:PostHook(HUDManager, "_update_waypoints", "OmnisciencePlus_NoEdgeArrows", function(self, t, dt)
	if not hide_edge_arrows() then
		return
	end
	local wps = self._hud and self._hud.waypoints
	if not wps then
		return
	end
	for id, wp in pairs(wps) do
		if type(id) == "string" and string.sub(id, 1, #WP_PREFIX) == WP_PREFIX then
			local on_rim = wp.arrow and wp.arrow.visible and wp.arrow:visible()
			if wp.arrow and wp.arrow.set_visible then
				wp.arrow:set_visible(false)
			end
			if on_rim then
				if wp.bitmap and wp.bitmap.set_visible then
					wp.bitmap:set_visible(false)
				end
				if wp.distance and wp.distance.set_visible then
					wp.distance:set_visible(false)
				end
				if wp.text and wp.text.set_visible then
					wp.text:set_visible(false)
				end
			end
		end
	end
end)
