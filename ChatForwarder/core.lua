ChatForwarder = {
    name    = "Chat Forwarder",
    author  = GetAddOnMetadata("ChatForwarder", "Author"),
    version = GetAddOnMetadata("ChatForwarder", "Version"),
    frame   = CreateFrame("frame"),
}

local ChatForwarder = ChatForwarder

-- Core ------------------------------------------------------------------------

-- database version
local DBVERSION = 20121021.1

-- locals
local boprolls      = {} -- roll ids to be automatically confirmed
local debug         -- debug mode flag
local events        -- event configuration table
local frame = ChatForwarder.frame -- addon frame

local incoming      -- data source
local outgoing      -- data destination
local request       -- requested player name for outgoing forwarding

-- comm settings, don't touch!
local COMM_DELIM    = "\a"
local COMM_PLAYER   = UnitName("player")
local COMM_PREFIX   = "CFW"

-- comm to event translation
local COMM2EVENT = {
    ["B"]   = "CF_GROUP",   -- battleground
    ["BL"]  = "CF_GROUP",   -- battleground leader
    ["C"]   = "CF_CHANNEL", -- channel
    ["G"]   = "CF_GUILD",   -- guild
    ["L"]   = "CF_LOOT",    -- loot roll
    ["O"]   = "CF_GUILD",   -- officer
    ["P"]   = "CF_GROUP",   -- party
    ["R"]   = "CF_GROUP",   -- raid
    ["RL"]  = "CF_GROUP",   -- raid leader
    ["S"]   = "CF_SAY",     -- say
    ["Y"]   = "CF_SAY",     -- yell
    ["<"]   = "CF_WHISPER", -- incoming whisper
    [">"]   = "CF_WHISPER", -- outgoing whisper
}

-- event to comm translation
local EVENT2COMM = {
    CHAT_MSG_BATTLEGROUND   = "B",
    CHAT_MSG_BATTLEGROUND_LEADER = "BL",
    CHAT_MSG_CHANNEL        = "C",
    CHAT_MSG_GUILD          = "G",
    CHAT_MSG_OFFICER        = "O",
    CHAT_MSG_PARTY          = "P",
    CHAT_MSG_RAID           = "R",
    CHAT_MSG_RAID_LEADER    = "RL",
    CHAT_MSG_SAY            = "S",
    CHAT_MSG_WHISPER        = "<",
    CHAT_MSG_WHISPER_INFORM = ">",
    CHAT_MSG_YELL           = "Y",
    START_LOOT_ROLL         = "L",
}

--- Generic printing function.
-- @param msg Message to print.
-- @param ... Additional params passed to ChatFrameX:AddMessage.
function ChatForwarder:Print(msg, ...)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffa500ChatForwarder:|r " .. msg, ...)
end

--- Toggles debug state.
-- In debug state all addon communication messages get printed to chat frame.
-- @param state New debug state.
function ChatForwarder:SetDebug(state)
    debug = not not state
end

--- Enables addon for chat forwarding.
function ChatForwarder:Enable()
    for event, _ in pairs(events) do
        frame:RegisterEvent(event)
    end
end

--- Disables addon for chat forwarding.
-- Does not disable inter-addon messaging.
function ChatForwarder:Disable()
    frame:UnregisterAllEvents()
    frame:RegisterEvent("CHAT_MSG_ADDON")

    return self:CloseOut()
end

--- Enables forwarding for given event.
-- @param event Event name.
function ChatForwarder:Forward(event)
    events[event] = true

    if outgoing then
        frame:RegisterEvent(event)
    end

    if event == "CHAT_MSG_BATTLEGROUND" then self:Forward("CHAT_MSG_BATTLEGROUND_LEADER")
    elseif event == "CHAT_MSG_RAID" then self:Forward("CHAT_MSG_RAID_LEADER")
    elseif event == "CHAT_MSG_WHISPER" then self:Forward("CHAT_MSG_WHISPER_INFORM")
    elseif event == "START_LOOT_ROLL" then self:Forward("CONFIRM_LOOT_ROLL")
    end
end

