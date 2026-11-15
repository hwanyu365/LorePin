local support = load_source("scripts/test-support.lua")

local function ids(list)
    local out = {}
    for i, c in ipairs(list) do out[i] = c.id end
    return out
end

describe("CategoryManager", function()
    it("TC#11 내장 6개 순서, 사용자 카테고리를 뒤에 이어 붙임, ID 조회, 기본 general", function()
        local ns = support.addon()
        eq(ids(ns:GetCategories()), { "general", "quest", "danger", "gather", "scenic", "complete" })
        eq(ns:GetDefaultCategoryId(), "general")
        eq(ns:GetCategoryById("danger").name, ns.L.CATEGORY_DANGER)
        eq(ns:GetCategoryById("nope"), nil)

        ns.db.customCategories = { { id = "mine", name = "Mine", custom = true } }
        eq(ids(ns:GetCategories()), { "general", "quest", "danger", "gather", "scenic", "complete", "mine" })
        eq(ns:GetCategoryById("mine").name, "Mine")
    end)

    it("TC#12 사용자 카테고리 추가(기본 아이콘·색)·중복 거부(내장 포함)·삭제", function()
        local ns = support.addon()
        eq(ns:AddCustomCategory("mine", "Mine"), true)
        eq(ns.db.customCategories[1], {
            id = "mine", name = "Mine", icon = [[Interface\Icons\INV_Misc_QuestionMark]],
            color = { r = 1.0, g = 1.0, b = 1.0 }, custom = true,
        })
        eq(ns:IsCustomCategory("mine"), true)
        eq(ns:IsCustomCategory("general"), false)

        local ok, err = ns:AddCustomCategory("mine", "Again")
        eq(ok, false)
        eq(type(err), "string")
        eq((ns:AddCustomCategory("quest", "Q")), false)
        eq(#ns.db.customCategories, 1)

        eq(ns:RemoveCustomCategory("mine"), true)
        eq(ns:RemoveCustomCategory("mine"), false)
        eq(ns:IsCustomCategory("mine"), false)
    end)
end)

describe("사용자 카테고리 만들기·지우기", function()
    it("TC#39 이름 판정과 막힌 이유", function()
        local ns = support.addon()
        local L = ns.L
        for _, blank in ipairs({ false, "", "   ", string.char(9) }) do
            local ok, reason = ns:CheckCategoryName(blank or nil)
            eq({ ok, reason }, { false, L.CATEGORY_NAME_REQUIRED }, tostring(blank))
        end
        eq({ ns:CheckCategoryName(string.rep("a", 24)) }, { true })
        eq({ ns:CheckCategoryName(" " .. string.rep("a", 24) .. " ") }, { true })
        eq({ ns:CheckCategoryName(string.rep("a", 25)) }, { false, L.CATEGORY_NAME_TOO_LONG })
        eq({ ns:CheckCategoryName(string.rep("가", 24)) }, { true })
        eq({ ns:CheckCategoryName(string.rep("가", 25)) }, { false, L.CATEGORY_NAME_TOO_LONG })
        eq({ ns:CheckCategoryName("gather") }, { false, L.CATEGORY_NAME_DUPLICATE })
        eq({ ns:CheckCategoryName("  QUEST ") }, { false, L.CATEGORY_NAME_DUPLICATE })
        ns:CreateCustomCategory("Herbs")
        eq({ ns:CheckCategoryName("herbs") }, { false, L.CATEGORY_NAME_DUPLICATE })
        eq({ ns:CheckCategoryName("Herbs 2") }, { true })

        local ko = support.addon({ locale = "koKR" })
        eq({ ko:CheckCategoryName(ko.L.CATEGORY_GATHER) }, { false, ko.L.CATEGORY_NAME_DUPLICATE })
    end)

    it("TC#40 만들기: 이름 정리·ID custom{n}·아이콘·색 기본값·거부 시 저장 안 함", function()
        local ns = support.addon()
        local icons = ns.CUSTOM_CATEGORY_ICONS
        eq(#icons, 12)

        local a = ns:CreateCustomCategory("  Herbs  ", icons[3], { r = 0.1, g = 0.2, b = 0.3 })
        eq(a, { id = "custom1", name = "Herbs", icon = icons[3], color = { r = 0.1, g = 0.2, b = 0.3 }, custom = true })
        local b = ns:CreateCustomCategory("Ore", [[Interface\Icons\Not_In_List]])
        eq(b, { id = "custom2", name = "Ore", icon = icons[1], color = { r = 1.0, g = 1.0, b = 1.0 }, custom = true })
        eq(ns:CreateCustomCategory("Fish").icon, icons[1])
        eq(ns:GetCategoryById("custom2").name, "Ore")

        ns:DeleteCustomCategory("custom1")
        eq(ns:CreateCustomCategory("Gems").id, "custom1")
        eq(ns:CreateCustomCategory("More").id, "custom4")

        local before = #ns.db.customCategories
        local cat, reason = ns:CreateCustomCategory("ore")
        eq({ cat, reason }, { nil, ns.L.CATEGORY_NAME_DUPLICATE })
        eq((ns:CreateCustomCategory("  ")), nil)
        eq(#ns.db.customCategories, before)
    end)

    it("TC#41 지우기: 그 카테고리 핀도 지움, 내장·없는 ID 거부, 없는 카테고리 ID 는 general", function()
        local ns = support.addon()
        local herbs = ns:CreateCustomCategory("Herbs")
        local ore = ns:CreateCustomCategory("Ore")
        local function pin(title, category) return ns:CreatePin({ title = title, category = category, mapID = 1, x = 0, y = 0 }) end
        local h1, h2 = pin("h1", herbs.id), pin("h2", herbs.id)
        local o1, g1 = pin("o1", ore.id), pin("g1", "gather")
        ns.calls.removedFromMap = {}
        local mapBefore, listBefore = ns.calls.worldMap, ns.calls.list

        eq(ns:DeleteCustomCategory(herbs.id), 2)
        eq(ns.calls.worldMap - mapBefore, 1)
        eq(ns.calls.list - listBefore, 1)
        eq(ns:GetCategoryById(herbs.id), nil)
        eq(ns:GetAllPins(), { o1, g1 })
        eq(ns.calls.removedFromMap, { h1.id, h2.id })

        eq(ns:DeleteCustomCategory(ore.id), 1)
        eq(ns:DeleteCustomCategory(ore.id), nil)
        eq(ns:DeleteCustomCategory("gather"), nil)
        eq(ns:GetAllPins(), { g1 })

        eq(pin("x", "custom9").category, "general")
        eq(pin("y", nil).category, "general")
        local keep = ns:CreateCustomCategory("Keep")
        eq(pin("z", keep.id).category, keep.id)
        ns:UpdatePin(g1.id, { category = "custom9" })
        eq(g1.category, "general")
        ns:UpdatePin(g1.id, { category = "danger" })
        eq(g1.category, "danger")

        local set = { danger = true, custom9 = true, [keep.id] = true }
        eq(ns:DropUnknownCategories(set), { danger = true, [keep.id] = true })
    end)
end)
