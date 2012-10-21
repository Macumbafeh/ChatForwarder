local ChatForwarder = ChatForwarder

-- Chat frame stuff ------------------------------------------------------------

local channels

--- Defines multiple events matching the same chat type.
-- The first event in array MUST be the "CHAT_MSG_" followed by the entry key.
ChatForwarder.ChatTypeGroups = {
    CF_CHANNEL  = { "CHAT_MSG_CF_CHANNEL" },
    CF_GROUP    = { "CHAT_MSG_CF_GROUP", "CHAT_MSG_CF_PARTY", "CHAT_MSG_CF_RAID", "CHAT_MSG_CF_BATTLEGROUND" },
    CF_GUILD    = { "CHAT_MSG_CF_GUILD", "CHAT_MSG_CF_OFFICER" },
    CF_LOOT     = { "CHAT_MSG_CF_LOOT" },
    CF_SAY      = { "CHAT_MSG_CF_SAY" },
    CF_WHISPER  = { "CHAT_MSG_CF_WHISPER", "CHAT_MSG_CF_WHISPER_INFORM" },
}

function ChatForwarder:SetChannels()
    channels = self.db.channels
    local groups = self.ChatTypeGroups
    for id, info in pairs(channels) do
        ChatTypeInfo[id] = info
        ChatTypeGroup[id] = groups[id]

        -- for use in chat config
        setglobal(id, "[CF] "  .. getglobal(strsub(id, 4)))

        -- make chat type configurable in chat configuration frame
        tinsert(CHAT_CONFIG_OTHER_SYSTEM, {
            type = id,
            checked = function() return IsListeningForMessageType(id) end,
            func = function(checked) ToggleChatMessageGroup(checked, id) end
        })
    end
end

-- Chat hyperlinks hooks -------------------------------------------------------

local Orig_ChatFrame_OnHyperlinkShow = ChatFrame_OnHyperlinkShow

function ChatFrame_OnHyperlinkShow(frame, link, btn)
    local rollid, action = link:match("^|Hcfroll:(%d+):(%d+)|h")

    if rollid and action then
        ChatForwarder:HandleRollHyperlink(btn, tonumber(rollid), tonumber(action))
    else
        Orig_ChatFrame_OnHyperlinkShow(frame, link, btn)
    end
end

-- Chat config hooks -----------------------------------------------------------

-- store original function handlers
local Orig_ChangeChatColor = ChangeChatColor
local Orig_GetChatWindowMessages = GetChatWindowMessages
local Orig_AddChatWindowMessages = AddChatWindowMessages
local Orig_RemoveChatWindowMessages = RemoveChatWindowMessages

function ChangeChatColor(chattype, r, g, b)
    if channels[chattype] then
        channels[chattype].r = r
        channels[chattype].g = g
        channels[chattype].b = b

        -- notify chat frames about the change!
        -- ChatForwarder:FireChatEvent("UPDATE_CHAT_COLOR", chattype, r,g,b)
    else
        Orig_ChangeChatColor(chattype, r, g, b)
    end
end

function GetChatWindowMessages(n)
    local ret = { Orig_GetChatWindowMessages(n) }

    for chattype, settings in pairs(channels) do
        if settings[n] then
            tinsert(ret, chattype)
        end
    end

    return unpack(ret)
end

function AddChatWindowMessages(n, chattype)
    if channels[chattype] then
        channels[chattype][n] = true
    else
        Orig_AddChatWindowMessages(n, chattype)
    end
end

function RemoveChatWindowMessages(n, chattype)
    if channels[chattype] then
        channels[chattype][n] = false
    else
        Orig_RemoveChatWindowMessages(n, chattype)
    end
end

-- Message displaying ----------------------------------------------------------

--- Type labels visible in front of chat message.
local TypeLabels = {
    ["B"]   = BATTLEGROUND,
    ["BL"]  = BATTLEGROUND_LEADER,
    ["G"]   = GUILD,
    ["L"]   = LOOT,
    ["O"]   = CHAT_MSG_OFFICER,
    ["P"]   = PARTY,
    ["R"]   = RAID,
    ["RL"]  = RAID_LEADER,
    ["S"]   = SAY,
    ["Y"]   = YELL,
    ["<"]   = "W:To",
    [">"]   = "W:From",
}

--- Used for printing incoming chat messages to chat frame.
-- @param sender Comm sender.
-- @param id Type ID for label translation.
-- @param type Chat type ID for colorisation.
-- @param msg Message to show.
-- @param author Original author.
-- @param channel Original public channel (optional).
function ChatForwarder:Message(sender, id, type, msg, author, channel)
    local info = ChatTypeInfo[type]

    for i = 1, NUM_CHAT_WINDOWS do
        if channels[type][i] then
            getglobal("ChatFrame" .. i):AddMessage(
                ("[%s @ %s]"):format(channel ~= "" and channel or TypeLabels[id] or UNKNOWN, sender) ..
                (author and " " .. self:GetPlayerLink(author) or "") .. ": " .. msg,
                info.r, info.g, info.b
            )
        end
    end
end
