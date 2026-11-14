local support = load_source("scripts/test-support.lua")

local function keys(t)
    local out = {}
    for k in pairs(t) do out[k] = true end
    return out
end

describe("Locale", function()
    it("TC#17 koKR 클라이언트면 koKR 문구, 그 밖이면 enUS, 두 로케일 키 집합이 같다", function()
        local en = support.addon({ locale = "enUS" })
        local ko = support.addon({ locale = "koKR" })
        eq(en.L.PIN_NOT_FOUND, "Pin not found.")
        eq(ko.L.TITLE_REQUIRED, "제목을 입력해주세요.")

        support.stub_wow({ locale = "koKR" })
        local koOnly = { L = {} }
        load_source("Locale/koKR.lua", koOnly)
        eq(keys(koOnly.L), keys(en.L))

        local de = support.addon({ locale = "deDE" })
        eq(de.L, en.L)
    end)
end)
