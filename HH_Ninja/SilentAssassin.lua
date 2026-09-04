-------------------------------------------------
--  Menu Logic
-------------------------------------------------
_G.SilentAssassin = _G.SilentAssassin or {}
SilentAssassin._path = ModPath
SilentAssassin._loc_path = ModPath .. "loc/"
SilentAssassin._data_path = SavePath .. "silentassassin.txt"
-- num_pagers -> number of pagers allowed.
-- num_pagers_per_player -> maximum number of pagers a single
--  player may use
SilentAssassin.settings = {}
-- I can't get at the player unit at the end game screen. (or at least I don't
-- know how)  So store the local pagers used here.  It'll be easier if I end
-- up having to sync the pagers used to the clients anyway.
SilentAssassin.localPagersUsed = 0

--Loads the options from blt
function SilentAssassin:Load()
    --log(debug.traceback())
    self.settings["num_pagers"] = 12
    self.settings["num_pagers_per_player"] = 3
    self.settings["enabled"] = true
    self.settings["stealth_kill_enabled"] = true
    self.settings["pager_bonus_enabled"] = false
    self.settings["pager_detection_threshold"] = 1
    -- Luckysugar tweaks: only your kills, only while crouching
    self.settings["local_kills_only"] = true
    self.settings["crouch_only"] = true

    local file = io.open(self._data_path, "r")
    if (file) then
        for k, v in pairs(json.decode(file:read("*all"))) do
            self.settings[k] = v
        end
    end
    --log("In Load " .. json.encode(self.settings))
end

--Saves the options
function SilentAssassin:Save()
    --log("In save " .. json.encode(self.settings))
    local file = io.open(self._data_path, "w+")
    if file then
        file:write(json.encode(self.settings))
        file:close()
    end
end

--Loads the data table for the menuing system.  Menus are
--ones based
function SilentAssassin:getCompleteTable()
    local tbl = {}
    for i, v in pairs(SilentAssassin.settings) do
        if i == "num_pagers" then
            tbl[i] = v + 1
        elseif  i == "num_pagers_per_player" then
            tbl[i] = v + 1
        elseif i == "pager_detection_threshold" then
            tbl[i] = v * 100
        else
            tbl[i] = v
        end
    end

    return tbl
end

--Sets number of pagers.  Called from the menu system.  Menus are all ones
--based
function setNumPagers(this, item)
    SilentAssassin.settings["num_pagers"] = item:value() - 1
end

function setNumPagersPerPlayer(this, item)
    SilentAssassin.settings["num_pagers_per_player"] = item:value() - 1
end

function setEnabled(this, item)
    local value = item:value() == "on" and true or false
    SilentAssassin.settings["enabled"] = value
end

function setStealthKillEnabled(this, item)
    local value = item:value() == "on" and true or false
    SilentAssassin.settings["stealth_kill_enabled"] = value
end

function setEnablePagerBonusToggle(this, item)
    local value = item:value() == "on" and true or false
    SilentAssassin.settings["pager_bonus_enabled"] = value
end

function setPagerDetectionThreshold(this, item)
    local value = item:value() / 100
    SilentAssassin.settings["pager_detection_threshold"] = value
end

function setLocalKillsOnly(this, item)
    local value = item:value() == "on" and true or false
    SilentAssassin.settings["local_kills_only"] = value
end

function setCrouchOnly(this, item)
    local value = item:value() == "on" and true or false
    SilentAssassin.settings["crouch_only"] = value
end