--- Disables forwarding for given event.
-- @param event Event name.
function ChatForwarder:Unforward(event)
    events[event] = nil

    if outgoing then
        frame:UnregisterEvent(event)
    end

    if event == "CHAT_MSG_BATTLEGROUND" then self:Unforward("CHAT_MSG_BATTLEGROUND_LEADER")
    elseif event == "CHAT_MSG_RAID" then self:Unforward("CHAT_MSG_RAID_LEADER")
    elseif event == "CHAT_MSG_WHISPER" then self:Unforward("CHAT_MSG_WHISPER_INFORM")
    elseif event == "START_LOOT_ROLL" then self:Unforward("CONFIRM_LOOT_ROLL")
    end
end

-- Helpers ---------------------------------------------------------------------

--- Returns clickable player link for use in chat frames.
-- @param player Player name to create link from.
function ChatForwarder:GetPlayerLink(player)
    return ("|Hplayer:%1$s|h[%1$s]|h"):format(player)
end

--- Returns need, greed & pass hyperlinks for given roll ID.
-- @param rollid Roll ID.
function ChatForwarder:GetNeedGreedPassLinks(rollid)
    return ("|cff88ff88[|Hcfroll:%1$d:1|h%2$s|h · |Hcfroll:%1$d:2|h%3$s|h · |Hcfroll:%1$d:0|h%4$s|h]|r"):format(rollid, NEED, GREED, PASS)
end

--- Handles roll hyperlink clicks.
-- @param btn Clicked button (irrelevant).
-- @param rollid Roll ID.
-- @param action Action to take.
function ChatForwarder:HandleRollHyperlink(btn, rollid, action)
    if incoming then
        self:Comm(incoming, "A", rollid, action)
    end
end

--- Checks if given player is friend.
-- @param player Player to check.
function ChatForwarder:IsFriend(player)
    for i = 1, GetNumFriends() do
        if GetFriendInfo(i) == player then
            return 1
        end
    end

    return nil
end

-- Connection ------------------------------------------------------------------

--- Accepts incoming connection from given player.
-- @param player Player name.
function ChatForwarder:Accept(player)
    incoming = player
    self:Comm(player, "CON", "A")
end

--- Sends busy comm to player.
-- @param player Player to send comm to.
function ChatForwarder:Busy(player)
    self:Comm(player, "CON", "B")
end

--- Closes incoming forwarding communication.
function ChatForwarder:CloseIn()
    if incoming then
        self:Comm(incoming, "CON", "C")
        incoming = nil
        return 1
    end

    return nil
end

--- Closes outgoing forwarding communication and notifies second player.
function ChatForwarder:CloseOut()
    if outgoing then
        self:Comm(outgoing, "CON", "C")
        outgoing = nil
        return 1
    end

    return nil
end

--- Requests connection with given player.
-- @param player Player to request.
function ChatForwarder:Connect(player)
    self:CloseOut()
    request = player
    self:Comm(player, "CON", "O")
end

--- Clears connection request.
function ChatForwarder:Denied()
    request = nil
end

--- Denies connection from given player.
-- @param player Player to deny connection from.
function ChatForwarder:Deny(player)
    self:Comm(player, "CON", "D")
end

--- Opens connection with given player.
-- Fired when player accepts connection or his request is accepted.
-- @param player Player whom to open transmission with.
function ChatForwarder:Open(player)
    request = nil
    outgoing = player
    self:Enable()
end

--- Connection request static dialog.
StaticPopupDialogs["CHAT_FORWARDER_CONNECTION_REQUEST"] = {
    text = "%s wants to forward chat to you. Do you want to accept it?",
    button1 = YES,
    button2 = NO,

    OnAccept = function(data)
        ChatForwarder:Accept(data)
        ChatForwarder:Print(("Connection from %s opened."):format(data))
    end,

    OnCancel = function(data)
        ChatForwarder:Deny(data)
    end,

    timeout = 0,
    hideOnEscape = 1,
    whileDead = 1,
}

-- Event handlers --------------------------------------------------------------

