--[[
	Heist Helper — meth-lab ingredient callouts
	Dialog IDs from Meth Helper Updated (Offyerrocker), SuperBLT-only (no BeardLib).
]]

_G.MethHelper = _G.MethHelper or {}
_G.HeistHelper = _G.HeistHelper or {}
local HH = MethHelper
if not HH.IsMethEnabled then
	HH = HeistHelper
end

HH._last_ingredient = HH._last_ingredient or nil

local DIALOG_IDS = {
	["pln_rt1_12"] = "added",
	["pln_rt1_23"] = "fail",
	["pln_rt1_20"] = "mu",
	["pln_rt1_22"] = "cs",
	["pln_rt1_24"] = "hcl",
	["pln_rt1_28"] = "added",
	["Play_pln_nai_16"] = "fail",
	["pln_rat_stage1_20"] = "mu",
	["pln_rat_stage1_22"] = "cs",
	["pln_rat_stage1_24"] = "hcl",
	["pln_rat_stage1_28"] = "done",
	["Play_loc_mex_cook_03"] = "mu",
	["Play_loc_mex_cook_04"] = "cs",
	["Play_loc_mex_cook_05"] = "hcl",
	["Play_loc_mex_cook_14"] = "done",
	["Play_loc_mex_cook_17"] = "done",
	["Play_loc_mex_cook_22"] = "added",
	["Play_loc_mex_cook_12"] = "fail",
}

local INGREDIENTS = {
	mu = true,
	cs = true,
	hcl = true,
}

local function loc_line(id)
	if managers.localization then
		return managers.localization:text("hh_meth_" .. id)
	end
	return id
end

if DialogManager then
	Hooks:PostHook(DialogManager, "queue_dialog", "HeistHelper_QueueDialog_Meth", function(self, id, params)
		if not HH.IsMethEnabled or not HH:IsMethEnabled() then
			return
		end
		local line_type = DIALOG_IDS[tostring(id)]
		if not line_type then
			return
		end

		local chatmode, hintmode
		local output
		if INGREDIENTS[line_type] then
			chatmode, hintmode = HH:MethOutputType("ingred")
			if line_type ~= HH._last_ingredient or HH.settings.meth_ingred_repeat then
				output = loc_line(line_type)
			end
			HH._last_ingredient = line_type
		else
			chatmode, hintmode = HH:MethOutputType(line_type)
			output = loc_line(line_type)
			HH._last_ingredient = line_type
		end

		if not output then
			return
		end
		if HH.settings.meth_message_allcaps and utf8 and utf8.to_upper then
			output = utf8.to_upper(output)
		end

		local prefix = "[" .. loc_line("prefix") .. "]"
		local color = Color("5FE1FF")
		local channel = (ChatManager and ChatManager.GAME) or 1

		if chatmode == 1 and managers.chat then
			managers.chat:_receive_message(channel, prefix, output, color)
		elseif chatmode == 2 and managers.chat then
			local username = (managers.network and managers.network.account and managers.network.account:username()) or "Offline"
			managers.chat:send_message(channel, username, output)
		end

		if hintmode and managers.hud and managers.hud.show_hint then
			managers.hud:show_hint({ text = output })
		end
	end)
end
