local ChatForwarder = ChatForwarder

--- Label to event translation for slash command use.
local LABEL2EVENT = {
    BATTLEGROUND = "CHAT_MSG_BATTLEGROUND",
    BG          = "CHAT_MSG_BATTLEGROUND",
    CHANNEL     = "CHAT_MSG_CHANNEL",
    GUILD       = "CHAT_MSG_GUILD",
    LOOT        = "START_LOOT_ROLL",
    OFFICER     = "CHAT_MSG_OFFICER",
    PARTY       = "CHAT_MSG_PARTY",
    RAID        = "CHAT_MSG_RAID",
    SAY         = "CHAT_MSG_SAY",
    WHISPER     = "CHAT_MSG_WHISPER",
    YELL        = "CHAT_MSG_YELL",
}

SLASH_CHATFORWARDER1 = "/chatforwarder"
SLASH_CHATFORWARDER2 = "/cf"

--- Shorthand function for printing messages.
local function print(...) DEFAULT_CHAT_FRAME:AddMessage(...) end

--- Slash command list helper function.
SlashCmdList.CHATFORWARDER = function(msg) ChatForwarder:OnSlash(msg) end

--- Slash command handler.
-- @param msg Command message.
function ChatForwarder:OnSlash(msg)
    local cmd, param = msg:match("(%S*)%s*(.*)")

    if cmd == "open" then -- request connection with given player
        if param ~= "" then
            self:Connect(param)
            self:Print(("Connection request sent to %s."):format(param))
        end

    elseif cmd == "close" or cmd == "off" then -- close active connection
        if param == "in" then
            return self:CloseIn() and self:Print("Incoming connection closed.")
        else
            return self:Disable() and self:Print("Forwarding disabled.")
        end

    elseif cmd == "forward" or cmd == "+" then
        for chan in param:gmatch("%w+") do
            local event = LABEL2EVENT[param:upper()]
            if event then
                self:Forward(event)
            end
        end

    elseif cmd == "unforward" or cmd == "-" then
        for chan in param:gmatch("%w+") do
            local event = LABEL2EVENT[param:upper()]
            if event then
                self:Unforward(event)
            end
        end

    elseif cmd == "accept" then
        local dlg = getglobal(StaticPopup_Visible("CHAT_FORWARDER_CONNECTION_REQUEST"))

        if dlg then
            StaticPopupDialogs[dlg.which].OnAccept(dlg.data, dlg.data2)
            StaticPopup_Hide("CHAT_FORWARDER_CONNECTION_REQUEST")
        end

    else
        self:Usage() -- print usage
    end
end

--- Usage information.
function ChatForwarder:Usage()
    self:Print("Usage: /cf { open || close || forward || unforward || accept }")
    print("   /cf open <player> - Requests fowarding connection to given player.")
    print("   /cf close [ in ] - Closes active incoming or outgoing connection.")
    print("   /cf foward||+ chan1 chan2 ... - Enables fowarding for given channel(s).")
    print("   /cf unfoward||- chan1 chan2 ... - Disables fowarding for given channel(s).")
    print("   /cf accept - Accepts current connection request.")
end
