local HH = _G.MethHelper or _G.HeistHelper
if not HH or not HH.ToggleMeth then
	return
end
local value = HH:ToggleMeth()
if managers.hud and managers.hud.show_hint then
	local key = value and "hh_meth_toggled_true" or "hh_meth_toggled_false"
	local text = (managers.localization and managers.localization:text(key)) or (value and "Meth callouts on" or "Meth callouts off")
	managers.hud:show_hint({ text = text })
end
