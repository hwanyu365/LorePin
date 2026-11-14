local support = load_source("scripts/test-support.lua")

describe("Config", function()
    it("TC#15 DB 생성·없는 키만 채움(중첩)·핀 초기화·설정 초기화 범위", function()
        local ns = support.addon({ db = nil })
        eq(LorePinDB, ns.db)
        eq(ns.db, ns.DEFAULTS)

        local saved = {
            pins = { { id = 7, title = "old" } },
            nextPinId = 8,
            settings = { maxPins = 100, legacyKey = "kept" },
        }
        ns = support.addon({ db = saved })
        eq(ns.db, saved)
        eq(ns.db.pins, { { id = 7, title = "old" } })
        eq(ns.db.nextPinId, 8)
        eq(ns.db.settings.maxPins, 100)
        eq(ns.db.settings.legacyKey, "kept")
        eq(ns.db.settings.showOnWorldMap, true)
        eq(ns.db.settings.worldMapIconSize, 20)
        eq(ns.db.customCategories, {})

        ns.db.customCategories = { { id = "mine" } }
        ns:ResetAllPins()
        eq(ns.db.pins, {})
        eq(ns.db.nextPinId, 1)
        eq(ns.db.settings.maxPins, 100)
        eq(ns.db.customCategories, { { id = "mine" } })

        ns:CreatePin({ title = "t", mapID = 1, x = 0, y = 0 })
        ns:ResetSettings()
        eq(ns.db.settings, ns.DEFAULTS.settings)
        eq(ns:GetPinCount(), 1)
    end)
end)

describe("버전 표시", function()
    it("TC#36 설정 제목은 TOC 버전을 쓰고, 읽지 못하면 이름만", function()
        local ns = support.addon()
        local asked = {}
        C_AddOns = { GetAddOnMetadata = function(name, field) asked[#asked + 1] = { name, field }; return "1.2.3" end }
        eq(ns:GetSettingsTitle(), "LorePin v1.2.3")
        eq(asked, { { "LorePin", "Version" } })

        C_AddOns = { GetAddOnMetadata = function() return nil end }
        eq(ns:GetSettingsTitle(), "LorePin")
        C_AddOns = { GetAddOnMetadata = function() return "" end }
        eq(ns:GetSettingsTitle(), "LorePin")
        C_AddOns = nil
        eq(ns:GetSettingsTitle(), "LorePin")
    end)
end)
