local ADDON_NAME, ns = ...

ns.L = {}
ns.ADDON_NAME = ADDON_NAME

function ns:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF33CC99[LorePin]|r " .. msg)
end

-- Bootstrap: initialize DB on ADDON_LOADED. Do NOT print a load banner to
-- chat — every loaded addon spamming "/mod loaded" clutters the chat window
-- and is better handled via CurseForge description / TOC Notes instead.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        ns:InitDB()
        loader:UnregisterEvent("ADDON_LOADED")
    end
end)