--- ADDON_LOADED event handler.
-- Instantiates the database. Loads default data if needed.
-- @param name Addon name.
function ChatForwarder:ADDON_LOADED(name)
    if name ~= "ChatForwarder" then
        return
    end

    frame:UnregisterEvent("ADDON_LOADED")

    ChatForwarderDB = ChatForwarderDB and ChatForwarderDB.version == DBVERSION
    and ChatForwarderDB or {
        channels = { -- channels' color and visibility configuration
            -- by default show in 3rd chat frame only
            CF_CHANNEL  = { [3] = true, r = 1.0, g = .75, b = .75, sticky = 0 },
            CF_GROUP    = { [3] = true, r = 1.0, g = .50, b = .00, sticky = 0 },
            CF_GUILD    = { [3] = true, r = .25, g = 1.0, b = .25, sticky = 0 },
            CF_LOOT     = { [3] = true, r = .00, g = .66, b = .00, sticky = 0 },
            CF_SAY      = { [3] = true, r = 1.0, g = 1.0, b = 1.0, sticky = 0 },
            CF_WHISPER  = { [3] = true, r = 1.0, g = .50, b = 1.0, sticky = 0 },
        },
        events = { -- enabled/disabled events configuration
            CHAT_MSG_GUILD          = true,
            CHAT_MSG_PARTY          = true,
            CHAT_MSG_RAID           = true,
            CHAT_MSG_WHISPER        = true,
            CHAT_MSG_WHISPER_INFORM = true,
        },
        version = DBVERSION
    }

    self.db = ChatForwarderDB
    events = ChatForwarderDB.events

    self:SetChannels()
end

--- CONFIRM_LOOT_ROLL event hadler.
-- Fired when BoP rolls need to be confirmed.
-- @param rollid Roll ID.
-- @param action Action to take.
function ChatForwarder:CONFIRM_LOOT_ROLL(rollid, action)
    if boprolls[rollid] then
        ConfirmLootRoll(rollid, action)
        boprolls[rollid] = nil
        StaticPopup_Hide("CONFIRM_LOOT_ROLL")
    end
end

--- START_LOOT_ROLL event handler.
-- Fired when player gets item roll offer.
-- @param rollid Roll ID.
-- @param action Action to take.
function ChatForwarder:START_LOOT_ROLL(rollid, rolltime)
    if not outgoing then
        return
    end

    local texture, name, count, quality, bop = GetLootRollItemInfo(rollid)
    local link = GetLootRollItemLink(rollid)

    self:Comm(outgoing, "L", rollid, strsub(texture, 17), link, count, bop or 0)
end

--- Valid channel list for @commands.
-- All not nil values define valid commands.
local ValidChannels = {
    BATTLEGROUND = false,
    BG      = "BATTLEGROUND",
    C       = "CHANNEL",
    CHANNEL = false,
    G       = "GUILD",
    GUILD   = false,
    O       = "OFFICER",
    OFFICER = false,
    P       = "PARTY",
    PARTY   = false,
    R       = "RAID",
    RAID    = false,
    S       = "SAY",
    SAY     = false,
    W       = "WHISPER",
    WHISPER = false,
    Y       = "YELL",
    YELL    = false,
}

local lasttarget = ""

--- Generic OnEvent handler for chat and loot events.
-- @param event Event hame.
-- @param ... Additional params.
function ChatForwarder:OnEvent(event, msg, author, _, _, _, _, _, _, channel)
    -- check receiver presence
    if not outgoing then
        return
    end

    if (author == outgoing and event == "CHAT_MSG_WHISPER") or event == "CHAT_MSG_WHISPER_INFORM" then
        if strsub(msg, 1, 1) == "@" then -- handle @commands
            local cmd, target, msg = msg:match("@(%w+):?(%S*)%s*(.*)")
            channel = cmd:upper()

            if ValidChannels[channel] ~= nil then
                if (channel == "W" or channel == "WHISPER") and target ~= lasttarget and target ~= "" then
                    lasttarget = target
                end

                SendChatMessage(msg, ValidChannels[channel] or channel, nil, target ~= "" and target or lasttarget)

            elseif cmd == "off" then
                self:Disable()
                self:Print("Outgoing forwarding disabled by @off command.")

            elseif cmd == "roll" then
                local min, max = msg:match("(%d+)[%D]*(%d*)")

                min = tonumber(min) or 100
                max = tonumber(max) or 1

                if min > max then
                    min, max = max, min
                end

                RandomRoll(min, max)

            elseif cmd == "camp" then
                self:Disable()
                Logout()

            elseif cmd == "quit" then
                self:Disable()
                Quit()
            end
        end

        if event == "CHAT_MSG_WHISPER" then
            return -- drop whisper messages from connected player
        end
    end

    self:Comm(outgoing, EVENT2COMM[event], msg, author, channel)