function isLocalKillsOnly()
    if SilentAssassin.settings["local_kills_only"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["local_kills_only"] and true or false
end

function isCrouchOnly()
    if SilentAssassin.settings["crouch_only"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["crouch_only"] and true or false
end

local function sa_is_local_player_unit(unit)
    local pl = managers.player and managers.player:player_unit()
    return alive(pl) and alive(unit) and unit:key() == pl:key()
end

local function sa_unit_is_crouching(unit)
    if not alive(unit) then
        return false
    end
    local mov = unit:movement()
    if mov and mov.crouching then
        local ok, crouching = pcall(function()
            return mov:crouching()
        end)
        if ok then
            return crouching and true or false
        end
    end
    if sa_is_local_player_unit(unit) and managers.player then
        return managers.player:current_state() == "crouch"
    end
    return false
end

-- Returns true if this kill may use stealth-kill (no pager) rules
-- Host-side: client kills often have nil/wrong attacker_unit. When
-- "Only My Kills" is OFF, do not require a readable remote crouch
-- (that check is what made OFF look broken).
local function sa_stealth_kill_allowed(damage_info)
    local attacker = damage_info and damage_info.attacker_unit
    local is_local = sa_is_local_player_unit(attacker)
    if isLocalKillsOnly() then
        if not is_local then
            return false
        end
    end
    if isCrouchOnly() then
        if is_local then
            if not sa_unit_is_crouching(attacker) then
                return false
            end
        elseif isLocalKillsOnly() then
            return false
        end
        -- teammate / unknown attacker + Only My Kills OFF: allow
    end
    return true
end
--this only gives you the bonus for not using your pager
function calculateStageStealthBonus()
    --and if you personally didn't use a pager at all, you get a 2% bonus
    local playerBonus
    if getLocalPagersAnswered() == 0 then
        playerBonus = .02
    else
        playerBonus = 0
    end

    return playerBonus
end

--bonus for difficulty too
function calculateLevelStealthBonus()
    --calculate an adjusted stealth bonus for the level/stage
    -- adding or removing pagers (from the default of 2) changes the bonus
    -- each pager used by the party decreases the bonus
    -- reducing pagers per player increases the bonus
    -- not using your pager increases it
    local numPagers = getNumPagers()
    --don't penalize the player for having 2 total pagers but 4 per player
    local numPagersPerPlayer = math.min(numPagers, getNumPagersPerPlayer())
    local difficultyBonus = 0;
    local parPagers

    --par for pagers is 2 when stealth kills are enabled, otherwise 
    --it is the default of 4.
    if isStealthKillEnabled() then
        parPagers = 2
    else
        parPagers = 4
    end
    -- 2% bonus for each pager below 2
    difficultyBonus = difficultyBonus + ((parPagers - numPagers) * .02)
    -- 1% bonus for each pager per player below the number of total pagers
    difficultyBonus = difficultyBonus + ((numPagers - numPagersPerPlayer) * .01)
    --log ("difficulty bonus is " .. tostring(difficultyBonus))

    --you also get a 1% bonus for each pager you had but didn't use
    local missionBonus
    --it seems like this gets called when someone joins a stealth lobby  In
    --that case groupai is undefined.  So try this hack.
    if managers.groupai and managers.groupai:state() then
        missionBonus = (numPagers - managers.groupai:state():get_nr_successful_alarm_pager_bluffs()) * .01
    else
        missionBonus = numPagers
    end
    --log ("mission bonus is " .. tostring(missionBonus))

    --and if you personally didn't use a pager at all, you get a 2% bonus
    local playerBonus
    if getLocalPagersAnswered() == 0 then
        playerBonus = .02
    else
        playerBonus = 0
    end

    --log("Player bonus is " .. tostring(playerBonus))

    local bonus = difficultyBonus + missionBonus + playerBonus
    --log("Level bonus is " .. tostring(bonus))
    return bonus
end

-- Loc + Heist Helper button live in menu.lua (menumanager hook).
-- Do not scan loc/ with file.GetFiles here — Vortex junk in loc/ can nil that call.
if not SilentAssassin._hh_menu then
    Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_SilentAssassin", function(loc)
        local path = SilentAssassin._loc_path .. "english.json"
        if io.file_is_readable(path) then
            loc:load_localization_file(path)
        end
    end)

    Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_SilentAssassin", function(menu_manager)
        MenuCallbackHandler.SilentAssassin_setNumPagers = setNumPagers
        MenuCallbackHandler.SilentAssassin_setNumPagersPerPlayer = setNumPagersPerPlayer
        MenuCallbackHandler.SilentAssassin_enabledToggle = setEnabled
        MenuCallbackHandler.SilentAssassin_killPagerEnabledToggle = setStealthKillEnabled
        MenuCallbackHandler.SilentAssassin_enablePagerBonusToggle = setEnablePagerBonusToggle
        MenuCallbackHandler.SilentAssassin_setPagerDetectionThreshold = setPagerDetectionThreshold
        MenuCallbackHandler.SilentAssassin_localKillsOnlyToggle = setLocalKillsOnly
        MenuCallbackHandler.SilentAssassin_crouchOnlyToggle = setCrouchOnly

        MenuCallbackHandler.SilentAssassin_Close = function(this)
            SilentAssassin:Save()
        end

        SilentAssassin:Load()
        MenuHelper:LoadFromJsonFile(SilentAssassin._path.."options.txt", SilentAssassin, SilentAssassin:getCompleteTable())
    end)
