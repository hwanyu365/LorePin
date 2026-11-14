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
