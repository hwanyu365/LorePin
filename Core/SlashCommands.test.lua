local support = load_source("scripts/test-support.lua")

local function slash_addon(opts)
    opts = opts or {}
    local ns = support.addon(opts)
    local frame = {}
    function frame:RegisterEvent() end
    function frame:UnregisterEvent() end
    function frame:SetScript() end
    CreateFrame = function() return frame end
    SlashCmdList = {}
    ns.opened = {}
    if opts.settings ~= false then
        Settings = { OpenToCategory = function(id) ns.opened[#ns.opened + 1] = { "settings", id } end }
        ns.settingsCategory = { GetID = function() return 42 end }
    end
    function ns:ShowPinPopup(prefill) self.opened[#self.opened + 1] = { "popup", prefill } end
    if opts.list ~= false then
        function ns:ShowPinList() self.opened[#self.opened + 1] = { "list" } end
    end
    function ns:ShowPinDetail(id) self.opened[#self.opened + 1] = { "detail", id } end
    load_source("Core/SlashCommands.lua", ns)
    return ns, SlashCmdList["LOREPIN"]
end

describe("슬래시 명령", function()
    it("TC#14 /lp·/lorepin 이 명령 표의 입력마다 동작한다", function()
        local ns, run = slash_addon()
        eq(SLASH_LOREPIN1, "/lp")
        eq(SLASH_LOREPIN2, "/lorepin")

        run(nil)
        run("   ")
        eq(ns.opened, { { "popup", nil }, { "popup", nil } })

        for _, input in ipairs({ "help", "?", " HeLp " }) do
            ns.printed = {}
            run(input)
            eq(ns.printed, { ns.L.HELP_HEADER, "  " .. ns.L.HELP_NEW, "  " .. ns.L.HELP_TITLE, "  " .. ns.L.HELP_LIST, "  " .. ns.L.HELP_SETTINGS, "  " .. ns.L.HELP_HELP }, input)
        end

        ns.opened = {}
        for _, input in ipairs({ "list", "l", "LIST" }) do run(input) end
        for _, input in ipairs({ "settings", "config", "opt" }) do run(input) end
        eq(ns.opened, { { "list" }, { "list" }, { "list" }, { "settings", 42 }, { "settings", 42 }, { "settings", 42 } })

        ns.opened = {}
        run("  Dark Cave  ")
        run("deleted cave")
        eq(ns.opened, { { "popup", { title = "Dark Cave" } }, { "popup", { title = "deleted cave" } } })
    end)

    it("TC#14 detail·delete 계열 명령은 없다 → 그 글을 제목으로 채운 생성 팝업, 핀은 그대로", function()
        local ns, run = slash_addon()
        local a = ns:CreatePin({ title = "A", mapID = 1, x = 0, y = 0 })
        ns.printed = {}
        local inputs = { "delete " .. a.id, "del " .. a.id, "rm " .. a.id, "detail " .. a.id, "show " .. a.id, "view " .. a.id, "delete" }
        local expected = {}
        for _, input in ipairs(inputs) do
            run(input)
            expected[#expected + 1] = { "popup", { title = input } }
        end
        eq(ns.opened, expected)
        eq(ns:GetPinCount(), 1)
        eq(ns.printed, {})
    end)

    it("TC#14 목록·설정 패널이 아직 없으면 채팅창 안내로 대신한다", function()
        local ns, run = slash_addon({ list = false, settings = false })
        ns:CreatePin({ title = "A", mapID = 1, x = 0, y = 0 })
        ns.printed = {}
        run("list")
        run("settings")
        eq(ns.printed, { string.format(ns.L.LIST_TOTAL_COUNT, 1), "Settings panel not ready." })
        eq(ns.opened, {})
    end)
end)