end

-- gets the number of pagers, triggering a load if necessary.  Called
-- by clients
function getNumPagers()
    if not SilentAssassin.settings["num_pagers"] then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["num_pagers"]
end

function getNumPagersPerPlayer()
    if not SilentAssassin.settings["num_pagers_per_player"] then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["num_pagers_per_player"]
end

function getEffectiveNumPagersPerPlayer()
    local numPerPlayer = getNumPagersPerPlayer()
    local numPagers = getNumPagers()
    local numPlayers = managers.network:session():amount_of_players()

    --If we're set to 2 pagers total, 1 per player, but there is only one
    --player, then effectively we're set to 1 pager.  But it's a pain to
    --keep changing settings based on number of players.  So set this to be
    --the larger of
    --
    --  The number of pagers per player
    --  the number of pagers total / number of players, rounded up
    --
    --log("numPerPlayer " .. tostring(numPerPlayer))
    --log("numPagers " .. tostring(numPagers))
    --log("numPlayers " .. tostring(numPlayers))
    local effectivePerPlayer = math.max(numPerPlayer, math.ceil(numPagers / numPlayers))
    --log("Effective number per player is " .. tostring(effectivePerPlayer))
    return effectivePerPlayer
end

function isSAEnabled()
    if SilentAssassin.settings["enabled"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["enabled"]
end

function isStealthKillEnabled()
    if not SilentAssassin.settings["stealth_kill_enabled"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["stealth_kill_enabled"]
end

function getPagerDetectionThreshold()
    if not SilentAssassin.settings["pager_detection_threshold"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["pager_detection_threshold"]
end

function isPagerBonusEnabled()
    return false
    --local Net = _G.LuaNetworking
    --if Net:IsClient() then
        --return false
    --end
    --if not SilentAssassin.settings["pager_bonus_enabled"] then
        --SilentAssassin:Load()
    --end
    --return SilentAssassin.settings["pager_bonus_enabled"]

end

function addLocalPagerAnswered()
    --log("Answered pager locally")
    SilentAssassin.localPagersUsed = SilentAssassin.localPagersUsed + 1
end

function getLocalPagersAnswered()
    return SilentAssassin.localPagersUsed
end

-------------------------------------------------
--  Handler for damaged received
-------------------------------------------------

if RequiredScript == "lib/units/enemies/cop/copbrain" then
    if not _CopBrain_clbk_damage then
        _CopBrain_clbk_damage = CopBrain._clbk_damage
    end

    function CopBrain:clbk_damage(my_unit, damage_info)
        --log ("CopBrain:clbk_damage")
        if _CopBrain_clbk_damage then 
            --this seems to get called on damage but not on death
            --So if we take any non-fatal damage, the pager will go off
            --log ("non-fatal damage")
            self._cop_pager_ready = true
            _CopBrain_clbk_damage(self, my_unit, damage_info)
            --log ("made parent callback")
        end
    end

    if not _CopBrain_clbk_death then
        _CopBrain_clbk_death = CopBrain.clbk_death
    end
    function CopBrain:clbk_death(my_unit, damage_info)
        --log ("clbk_death")
        if managers.groupai:state():whisper_mode() then 
            --for i, key in pairs(self._logic_data.detected_attention_objects) do
                --log("value is " .. tostring(i) .. ", " .. tostring(key))
                --for f, s in pairs(key) do
                    --log("inner is " .. tostring(f) .. ", " .. tostring(s))
                --end
            --end
            --log ("clbk_death2")
            if isSAEnabled() and isStealthKillEnabled() and sa_stealth_kill_allowed(damage_info) then


                local head
            --log ("damage_info is " .. json.encode(damage_info))
                if damage_info.col_ray then 
                    --the idea was to require a headshot.  It turns out that col_ray is not
                    --set when the client takes the shot so I can only do OHKs on clients.
                    --I figure to make things fair it should be OHKs for everyone
                    --head = self._unit:character_damage()._head_body_name and damage_info.col_ray.body and damage_info.col_ray.body:name() == self._unit:character_damage()._ids_head_body_name
                    head = true
                else
                    --OHK keeps the pager from going ff
                    head = true
                end
                if not head then
                    --log ("enabling pager")
                    --not headshots will cause the pager to go off
                    self._cop_pager_ready = true
                end

                local notice_progress = 0;
                if self._logic_data.detected_attention_objects then
                    for key, obj in pairs(self._logic_data.detected_attention_objects) do
                        if obj.notice_progress then
                            notice_progress = math.max(notice_progress, obj.notice_progress)
                        end
                    end
                end
                --log("notice progress was " .. tostring(notice_progress))
                if notice_progress > getPagerDetectionThreshold() then
                    --log("notice was too high")
                    self._cop_pager_ready = true
                end
                --if self._cop_pager_ready then
                    --log("_cop_pager_ready is true")
                --end

                --log(tostring(self._unit:movement():stance_name()))
                --if self._unit:movement():cool() then
                    --log("unit is cool")
                --end

                --cool() doesn't work for the camera operator on First World Bank.  For
                --some reason he's in stance "cbt" (and therefore uncool) even if he's not
                --alerted.  I figure this is a bug in the map.
            --ignore the above comment.  They fixed that bug.  Hopefully it stays that way.
            --log("unit is " .. json.encode(self._logic_data))
                if not self._cop_pager_ready and self._unit:movement():cool() then
                --if not self._cop_pager_ready and self._unit:movement():stance_name() ~= "hos" then
                    --we're dead and the pager is not ready, so delete it
                    --log ("pager disabled")
                    self._unit:unit_data().has_alarm_pager = false
                end
            end
        end
        --log("clbk_death parent")
        _CopBrain_clbk_death(self, my_unit, damage_info)
    end

-------------------------------------------------
--  Setting number of pagers
-------------------------------------------------

    --This is called when a player interacts with a pager.  Swap in the
    --correct table before actually running the pager interaction
elseif RequiredScript == "lib/units/interactions/interactionext" then
    if not _IntimitateInteractionExt_at_interact_start then
        _IntimitateInteractionExt_at_interact_start = IntimitateInteractionExt._at_interact_start
    end
    function IntimitateInteractionExt:_at_interact_start(player, timer)
        --log("at_interact_start")
        if managers.groupai:state():whisper_mode() then 
        --This is eventually going to call CopBrain.on_alarm_pager_interaction.
        --However, it doesn't pass in the player.  So, if we are going to do
        --that, set up the alarm_pager tables here
            if self.tweak_data == "corpse_alarm_pager" then
                --log("corpse_alarm_pager matches")
                if Network:is_server() then
                    --log("is server")
                    if not self._in_progress then 
                        --This is where the pager really runs
                        local bluffChance = {}
                        local numPagers;
                        numPagers = getNumPagers()

                        --Track the number of pagers a player has answered in the
                        --player object
                        if not player:base().num_answered then
                            player:base().num_answered = 0
                        end

                        --log("NumAnswered" .. tostring(player:base().num_answered))

                        --If this player can answer a pager, write up to
                        --getEffectiveNumPagersPerPlayer() 1's into the table,
                        --otherwise write all 0's.  This way the real
                        --on_alarm_pager_interaction will index into the table as
                        --normal
                        player:base().num_answered = player:base().num_answered + 1
                        local tableValue
                        if player:base().num_answered <= getEffectiveNumPagersPerPlayer() then
                            tableValue = 1
                        else
                            tableValue = 0
                        end
                        --log("tableValue is " .. tostring(tableValue))
                        for i = 0, ( numPagers - 1), 1 do
                            table.insert(bluffChance, tableValue)
                        end
                        table.insert(bluffChance, 0)

                        tweak_data.player.alarm_pager["bluff_success_chance"] = bluffChance
                        tweak_data.player.alarm_pager["bluff_success_chance_w_skill"] = bluffChance
                        if player:base().is_local_player then
                            addLocalPagerAnswered()
                        end
                    end
                end
            end
        end
        _IntimitateInteractionExt_at_interact_start(self, player, timer)
    end

elseif RequiredScript == "lib/managers/jobmanager" then
    if not _JobManager_current_stage_data then
        _JobManager_current_stage_data = JobManager.current_stage_data
    end
    function JobManager.current_stage_data(self)
        if isSAEnabled() and isPagerBonusEnabled() then 
            return modifyGhostBonus(self, _JobManager_current_stage_data(self))
        else
            return _JobManager_current_stage_data(self)
        end
    end

    if not _JobManager_current_level_data then
        _JobManager_current_level_data = JobManager.current_level_data
    end

    function JobManager.current_level_data(self)
        if isSAEnabled() and isPagerBonusEnabled() then
            return modifyGhostBonus(self, _JobManager_current_level_data(self))
        else
            return _JobManager_current_level_data(self)
        end
    end

    function modifyGhostBonus(self, level_data)
        --when the level is completed, modify the ghost_bonus of the stage.
        --This is called from JobManager.accumulate_ghost_bonus, which sets the
        --stealth bonus
        if level_data and level_data.ghost_bonus then
            local new_data = {}
            for k, v in pairs(level_data) do
                if k == "ghost_bonus" then
                    local bonus
                    if JobManager.on_last_stage(self) then
                        bonus = calculateLevelStealthBonus()
                    else
                        bonus = calculateStageStealthBonus()
                    end
                    --make sure the total stealth bonus is never negative
                    new_data[k] = math.clamp(v + bonus, 0, 1)
                else
                    new_data[k] = v
                end
            end

            return new_data
        end
        return level_data
    end
end

function CreateSALobbyMessage()
        local params = {
            num_pagers = getNumPagers(),
            num_per_player = getNumPagersPerPlayer(),
            pager_detection_threshold_pct = getPagerDetectionThreshold() * 100
        }
        local message = ""
        for i = 1, 10 do
            local key = "sa_lobby_notice_" .. tostring(i)
            local ok, piece = pcall(function()
                return managers.localization:text(key, params)
            end)
            if ok and piece and piece ~= "" and piece ~= key then
                message = message .. piece
            end
        end
        return message
end

local function sa_show_lobby_message_local(message)
    if not message or message == "" then
        return
    end
    if managers.chat and managers.chat._receive_message then
        managers.chat:_receive_message(ChatManager.GAME, "Ninja", message, Color(1, 0.7, 1, 0.4))
    end
end

Hooks:Add("NetworkManagerOnPeerAdded", "NetworkManagerOnPeerAdded_SA", function(peer, peer_id)
    if Network:is_server() and isSAEnabled() then

        DelayedCalls:Add("DelayedSAAnnounce" .. tostring(peer_id), 2, function()

            local message = CreateSALobbyMessage()
            local peer2 = managers.network:session() and managers.network:session():peer(peer_id)
            if peer2 then
                peer2:send("send_chat_message", ChatManager.GAME, message)
            end
            -- host sees the same text joiners get
            sa_show_lobby_message_local(message)
        end)
    end
end)