end

-- Comm ------------------------------------------------------------------------

local function pack(...) return strjoin(COMM_DELIM, ...) end
local function unpk(msg) return strsplit(COMM_DELIM, msg) end

--- Addon message event handler.
-- @param prefix Message prefix.
-- @param msg Addon message itself.
-- @param distr Distribution channel.
-- @param sender Message sender.
function ChatForwarder:CHAT_MSG_ADDON(prefix, msg, distr, sender)
    if prefix ~= COMM_PREFIX
    or distr ~= "WHISPER"
    -- or sender == COMM_PLAYER
    then
        return
    end

    return debug and self:Print("[RECV] " .. msg:gsub(COMM_DELIM, ", "))
    or self:HandleComm(sender, unpk(msg))
end

function ChatForwarder:HandleComm(sender, type, ...)
    if sender == incoming then -- incoming comms
        if type == "L" then -- loot offer
            local rollid, texture, link, count, bop = ...

            count = tonumber(count) or 1
            bop = tonumber(bop) or 0

            local msg = ("|TInterface\\Icons\\%s:16:16:0:-2|t%s%s%s %s"):
                format(texture, link, bop > 0 and "[BoP]" or "", count > 1 and
                ("x%d"):format(count) or "", self:GetNeedGreedPassLinks(rollid))

            self:Message(sender, type, COMM2EVENT[type], msg)

        elseif COMM2EVENT[type] then
            local msg, author, channel = ...
            self:Message(sender, type, COMM2EVENT[type], msg, author, channel)

        elseif type == "CON" and select(1, ...) == "C" then
            self:CloseIn()
            self:Print(("Incoming connection closed by %s."):format(sender))
        end

        return

    elseif sender == outgoing then
        if type == "A" then -- roll action
            if events.START_LOOT_ROLL then
                local rollid, action = ...

                rollid = tonumber(rollid)
                action = tonumber(action)

                if select(5, GetLootRollItemInfo(rollid)) then -- is BoP item?
                    boprolls[rollid] = true
                end

                RollOnLoot(rollid, action)
            end
        elseif type == "CON" and select(1, ...) == "C" then
            self:Disable()
            self:Print(("Connection closed by %s."):format(sender))
        end

        return

    elseif sender == request then -- request comms
        if type ~= "CON" then
            return
        end

        local subtype = ...

        if subtype == "A" then -- accept
            self:Open(sender)
            self:Print(("Outgoing connection to %s opened."):format(sender))

        elseif subtype == "B" then -- busy
            self:Denied()
            self:Print(("Connection denied. %s is busy."):format(sender))

        elseif subtype == "D" then -- deny
            self:Denied()
            self:Print(("Connection request denied by %s."):format(sender))
        end

        return

    elseif type == "CON" and select(1, ...) == "O" then -- open request
        if incoming or request then
            self:Busy(sender)
            return
        end

        if self:IsFriend(sender) then
            self:Accept(sender)
            self:Print(("Incoming connection from %s opened."):format(sender))

        else
            local dlg = StaticPopup_Show("CHAT_FORWARDER_CONNECTION_REQUEST", sender, nil, sender)

            if dlg then
                dlg.data = sender
            end
        end

        return
    end
end

function ChatForwarder:Comm(player, ...)
    return debug and self:Print("[SEND] " .. pack(...):gsub(COMM_DELIM, ", "))
    or SendAddonMessage(COMM_PREFIX, pack(...), "WHISPER", player)
end

-- Init ------------------------------------------------------------------------

function ChatForwarder:Init()
    frame:SetScript("OnEvent", function(frame, event, ...)
        if self[event] then
            self[event](self, ...)
        else
            self:OnEvent(event, ...)
        end
    end)

    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("CHAT_MSG_ADDON")

    self:Print(("Version %s loaded. Usage: /cf"):format(self.version))
end

ChatForwarder:Init()
