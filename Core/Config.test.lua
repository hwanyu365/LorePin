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

describe("미니맵 설정 없음", function()
    it("TC#15 이전 버전의 설정 키는 로드 때 남기고 설정 초기화 때 지운다, 새 기본값에는 없다", function()
        local ns = support.addon({ db = { settings = { showOnMinimap = false, minimapIconSize = 12 } } })
        eq(ns.db.settings.showOnMinimap, false)
        eq(ns.db.settings.minimapIconSize, 12)
        eq(ns.DEFAULTS.settings.showOnMinimap, nil)
        eq(ns.DEFAULTS.settings.minimapIconSize, nil)

        ns:ResetSettings()
        eq(ns.db.settings.showOnMinimap, nil)
        eq(ns.db.settings.minimapIconSize, nil)
    end)
end)
