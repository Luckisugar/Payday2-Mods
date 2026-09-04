-- Omniscience+ — tweak_data only
_G.OmnisciencePlus = _G.OmnisciencePlus or {}

Hooks:PostHook(PlayerTweakData, "init", "OmnisciencePlus_PlayerTweakData", function(self)
	if OmnisciencePlus.Load and (not OmnisciencePlus.settings or OmnisciencePlus.settings.radius_m == nil) then
		OmnisciencePlus:Load()
	end
	if not OmnisciencePlus.StartT then
		return
	end
	self.omniscience = self.omniscience or {}
	self.omniscience.start_t = OmnisciencePlus:StartT()
	self.omniscience.interval_t = OmnisciencePlus:IntervalT()
	self.omniscience.sense_radius = OmnisciencePlus:SenseRadius()
	self.omniscience.target_resense_t = OmnisciencePlus:ResenseT()
	self.omniscience.sense_exit_sq = 4900
end)
