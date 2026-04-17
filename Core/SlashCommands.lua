local ADDON_NAME, ns = ...

-- ─── Bootstrap on PLAYER_LOGIN ───────────────────────────────────────────────
-- Defer initialization that needs the world frame or Blizzard Settings system.
local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("PLAYER_LOGIN")
bootFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if ns.InstallMapHooks then ns:InstallMapHooks() end
        if ns.InitSettings    then ns:InitSettings()    end
        if ns.InstallMapPicker then ns:InstallMapPicker() end
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- ─── Slash command handler ───────────────────────────────────────────────────

local function PrintHelp()
    local L = ns.L
    ns:Print(L.HELP_HEADER)
    ns:Print("  " .. L.HELP_NEW)
    ns:Print("  " .. L.HELP_TITLE)
    ns:Print("  " .. L.HELP_LIST)
    ns:Print("  " .. L.HELP_SETTINGS)
    ns:Print("  " .. L.HELP_HELP)
end

local function HandleSlashCommand(input)
    local L = ns.L
    input = input or ""
    -- Trim leading/trailing whitespace
    input = input:match("^%s*(.-)%s*$") or ""

    -- No args: open pin creation popup at current location
    if input == "" then
        ns:ShowPinPopup()
        return
    end

    -- First token
    local cmd, rest = input:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "help" or cmd == "?" then
        PrintHelp()
        return
    end

    if cmd == "list" or cmd == "l" then
        if ns.ShowPinList then
            ns:ShowPinList()
        else
            ns:Print(string.format(L.LIST_TOTAL_COUNT, ns:GetPinCount()))
        end
        return
    end

    if cmd == "settings" or cmd == "config" or cmd == "opt" then
        if ns.settingsCategory and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(ns.settingsCategory:GetID())
        else
            ns:Print("Settings panel not ready.")
        end
        return
    end

    if cmd == "delete" or cmd == "del" or cmd == "rm" then
        local pinId = tonumber(rest)
        if not pinId then
            ns:Print("Usage: /lp delete <pinId>")
            return
        end
        local ok, pin = ns:DeletePin(pinId)
        if ok then
            ns:Print(string.format(L.PIN_DELETED, pin.title or ""))
        else
            ns:Print(L.PIN_NOT_FOUND)
        end
        return
    end

    if cmd == "detail" or cmd == "show" or cmd == "view" then
        local pinId = tonumber(rest)
        if not pinId then
            ns:Print("Usage: /lp detail <pinId>")
            return
        end
        if ns.ShowPinDetail then
            ns:ShowPinDetail(pinId)
        else
            ns:Print(L.PIN_NOT_FOUND)
        end
        return
    end

    -- Otherwise, treat the whole input as a pin title (quick-create mode)
    ns:ShowPinPopup({ title = input })
end

-- ─── Register slash commands ─────────────────────────────────────────────────

SLASH_LOREPIN1 = "/lp"
SLASH_LOREPIN2 = "/lorepin"
SlashCmdList["LOREPIN"] = HandleSlashCommand
