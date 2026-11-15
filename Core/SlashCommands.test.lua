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
    if opts.detail ~= false then
        function ns:ShowPinDetail(id) self.opened[#self.opened + 1] = { "detail", id } end
    end
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
        for _, input in ipairs({ "detail 3", "show 4", "VIEW  5 " }) do run(input) end
        eq(ns.opened, { { "detail", 3 }, { "detail", 4 }, { "detail", 5 } })
        ns.printed = {}
        run("detail abc")
        run("view")
        eq(ns.printed, { "Usage: /lp detail <pinId>", "Usage: /lp detail <pinId>" })

        ns.opened = {}
        run("  Dark Cave  ")
        run("deleted cave")
        eq(ns.opened, { { "popup", { title = "Dark Cave" } }, { "popup", { title = "deleted cave" } } })
    end)

    it("TC#14 delete·del·rm 은 확인 없이 지우고, id 가 숫자가 아니거나 없는 핀이면 안내한다", function()
        local ns, run = slash_addon()
        local a = ns:CreatePin({ title = "A", mapID = 1, x = 0, y = 0 })
        local b = ns:CreatePin({ title = "B", mapID = 1, x = 0, y = 0 })
        local c = ns:CreatePin({ title = "C", mapID = 1, x = 0, y = 0 })
        ns.printed = {}
        run("delete " .. a.id)
        run("DEL " .. b.id)
        run("rm " .. c.id)
        eq(ns:GetPinCount(), 0)
        run("rm 99")
        run("delete x")
        run("del")
        eq(ns.printed, {
            string.format(ns.L.PIN_DELETED, "A"),
            string.format(ns.L.PIN_DELETED, "B"),
            string.format(ns.L.PIN_DELETED, "C"),
            ns.L.PIN_NOT_FOUND,
            "Usage: /lp delete <pinId>",
            "Usage: /lp delete <pinId>",
        })
        eq(ns.opened, {})
    end)

    it("TC#14 목록·설정·상세 패널이 아직 없으면 채팅창 안내로 대신한다", function()
        local ns, run = slash_addon({ list = false, settings = false, detail = false })
        local a = ns:CreatePin({ title = "A", mapID = 1, x = 0, y = 0 })
        ns.printed = {}
        run("list")
        run("settings")
        run("detail " .. a.id)
        eq(ns.printed, { string.format(ns.L.LIST_TOTAL_COUNT, 1), "Settings panel not ready.", ns.L.PIN_NOT_FOUND })
        eq(ns.opened, {})
    end)
end)
